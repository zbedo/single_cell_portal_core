#!/usb/bin/env bash

set -eu

# Burp private Docker image URL (this assumes the client was already
# authenticated with container registry using burp_start.sh)
IMAGE="$1"

# Scan collected traffic and report results (optional)
docker run --rm -it --entrypoint python3 "${IMAGE}" BroadBurpScanner.py http://localhost --action scan
