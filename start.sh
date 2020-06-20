# rm -rf ~/.minikube
# mkdir -p ~/goinfre/minikube
# ln -s ~/goinfre/minikube ~/.minikube

# open --background -a Docker

# ./clean.sh
minikube delete

minikube start --vm-driver=virtualbox \
--extra-config=apiserver.service-node-port-range=1-35000 \
--bootstrapper=kubeadm \
--extra-config=kubelet.authentication-token-webhook=true

minikube addons enable ingress
minikube addons enable dashboard

echo "Eval..."
eval $(minikube docker-env)
export MINIKUBE_IP=$(minikube ip)
IP=$(kubectl get node -o=custom-columns='DATA:status.addresses[0].address' | sed -n 2p)
printf "Minikube IP: ${MINIKUBE_IP}, get node: ${IP}\n"

sed "s/MINIKUBE_IP/$MINIKUBE_IP/g" srcs/nginx/homepage-pde-bakk/beforesed.html > srcs/nginx/homepage-pde-bakk/index.html
echo "Building images..."
docker build -t nginx_alpine ./srcs/nginx/
docker build -t ftps_alpine --build-arg IP=${IP} ./srcs/ftps/
docker build -t service_influxdb ./srcs/influxdb
docker build -t grafana_alpine ./srcs/grafana

sleep 10
kubectl apply -k ./srcs/
# ./apply.sh

# echo "\n\nHier: http://$MINIKUBE_IP"
echo "Opening the network in your browser..."
open http://$MINIKUBE_IP

# minikube dashboard
# To enter terminal:
# kubectl run -i --tty busybox --image=busybox --restart=Never -- sh 