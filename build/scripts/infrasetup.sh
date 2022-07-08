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

function help {
  echo "Try these parameters instead"
  echo "bash ${0} <options>"
  echo -e "\noptions:"
  echo -e "\n  installKubeCtl\n  installMiniKube\n  startMiniKube\n  stopMiniKube\n  restartMiniKube\n  deleteMiniKube\n  reprovisionMiniKube\n  help\n"
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
  *help*)
  help
  ;;
  *)
  echo -e "${command} command not found\n"
  help
esac