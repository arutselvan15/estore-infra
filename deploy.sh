#!/usr/bin/env bash

set -e

ns="estore-infra"
rootDir=$(pwd)
certsDir="$rootDir/webhooks/certs"
webhookCertSecretTmpl="$rootDir/webhooks/tmpl/webhook-cert-secret.tmpl"


enableWebhook (){
  echo "Enable webhook ..."
  kubectl api-versions | grep admissionregistration.k8s.io/v1beta1

	# enable webhooks
  # kubectl --enable-admission-plugins=MutatingAdmissionWebhook,ValidatingAdmissionWebhook
}

genCaCert (){
  echo "Generate CA cert ..."
  cd "$rootDir/webhooks" && sh gen-ca-cert.sh
}

genWebhookCerts (){
  echo "Generate webhook cert $1 ..."
  cd "$rootDir/webhooks" && sh gen-webhook-cert.sh --namespace "$ns" --name "$1" --service "$1"-service
}

webhooks (){
  enableWebhook
  genCaCert

  ca_pem_b64="$(openssl base64 -A <"$certsDir/ca.crt")"

  for file in "$rootDir"/webhooks/*.yaml; do
    echo "Apply webhook $file ..."
    webhookName=$(basename "$file")
    webhookName=${webhookName/.yaml/}

    genWebhookCerts "$webhookName"

    cert_pem_b64="$(openssl base64 -A <"$certsDir/$webhookName.crt")"
    key_pem_b64="$(openssl base64 -A <"$certsDir/$webhookName.key")"

    sed -e 's/__NAME__/'"$webhookName"'/g' -e 's/__CERT_B64__/'"$cert_pem_b64"'/g' -e 's/__KEY_B64__/'"$key_pem_b64"'/g' <"$webhookCertSecretTmpl" | kubectl apply -f -
    sed -e 's/__CA_BUNDLE_B64__/'"$ca_pem_b64"'/g' <"$file" | kubectl apply -f -
    separator
  done

  cd "$rootDir"
}

example (){
	kubectl apply -f examples/product.yaml
}

kubeapply (){
  for file in "$1"/*.yaml; do
    echo "Apply $file ..."
    kubectl apply -f "$file"
  done
}

banner (){
  echo "==============================="
  echo "$1"
  echo "==============================="
}

separator(){
  printf "\n\n\n"
}

main (){
  echo "=== Deployment started ==="
  separator

  banner "Deploying namespaces..."
  kubeapply namespaces
  separator

   # switch to infra namespace
	kubectl config set-context --current --namespace=estore-infra
  separator

  banner "Deploying service accounts..."
  kubeapply serviceaccounts
  separator

  banner "Deploying rbacs..."
  kubeapply rbac
  separator

  banner "Deploying config maps..."
  kubeapply configmaps
  separator

  banner "Deploying secrets..."
  kubeapply secrets
  separator

  banner "Deploying crds..."
  kubeapply crds
  separator

  banner "Deploy webhooks ..."
  webhooks

  banner "Deploying deployments..."
  kubeapply deployments

  echo "=== Deployment completed ==="
}

main