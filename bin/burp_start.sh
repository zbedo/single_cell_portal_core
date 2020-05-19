#!/usr/bin/env bash

set -eu

IMAGE="$1" # Burp private Docker image URL
BASE64_KEY="$2" # base64-encoded Service Account Key JSON to pull the image from container registry

# Authenticate with container registry
REGISTRY=$(echo "${IMAGE}" | awk -F/ '{print $1}')
echo "${BASE64_KEY}" | docker login -u _json_key_base64 --password-stdin "https://${REGISTRY}"

# Start Burp container in the background
docker run --rm -d -p 8080:8080 -p 8081:8081 --net host "${IMAGE}"

# Update iptables so all "under test" container traffic is proxied through the Burp container
sudo iptables -t nat -A PREROUTING -p tcp -m multiport --dport 80,443 -j REDIRECT --to-ports 8080
