RUNNING=`ps aux | grep dockerd | grep -v grep`
if [ -z "$RUNNING" ]; then
	nohup dockerd > /dev/null 2>&1 &
fi

alias kubectl="minikube kubectl --"