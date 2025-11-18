#!/usr/bin/env bash
set -e

CONTAINER_NAME="${TENSORRT_CONTAINER_NAME:-tensorrt_dev}"
TRTEXEC_PATH="${TRTEXEC_PATH:-/usr/src/tensorrt/bin/trtexec}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "❌ TensorRT container '${CONTAINER_NAME}' not running."
  echo "   Please start the container first with ./run_tensorrt_container.sh"
  exit 1
fi

echo "🚀 Running trtexec in container '${CONTAINER_NAME}'"
echo "   (workdir: /workspace)"

docker exec -it -w /workspace "${CONTAINER_NAME}" \
  "${TRTEXEC_PATH}" "$@"