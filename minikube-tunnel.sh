#!/bin/bash -i

kubectl port-forward svc/awx-app-service awx_tunnel_port:80