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

function installHelm {
  if [ -f /usr/local/bin/helm ];
  then
    echo "helm already exists"
  else
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod +x get_helm.sh
    ./get_helm.sh
    rm get_helm.sh
    echo "Helm Installed"
  fi
}
#function to install minikube
function installMiniKube {
  if [ -f /usr/local/bin/minikube ];
  then
    echo "minikube already installed.."
  else
    sudo apt update -y
    sudo apt install curl apt-transport-https virtualbox virtualbox-ext-pack wget -y
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
    minikube addons enable volumesnapshots
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

#function generate docker secret for thumbnail generator
function kubeSecret {
kubectl create secret docker-registry regcred -n thumbnail-generator\
  --docker-server=$DOCKER_REGISTRY_SERVER \
  --docker-username=$DOCKER_USER \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL
}

#function to wait for pods in specific pod
function waitForPods {
  namespace=$1
  pods=$(kubectl get pod -n ${namespace} | awk 'NR>1{print $1}')
  for pod in ${pods}
  do
    echo "waiting for ${pod} in ${namespace}"
    while [[ $(kubectl get pods ${pod} -n ${namespace} -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
      sleep 10s
      echo "Sleeping for 10s to wait..Ctrl+C to cancel"
    done
    echo "${pod} is in running state"
  done
}

#function to install argo cli
function installArgoCli {
  if [ -f /usr/local/bin/argocd ];
  then
    echo "argocli already installed"
  else 
  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  sudo chmod a+x argocd
  sudo mv argocd /usr/local/bin/argocd
  fi
}

#function to do argologin and install github private repo
function argoLogin {
  argoURL=$(minikube service argocd-server -n argocd --url | tail -n 1 | sed -e 's|http://||') 
  while [[ $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) == "" ]]
  do
    echo "Password not generated..sleeping for 10s"
    sleep 10s
  done
  argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  argocd login --insecure --grpc-web $argoURL  --username admin --password $argoPass
  argocd repo  add ${git_repo} --username ${git_username} --password ${git_token} --insecure-skip-server-verification
}

#function to install argo helm chart inside kubernetes cluster
function installArgo {
  minikube addons enable ingress
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  installArgoCli
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  waitForPods argocd
  argoLogin
}

#function to fetch argo login details
function argoDetails {
  argoURL=$(minikube service argocd-server -n argocd --url | tail -n 1 | sed -e 's|http://||')
  argoPass=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
  echo "Username: admin"
  echo "Password: "$argoPass
  echo "Click on the URL to go to GUI: "$argoURL
  echo "logging into argocd cli"
}

#function to install prometheus adaptor helm chart
function installPrometheusAdaptor {
  git_root_dir=$(git rev-parse --show-toplevel)
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install prometheus-adapter prometheus-community/prometheus-adapter -f ${git_root_dir}/deployments/dev/values/prometheus-adaptor.yaml
  echo "Waiting for applying the changes"
  sleep 10s
  waitForPods default
}
#function to install all the components
function installAll {
  installKubeCtl
  installHelm
  installMiniKube
  deleteMiniKube
  startMiniKube
  kubectl create namespace thumbnail-generator 
  kubectl create namespace minio
  kubectl create namespace mongo
  kubectl create namespace prometheus
  kubeSecret
  installArgo
  echo "Waiting for 15s"
  sleep 15s
  git_root_dir=$(git rev-parse --show-toplevel)
  echo "Deploying Minio argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/minio.yaml
  echo "Deploying Mongo argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/mongo.yaml
  echo "Deploying prometheus project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/prometheus.yaml
  echo "Waiting for 20s"
  sleep 30s
  waitForPods minio
  waitForPods mongo
  echo "Deploying thumbnail argocd project"
  kubectl apply -f ${git_root_dir}/deployments/dev/argocd/thumbnail-generator.yaml
  waitForPods default
  waitForPods thumbnail-generator
  installPrometheusAdaptor
  echo ""
  argoDetails
}

function help {
  echo "Try these parameters instead"
  echo "bash ${0} <options>"
  echo -e "\noptions:"
  echo -e "\n  installKubeCtl\n  installMiniKube\n installPrometheusAdaptor\n  installHelm\n  startMiniKube\n  stopMiniKube\n  restartMiniKube\n  deleteMiniKube\n  reprovisionMiniKube\n  kubeSecret\n  installArgo\n  argoDetails\n  installAll\n  help\n"
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
  *argoDetails*)
  $command
  ;;
  *installHelm*)
  $command
  ;;
  *installPrometheusAdaptor*)
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