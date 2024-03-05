#!/bin/bash

# Prompt the user for the MySQL password
echo -n "Enter the MySQL password: "
read password

# Encode the password to base64
password_base64=$(echo -n "$password" | base64)

# Create the mysql-pvc-secret.yaml file with the user input
cat <<EOF > mysql-pvc-secret.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block
  volumeMode: Filesystem
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  password: $password_base64
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0.26
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        ports:
        - containerPort: 3306
      volumes:
      - name: mysql-pvc
        persistentVolumeClaim:
          claimName: mysql-pvc
EOF

# Apply the Secret to the Kubernetes cluster
kubectl apply -f mysql-pvc-secret.yaml

# Step 2: Create Keycloak Database
mysql_pod_name=$(kubectl get pods -l app=mysql -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it "$mysql_pod_name" -- mysql -uroot -p$(kubectl get secret mysql-secret -o jsonpath="{.data.password}" | base64 --decode) -e "CREATE DATABASE keycloak;"

# Clean up the temporary file
rm mysql-pvc-secret.yaml