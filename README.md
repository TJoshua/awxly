# Awxly

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A [WSL2](https://docs.microsoft.com/en-us/windows/wsl/about) distribution initializer to deploy [Ansible AWX](https://github.com/ansible/awx) using [Ansible AWX Operator](https://github.com/ansible/awx-operator) in a [minikube](https://github.com/kubernetes/minikube) environment running under [Alpine Linux](https://www.alpinelinux.org).

# Table of Contents

* [Awxly](#awxly)
* [Table of Contents](#table-of-contents)
   * [Purpose](#purpose)
   * [Usage](#usage)
      * [Requirements](#requirements)
      * [Installation](#installation)
	  * [Management](#management)
      * [Uninstall](#uninstall)
   * [Planned Features](#planned-features)
   * [Author](#author)

## Purpose

To provide an easily deployed and persistable instance of [Anisble AWX](https://www.ansible.com/products/awx-project/faq) within Windows, ideally for home usage, development environments, or demonstrations.

## Usage

Awxly is a set of scripts used to create a WSL distribution within Windows containing Ansible AWX.

### Requirements

  * Windows 10 (Build 19041+) and higher
  * [WSL2](https://docs.microsoft.com/en-us/windows/wsl/install)
  * [Windows PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
  * [Windows Terminal](https://apps.microsoft.com/store/detail/windows-terminal/9N0DX20HK701) (recommended)

### Installation

Start by extracting or cloning an Awxly release to a directory of choice. Awxly uses two directories for storage. By default, both of these directories will be created within the directory containing the Awxly installation script.

The `awxly-install.ps1` PowerShell script uses the following parameters:

```
.\awxly-install.ps1 <storageDirectory> <tempDirectory> <tunnelPort>
```

**Parameter Information**
  
| Name             | Required | Description                                                    | Default       |
| ---------------- | -------- | -------------------------------------------------------------- | ------------- |
| storageDirectory | No       | The full Windows path to the Awxly storage directory           | `cwd`\storage |
| tempDirectory    | No       | The full Windows path to the Awxly temporary directory         | `cwd`\temp    |
| tunnelPort       | No       | The desired port to use to access the AWX web interface        | 5000          |

After determining which parameters to use, invoke the `awxly-install.ps1` PowerShell script with the desired values and wait for it to finish. Depending on your system, it may take awhile to fully complete.

Once complete, a WSL distribution will be available in Windows Terminal as `Awxly-<version>`. It will be actively running Docker and minikube after installation.

### Management

It is worth noting that if the Windows host is rebooted, Docker and minikube will no longer be running. The Alpine Linux distribution that Awxly configures is set up with a `.bashrc` file to ensure Docker is running when entering an Awxly shell.

Since Docker will be implicitly started upon entering an Awxly shell, minikube is the only component that needs started manually. A helper script, `minikube-start.sh`, is provided in the root user's home directory for this purpose:

```
./minikube-start.sh
```

The `.bashrc` file will also configure a `kubectl` command alias to ease cluster management with minikube. To check the status of the AWX cluster components, run the following command:

```
kubectl get pods -n awx
```

Once all of the AWX pods are ready, the AWX user interface may be accessed from the Windows host by running the `minikube-tunnel.sh` helper script in the root user's home directory.

```
./minikube-tunnel.sh
```

> :warning: The tunnel script must be actively running in order to access the AWX user interface from the Windows host.

The default login credentials are `admin`/`awxly`, which can be changed after logging in.

### Uninstall

Currently, the uninstall script will remove all WSL distributions of Awxly. To uninstall, run the following PowerShell script:

```
.\awxly-uninstall.ps1
```

> :warning: Currently the installer script places an `Awxly-<version>.metadata` file in the Awxly directory to indicate which versions are installed. The uninstall script will also use these to determine the distributions to uninstall within WSL.

The uninstall script will remove the custom WSL distribution from Windows and delete the Linux filesystem that was used. Note that this does **NOT** delete the persistent storage directory where AWX stores its data, which allows the data to be managed independently.

## Planned Features

  * Use the current AWX Operator release tag in the Awxly WSL distribution name
  * Allow the user to provide additional scripts to be invoked during installation or in the `.bashrc` file (use case: environment variables like `http_proxy`)
  * Provide the ability when installing/uninstalling to specify the version to install/uninstall
  * Use WSL commands to determine installed versions of Awxly instead of the current metadata files

## Author

This project was created in 2022 by [TJoshua](https://github.com/TJoshua).