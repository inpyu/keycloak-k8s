#!/bin/bash

function make-certs()
{
        cd certs

        openssl req -x509 -new -nodes -newkey rsa:2048 -keyout CA.key -sha256 -days 825 -out CA.pem -subj "/O=Genians/CN=Self CA"

        #Generate keycloak server key:
        openssl genrsa -out tls.key 2048

        #Generate keycloak certificate signing request:
        openssl req -new -key tls.key -out tls.csr -subj "/O=Genians/CN=sdevtest"

        >tls.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
extendedKeyUsage=serverAuth
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kc.sdev.genians.kr
EOF

        #Sign keycloak CSR using CA key to generate server certificate:
        openssl x509 -req -days 3650 -in tls.csr -CA CA.pem -CAkey CA.key -CAcreateserial -out tls.crt -extfile tls.ext

        #Convert Keycloak cert to pkcs12 format:
        #openssl pkcs12 -export -in keycloak.crt -inkey keycloak.key -out keycloak.p12 -name myserverkeystore -CAfile ca.crt
        cd ..
}

#./kc.sh start-dev --https-port=8081 --https-certificate-file=keycloak-server.crt.pem --https-certificate-key-file=keycloak-server.key.pem

#make-certs

function create-tls-scret()
{
	kubectl create secret -n default tls kc-tls-secret --key ./tls.key --cert ./tls.crt
}

create-tls-scret
