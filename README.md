# estore-infra

minikube start

docker logout
docker login

eval $(minikube docker-env)

build the container

set imagePullPolicy: Never in deployment.yaml