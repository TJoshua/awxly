#!/bin/bash

set -e
set -o pipefail

USAGE()
{
	echo "Usage: `basename $0` <StorageDir> <TunnelPort>"
}

if [ "$#" -ne "2" ]; then
	USAGE
	exit 1
fi

if [ ! -d "$1" ]; then
	echo "The specified storage directory does not exist. ($1)"
	exit 1
fi

# Determine the persistent storage directories to use for the kubernetes cluster
export awxly_k8s_dir=$1
export awxly_k8s_projects_dir="$awxly_k8s_dir/projects"
export awxly_k8s_pgsql_dir="$awxly_k8s_dir/pgsql"
# Ensure that the persistent storage directories exist
mkdir -p $awxly_k8s_projects_dir
mkdir -p $awxly_k8s_pgsql_dir

# Determine the awxly install directory on the WSL host
export awxly_install_dir=$(dirname "$0")
export awxly_temp_dir="$awxly_install_dir/temp"
export awxly_minikube_temp_dir="$awxly_temp_dir/minikube"

export awx_tunnel_port=$2

# Install openssh (required for minikube tunneling)
apk add openssh
# Install curl (required for kustomize install)
apk add curl
# Install the jq package (required to parse JSON when determining the latest awx release)
apk add jq
# Install docker
apk add docker
# Install the tools necessary to build minikube from source
apk add go make git

# Clone the minikube git repository (or pull the latest if it already exists in the temp directory)
if [ -d "$awxly_minikube_temp_dir" ]; then
	echo "Using existing minikube repository found in temp directory..."
	cd $awxly_minikube_temp_dir
	git pull
else
	echo "Minikube repository not found in temp directory. Cloning..."
	git clone https://github.com/kubernetes/minikube $awxly_minikube_temp_dir
	cd $awxly_minikube_temp_dir
fi

# Build minikube and copy the binary to /usr/local/bin/
make
cp "$awxly_minikube_temp_dir/out/minikube" /usr/local/bin/.
cd ~

# Download and copy the kustomize binary to /usr/local/bin/
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
mv kustomize /usr/local/bin/.

# Copy the bash profile to the home directory
# The bash profile will ensure that docker is running
cp "$awxly_install_dir/.profile" ~/.
cp "$awxly_install_dir/.bashrc" ~/.

# Invoke the bashrc file to ensure the startup sequence has been initiated
./.bashrc

# Output the Docker version
docker --version
# Create helper scripts to control minikube
cp "$awxly_install_dir/minikube-start.sh" ~/.
cp "$awxly_install_dir/minikube-tunnel.sh" ~/.
sed -i "s#awxly_k8s_dir#$awxly_k8s_dir#" ~/minikube-start.sh
sed -i "s#awx_tunnel_port#$awx_tunnel_port#" ~/minikube-tunnel.sh
chmod +x ~/minikube-start.sh && chmod +x ~/minikube-tunnel.sh
# Prepare a cluster in minikube
./minikube-start.sh
# Create an alias for kubectl since minikube will be handling the calls
alias kubectl="minikube kubectl --"
# Wait for all pods in the cluster to be ready
echo "Waiting for minikube pods to be ready..."
kubectl wait --for=condition=ready --timeout=90s --all-namespaces --all pods
# Display all pods in the output
kubectl get pods -A

# Determine the path to the template kustomization.yaml file
export awx_manifest_path="$awxly_install_dir/kustomization.yaml"
# Determine the latest version of awx-operator
export awx_latest_version=$(wget -q -O - https://api.github.com/repos/ansible/awx-operator/releases/latest | jq -r ".tag_name")
# Create a kustomization.yaml file in the home directory with the latest awx-operator version
sed "s#<tag>#$awx_latest_version#" $awx_manifest_path > ~/kustomization.yaml

# Add all of the generic awx-operator components into the cluster
kustomize build . | kubectl apply -f -
# Set the default kubectl namespace to awx
kubectl config set-context --current --namespace=awx
# Wait for the awx-operator pods to become ready
echo "Waiting for kubernetes pods in the awx namespace to be ready... (this may take awhile)"
kubectl wait --for=condition=ready --timeout=300s --all-namespaces --all pods

# Copy the awx-app.yaml file from the WSL host install directory
cp "$awxly_install_dir/awx-app.yaml" ~/.
# Swap out the placeholder for the awx-app resource in the kustomization.yaml file
sed -i "s/#<awx-app>/- awx-app.yaml/" ~/kustomization.yaml
# Run kustomize to create the awx-app instance in the cluster
kustomize build . | kubectl apply -f -