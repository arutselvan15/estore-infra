#!/usr/bin/env bash

set -e

certDir="./certs"
certFile="${certDir}/ca.crt"
keyFile="${certDir}/ca.key"
cn="/CN=admission_ca"

if [ ! -x "$(command -v openssl)" ]; then
    echo "openssl not found"
    exit 1
fi

if [ -f "${certFile}" ]; then
  echo "Certificate file ${certFile} already exists ..."
else
  openssl genrsa -out ${keyFile} 2048
  openssl req -x509 -new -nodes -key ${keyFile} -days 100000 -out ${certFile} -subj ${cn}
  echo "Certificate file ${certFile} generated ..."
fi
