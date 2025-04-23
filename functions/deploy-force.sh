#!/bin/bash

echo "Forcing deployment of all Firebase functions..."

# Delete the node_modules folder to force a clean install
rm -rf node_modules

# Clean the .firebase cache directory
rm -rf .firebase

# Install dependencies
npm install

# Modify the package.json version to force a new deployment
TIMESTAMP=$(date +%s)
sed -i "s/\"version\": \".*\"/\"version\": \"1.0.${TIMESTAMP}\"/" package.json

# Deploy only the functions with force option
firebase deploy --only functions --force

echo "Deployment completed!" 