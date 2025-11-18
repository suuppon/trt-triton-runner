#!/usr/bin/env bash
set -e

# ============================
# Basic Configuration
# ============================
MODEL_REPOSITORY_PATH="${MODEL_REPOSITORY_PATH:-$(pwd)/models}"
MODEL_SOURCE_PATH="${MODEL_SOURCE_PATH:-$(pwd)/src}"

TRITON_MODEL_REPOSITORY_PATH="/models"
TRITON_MODEL_SOURCE_PATH="/src"

CONTAINER_NAME="${TRITON_CONTAINER_NAME:-triton_server}"
NETWORK_NAME="${NETWORK_NAME:-triton-net}"

# TRITON_TAG / TRITON_IMAGE can be overridden via environment variables
#   Example: TRITON_TAG=24.12 ./run_triton_container.sh
#            TRITON_IMAGE=nvcr.io/nvidia/tritonserver:25.08-py3-igpu ./run_triton_container.sh

# ============================
# Jetson / Non-Jetson + L4T Detection
# ============================
ARCH=$(uname -m)
IS_JETSON=0
L4T_MAJOR=""
L4T_MINOR=""

if [[ -f /etc/nv_tegra_release ]]; then
  IS_JETSON=1
  # /etc/nv_tegra_release example: "# R36 (release), REVISION: 4.7, ..."
  L4T_MAJOR=$(grep -o "R[0-9]*" /etc/nv_tegra_release | head -n1 | tr -d 'R')
  L4T_MINOR=$(grep -o "REVISION: *[0-9]*\.[0-9]*" /etc/nv_tegra_release | head -n1 | awk -F'[ :.]' '{print $3}')
fi

if [[ "$IS_JETSON" -eq 1 ]]; then
  echo "🟢 Detected Jetson (arch=${ARCH}, L4T=${L4T_MAJOR}.${L4T_MINOR}.*)"
else
  echo "💻 Non-Jetson environment (arch=${ARCH})"
fi

# ============================
# Triton Image Auto-tag Selection
# ============================
if [[ -n "$TRITON_IMAGE" ]]; then
  IMAGE="$TRITON_IMAGE"
else
  if [[ "$IS_JETSON" -eq 1 ]]; then
    # Jetson → -py3-igpu image
    if [[ -n "$TRITON_TAG" ]]; then
      TAG="$TRITON_TAG"
    else
      # Default based on support matrix
      if [[ -n "$L4T_MAJOR" ]] && (( L4T_MAJOR >= 36 )); then
        # JetPack 6.x (L4T 36.x)
        TAG="25.10"
      elif [[ -n "$L4T_MAJOR" ]] && (( L4T_MAJOR == 35 )); then
        # JetPack 5.x
        TAG="24.08"
      else
        # Older versions
        TAG="23.12"
      fi
    fi
    IMAGE="nvcr.io/nvidia/tritonserver:${TAG}-py3-igpu"
  else
    # Non-Jetson → standard py3 image
    TAG="${TRITON_TAG:-25.10}"
    IMAGE="nvcr.io/nvidia/tritonserver:${TAG}-py3"
  fi
fi

echo "📦 Triton image: ${IMAGE}"

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
# Start Triton Container
# ============================
echo "🚀 Starting Triton Inference Server: ${CONTAINER_NAME}"

RUN_ARGS=(
  --runtime=nvidia
  --rm -it -d
  --name "${CONTAINER_NAME}"
  --network "${NETWORK_NAME}"
  -p 8000:8000
  -p 8001:8001
  -p 8002:8002
  -v "${MODEL_REPOSITORY_PATH}:${TRITON_MODEL_REPOSITORY_PATH}"
  -v "${MODEL_SOURCE_PATH}:${TRITON_MODEL_SOURCE_PATH}"
)

docker run "${RUN_ARGS[@]}" "${IMAGE}" tritonserver \
  --model-repository="${TRITON_MODEL_REPOSITORY_PATH}"

echo "✅ Triton up."
echo "   HTTP   : http://localhost:8000/v2/health/ready"
echo "   gRPC   : localhost:8001"
echo "   Metrics: http://localhost:8002/metrics"
echo "   Container: ${CONTAINER_NAME}"