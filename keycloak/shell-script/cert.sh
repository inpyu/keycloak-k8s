#!/bin/bash

# Prompt the user for SSL certificate subject information
echo "Enter the SSL certificate subject information:"
read -p "Country (2 letter code, e.g., US): " country
read -p "State or Province Name (full name, e.g., California): " state
read -p "Locality Name (e.g., city): " locality
read -p "Organization Name (e.g., company): " org
read -p "Organizational Unit Name (e.g., section): " org_unit
read -p "Common Name (e.g., domain name): " common_name

# Generate the SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ingresstls.key -out ingresstls.cert -subj "/C=$country/ST=$state/L=$locality/O=$org/OU=$org_unit/CN=$common_name"

# Create the Ingress YAML file
cat <<EOF > keycloak-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
spec:
  tls:
  - hosts:
    - $common_name
    secretName: httpstls
  rules:
  - host: $common_name
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 30001
EOF

# Apply the Ingress to the Kubernetes cluster
kubectl apply -f keycloak-ingress.yaml

# Clean up the temporary files
rm ingresstls.key ingresstls.cert keycloak-ingress.yaml