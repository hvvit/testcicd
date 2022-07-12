#!/bin/bash

command=$1
#function to install kubectl
function installKubeCtl {
  if [ -f /usr/local/bin/kubectl ];
  then
    echo "kubectl already installed.."
  else
    sudo apt update -y
    sudo apt install curl apt-transport-https -y
    curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    kubectl version -o json
  fi
}

#function to install minikube
function installMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    echo "minikube already installed.."
  fi
  sudo apt update -y
  sudo apt install curl apt-transport-https virtualbox virtualbox-ext-pack wget -y
  if [ $? == "0" ];
  then
    wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo mv minikube-linux-amd64 /usr/local/bin/minikube
    sudo chmod 755 /usr/local/bin/minikube
    minikube version
  fi
}

#function to start minikube
function startMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    minikube start
    minikube addons enable metrics-server
  else 
    echo "minikube not installed"
  fi
}

#function to stop Minikube
function stopMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    minikube stop
  else 
    echo "minikube not installed"
  fi
}

#function to restart Minikube
function restartMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    stopMiniKube
    startMiniKube
  else 
    echo "minikube not installed"
  fi
}

#function to delete Minikube
function deleteMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    minikube delete
  else 
    echo "minikube not installed"
  fi
}

#function to reprovision minikube
function reprovisionMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    deleteMiniKube
    startMiniKube
  else 
    echo "minikube not installed"
  fi
}

function kubeSecret {
kubectl create secret docker-registry regcred -n thumbnail-generator\
  --docker-server=$DOCKER_REGISTRY_SERVER \
  --docker-username=$DOCKER_USER \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL
}

function installArgo {
  minikube addons enable ingress
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo chmod a+x /usr/local/bin/argocd
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  echo "Username: admin"
  echo "Password: "$argoPass
  argoURL=$(minikube service argocd-server -n argocd --url | tail -n 1 | sed -e 's|http://||')
  echo "Click on the URL to go to GUI: "$argoURL
  echo "logging into argocd cli"
  argocd login --insecure --grpc-web $argoURL  --username admin --password $argoPass
  argocd repo  add ${git_repo} --username ${git_username} --password ${git_token} --insecure-skip-server-verification
}

function installAll {
  deleteMiniKube
  startMiniKube
  kubectl create namespace thumbnail-generator 
  kubectl create namespace minio
  kubectl create namespace mongo
  kubeSecret
  installArgo
  echo "Waiting for 15s"
  sleep 15s
  git_root_dir=$(git rev-parse --show-toplevel)
  echo "Deploying Minio argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/minio.yaml
  echo "Deploying Mongo argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/mongo.yaml
  echo "Waiting for 60s"
  sleep 60s
  echo "Deploying thumbnail argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/thumbnail-generator.yaml
}

function help {
  echo "Try these parameters instead"
  echo "bash ${0} <options>"
  echo -e "\noptions:"
  echo -e "\n  installKubeCtl\n  installMiniKube\n  startMiniKube\n  stopMiniKube\n  restartMiniKube\n  deleteMiniKube\n  reprovisionMiniKube\n  kubeSecret\n  installArgo\n  installAll\n  help\n"
  echo -e "for example:"
  echo "  bash ${0} installKubeCtl"
}
case "$command" in
  *installKubeCtl*)
  $command
  ;;
  *installMiniKube*)
  $command
  ;;
  *startMiniKube*)
  $command
  ;;
  *stopMiniKube*)
  $command
  ;;
  *restartMiniKube*)
  $command
  ;;
  *deleteMiniKube*)
  $command
  ;;
  *reprovisionMiniKube*)
  $command
  ;;
  *kubeSecret*)
  $command
  ;;
  *installArgo*)
  $command
  ;;
  *installAll*)
  $command
  ;;
  *help*)
  help
  ;;
  *)
  echo -e "${command} command not found\n"
  help
  ;;
esac