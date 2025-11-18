#!/usr/bin/env bash
set -e

# ============================
# Configuration (can be overridden via environment variables)
# ============================
WORKDIR="${WORKDIR:-$(pwd)}"
NETWORK_NAME="${NETWORK_NAME:-triton-net}"
CONTAINER_NAME="${TENSORRT_CONTAINER_NAME:-tensorrt_dev}"

# TENSORRT_TAG / TENSORRT_IMAGE can be manually specified
#   Example: TENSORRT_TAG=25.10-py3 ./run_tensorrt_container.sh
#            TENSORRT_IMAGE=nvcr.io/nvidia/tensorrt:25.10-py3 ./run_tensorrt_container.sh

# ============================
# Jetson / Non-Jetson Detection
# ============================
IS_JETSON=0
if [[ -f /etc/nv_tegra_release ]]; then
  IS_JETSON=1
fi

# ============================
# TensorRT Image Auto-selection
# ============================
if [[ -n "$TENSORRT_IMAGE" ]]; then
  IMAGE="$TENSORRT_IMAGE"
else
  if [[ "$IS_JETSON" -eq 1 ]]; then
    # Jetson: Read TensorRT version from host libnvinfer.so and select l4t-tensorrt:rX.Y.Z-devel
    TRT_VERSION_FULL=$(strings /usr/lib/aarch64-linux-gnu/libnvinfer.so 2>/dev/null | grep "TensorRT" | head -n1 | awk '{print $2}')
    if [[ -z "$TRT_VERSION_FULL" ]]; then
      echo "❌ Could not detect TensorRT version from /usr/lib/aarch64-linux-gnu/libnvinfer.so"
      echo "   Please specify TENSORRT_IMAGE manually."
      exit 1
    fi

    TRT_VERSION_SHORT=$(echo "$TRT_VERSION_FULL" | awk -F. '{print $1"."$2"."$3}')
    TAG="${TENSORRT_TAG:-r${TRT_VERSION_SHORT}-devel}"
    IMAGE="nvcr.io/nvidia/l4t-tensorrt:${TAG}"
  else
    # Non-Jetson: Server TensorRT image (modify as needed)
    TAG="${TENSORRT_TAG:-25.10-py3}"
    IMAGE="nvcr.io/nvidia/tensorrt:${TAG}"
  fi
fi

echo "📦 TensorRT image: ${IMAGE}"

# ============================
# Docker Network Setup
# ============================
if [[ -n "$NETWORK_NAME" ]]; then
  if ! docker network ls | grep -q "${NETWORK_NAME}"; then
    echo "🌐 Creating docker network: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" >/dev/null
  else
    echo "🌐 Using existing docker network: ${NETWORK_NAME}"
  fi
fi

# Clean up existing container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "🧹 Removing existing container: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# ============================
# Start Container
# ============================
echo "🚀 Starting TensorRT dev container: ${CONTAINER_NAME}"

RUN_ARGS=(
  --runtime=nvidia
  --rm -it -d
  --name "${CONTAINER_NAME}"
  -v "${WORKDIR}":/workspace
  -w /workspace
)

if [[ -n "$NETWORK_NAME" ]]; then
  RUN_ARGS+=( --network "${NETWORK_NAME}" )
fi

docker run "${RUN_ARGS[@]}" "${IMAGE}" bash

echo "✅ Started container '${CONTAINER_NAME}'"
echo "   - workdir (host): ${WORKDIR}"
echo "   - workdir (ctr) : /workspace"
echo "   Example exec: ./trtexec.sh --onnx=ckpt_best_409.onnx --saveEngine=ckpt_best_409.plan --fp16"