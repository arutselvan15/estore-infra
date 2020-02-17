#!/usr/bin/env bash

set -e

usage() {
    cat <<EOF
Generate certificate suitable for use with an sidecar-injector webhook service.
This script uses k8s' CertificateSigningRequest API to a generate a
certificate signed by k8s CA suitable for use with sidecar-injector webhook
services. This requires permissions to create and approve CSR. See
https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster for
detailed explantion and additional instructions.
The server key/cert k8s CA cert are stored in a k8s secret.

usage: ${0} [OPTIONS]
The following flags are required.
       --service          Service name of webhook.
       --namespace        Namespace where webhook service and secret reside.
       --name             Certificate file to store in local disk.
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case ${1} in
        --service)
            service="$2"
            shift
            ;;
        --name)
            name="$2"
            shift
            ;;
        --namespace)
            namespace="$2"
            shift
            ;;
        *)
            usage
            ;;
    esac
    shift
done

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

certDir="./certs"
keyFile="${certDir}/${name}.key"
csrFile="${certDir}/${name}.csr"
certFile="${certDir}/${name}.crt"
cn="/CN=${service}.${namespace}.svc"

caCert="${certDir}/ca.crt"
caKey="${certDir}/ca.key"

if [ -f "${certFile}" ]; then
  echo "Certificate file ${certFile} already exists ..."
else
  openssl genrsa -out "${keyFile}" 2048
  openssl req -new -key "${keyFile}" -out "${csrFile}" -subj "${cn}" -config csr.conf
  openssl x509 -req -in "${csrFile}" -CA "${caCert}" -CAkey "${caKey}" -CAcreateserial -out "${certFile}" -days 100000 -extensions v3_req -extfile csr.conf
  echo "Certificate file ${certFile} generated ..."
fi


## use kube to generate cert, this can be done using openssl command also
genCertUsingKube (){
  tmpdir=$(mktemp -d)
  openssl genrsa -out ${tmpdir}/server-key.pem 2048
  openssl req -new -key ${tmpdir}/server-key.pem -subj "/CN=${service}.${namespace}.svc" -out ${tmpdir}/server.csr -config ${tmpdir}/csr.conf

  # clean-up any previously created CSR for our service. Ignore errors if not present.
  kubectl delete csr ${name} 2>/dev/null || true

  # create  server cert/key CSR and  send to k8s API
  cat <<EOF | kubectl create -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${name}
spec:
  groups:
  - system:authenticated
  request: $(cat ${tmpdir}/server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

  # verify CSR has been created
  while true; do
      kubectl get csr ${name}
      if [ "$?" -eq 0 ]; then
          break
      fi
  done

  # approve and fetch the signed certificate
  kubectl certificate approve ${name}
  # verify certificate has been signed
  for x in $(seq 10); do
      serverCert=$(kubectl get csr ${name} -o jsonpath='{.status.certificate}')
      if [[ ${serverCert} != '' ]]; then
          break
      fi
      sleep 1
  done
  if [[ ${serverCert} == '' ]]; then
      echo "ERROR: After approving csr ${name}, the signed certificate did not appear on the resource. Giving up after 10 attempts." >&2
      exit 1
  fi
  echo ${serverCert} | openssl base64 -d -A -out ${tmpdir}/server-cert.pem
}