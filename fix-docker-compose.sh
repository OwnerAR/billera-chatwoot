#!/bin/bash
# Script untuk fix docker-compose.production.yaml di server

# Backup file lama
cp docker-compose.production.yaml docker-compose.production.yaml.backup

# Update image name
sed -i 's|image: billera-chatwoot:latest|image: etan1997/billera-chatwoot:latest|g' docker-compose.production.yaml

echo "File sudah diupdate. Cek dengan: grep 'image:' docker-compose.production.yaml"

