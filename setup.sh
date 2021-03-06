#!/bin/bash
red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
blu=$'\e[1;34m'
mag=$'\e[1;35m'
cyn=$'\e[1;36m'
end=$'\e[0m'
rm -rf ~/.minikube
mkdir -p ~/goinfre/.minikube
ln -s ~/goinfre/.minikube ~/.minikube

:> errlog.txt
:> log.log
# minikube delete
sh cleanup.sh >> log.log 2>> /dev/null

minikube start	--vm-driver=virtualbox \
				--cpus=2 --memory 3000 \
				--addons metrics-server \
  				--extra-config=kubelet.authentication-token-webhook=true

minikube addons enable metallb >> log.log 2>>errlog.txt && sleep 2 && kubectl apply -f ./srcs/metallb.yaml >> log.log 2>>errlog.txt
minikube addons enable default-storageclass >> log.log 2>> errlog.txt
minikube addons enable storage-provisioner >> log.log 2>> errlog.txt
minikube addons enable dashboard >> log.log 2>> errlog.txt
eval $(minikube docker-env)
export MINIKUBE_IP=$(minikube ip)

printf "Building and deploying ftps:\t\t"
docker build -t ftps_alpine ./srcs/ftps > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f ./srcs/ftps.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

printf "Building and deploying mysql:\t\t"
docker build -t mysql_alpine ./srcs/mysql > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f ./srcs/mysql.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

printf "Building and deploying wordpress:\t"
docker build -t wordpress_alpine ./srcs/wordpress > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f ./srcs/wordpress.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

printf "Building and deploying phpmyadmin:\t"
docker build -t phpmyadmin_alpine ./srcs/phpmyadmin > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f ./srcs/phpmyadmin.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n";

printf "Building and deploying influxdb:\t"
docker build -t influxdb_alpine srcs/influxdb > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f srcs/influxdb.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

printf "Building and deploying telegraf:\t"
docker build -t telegraf_alpine --build-arg INCOMING=${MINIKUBE_IP} srcs/telegraf > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f srcs/telegraf.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

printf "Building and deploying grafana:\t\t"
docker build -t grafana_alpine ./srcs/grafana > /dev/null 2>>errlog.txt && { printf "[${grn}OK${end}]\n"; kubectl apply -f ./srcs/grafana.yaml >> log.log 2>> errlog.txt; } || printf "[${red}NO${end}]\n"

sleep 3;
WORDPRESS_IP=`kubectl get services | awk '/wordpress-svc/ {print $4}'`
PHPMYADMIN_IP=`kubectl get services | awk '/phpmyadmin-svc/ {print $4}'`
GRAFANA_IP=`kubectl get services | awk '/grafana-svc/ {print $4}'`
sed -e "s/GRAFANA_IP/$GRAFANA_IP/g" -e "s/WORDPRESS_IP/$WORDPRESS_IP/g" -e "s/PHPMYADMIN_IP/$PHPMYADMIN_IP/g" srcs/nginx/homepage-pde-bakk/beforesed.html > srcs/nginx/homepage-pde-bakk/index.html

printf "Building and deploying nginx:\t\t"
docker build -t nginx_alpine ./srcs/nginx > /dev/null 2>>errlog.txt && printf "[${grn}OK${end}]\n" || printf "[${red}NO${end}]\n"; kubectl apply -f ./srcs/nginx.yaml >> log.log 2>> errlog.txt

kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)" >> log.log 2>> errlog.txt
