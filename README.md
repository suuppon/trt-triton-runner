# TensorRT & Triton Inference Server Docker Runner

Automated Docker container management scripts for TensorRT and Triton Inference Server that automatically detect your device setup (Jetson vs. non-Jetson) and pull the appropriate Docker images.

## Overview

This repository provides shell scripts that automatically:
- **Detect your device type** (NVIDIA Jetson or standard x86_64 server)
- **Auto-select compatible Docker images** based on your hardware and software versions
- **Run containers** with proper configuration for TensorRT development and Triton Inference Server

## Features

### Automatic Device Detection
- Detects NVIDIA Jetson devices by checking `/etc/nv_tegra_release`
- Reads L4T (Linux for Tegra) version for Jetson devices
- Automatically selects appropriate Docker images:
  - **Jetson**: Uses `l4t-tensorrt` and `tritonserver:*-py3-igpu` images
  - **Non-Jetson**: Uses standard `tensorrt` and `tritonserver:*-py3` images

### TensorRT Version Auto-detection (Jetson)
- Automatically reads TensorRT version from host system's `libnvinfer.so`
- Selects matching `l4t-tensorrt:rX.Y.Z-devel` image tag

### Flexible Configuration
- All settings can be overridden via environment variables
- Supports custom image tags and full image names
- Configurable container names, network names, and paths

## Prerequisites

- Docker installed and configured
- NVIDIA Docker runtime (`nvidia-docker2` or Docker with `--runtime=nvidia` support)
- For Jetson devices: TensorRT installed on the host system (for version detection)

## Resources

- [Triton Inference Server on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/tritonserver) - Official Triton Inference Server container images
- [TensorRT on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-tensorrt) - Official TensorRT container images for Jetson (L4T)

## Scripts

### 1. `run_tensorrt_container.sh`

Starts a TensorRT development container for model optimization and engine building.

**Usage:**
```bash
./run_tensorrt_container.sh
```

**Environment Variables:**
- `WORKDIR`: Host directory to mount as `/workspace` (default: current directory)
- `TENSORRT_CONTAINER_NAME`: Container name (default: `tensorrt_dev`)
- `NETWORK_NAME`: Docker network name (default: `triton-net`)
- `TENSORRT_TAG`: Override image tag (e.g., `25.10-py3` or `r8.6.1-devel`)
- `TENSORRT_IMAGE`: Override full image name (e.g., `nvcr.io/nvidia/tensorrt:25.10-py3`)

**Examples:**
```bash
# Default (auto-detects device and TensorRT version)
./run_tensorrt_container.sh

# Specify custom tag
TENSORRT_TAG=25.10-py3 ./run_tensorrt_container.sh

# Specify full image
TENSORRT_IMAGE=nvcr.io/nvidia/tensorrt:25.10-py3 ./run_tensorrt_container.sh

# Custom work directory
WORKDIR=/path/to/models ./run_tensorrt_container.sh
```

**What it does:**
- Detects Jetson vs. non-Jetson environment
- For Jetson: Reads TensorRT version from host and selects matching `l4t-tensorrt` image
- For non-Jetson: Uses default `tensorrt:25.10-py3` image
- Creates/joins Docker network (`triton-net` by default)
- Mounts current directory (or `WORKDIR`) to `/workspace` in container
- Starts container in detached mode with bash

### 2. `run_triton_container.sh`

Starts Triton Inference Server container for model serving.

**Usage:**
```bash
./run_triton_container.sh
```

**Environment Variables:**
- `MODEL_REPOSITORY_PATH`: Host path to model repository (default: `./models`)
- `MODEL_SOURCE_PATH`: Host path to model source code (default: `./src`)
- `TRITON_CONTAINER_NAME`: Container name (default: `triton_server`)
- `NETWORK_NAME`: Docker network name (default: `triton-net`)
- `TRITON_TAG`: Override image tag (e.g., `24.12`, `25.10`)
- `TRITON_IMAGE`: Override full image name (e.g., `nvcr.io/nvidia/tritonserver:25.08-py3-igpu`)

**Examples:**
```bash
# Default (auto-detects device and selects appropriate image)
./run_triton_container.sh

# Specify custom tag
TRITON_TAG=24.12 ./run_triton_container.sh

# Specify full image
TRITON_IMAGE=nvcr.io/nvidia/tritonserver:25.08-py3-igpu ./run_triton_container.sh

# Custom model repository
MODEL_REPOSITORY_PATH=/path/to/models ./run_triton_container.sh
```

**What it does:**
- Detects Jetson vs. non-Jetson environment
- For Jetson: Selects `tritonserver:*-py3-igpu` image based on L4T version:
  - L4T 36.x (JetPack 6.x): `25.10-py3-igpu`
  - L4T 35.x (JetPack 5.x): `24.08-py3-igpu`
  - Older: `23.12-py3-igpu`
- For non-Jetson: Uses `tritonserver:25.10-py3` by default
- Creates/joins Docker network
- Mounts model repository and source directories
- Exposes ports:
  - `8000`: HTTP endpoint
  - `8001`: gRPC endpoint
  - `8002`: Metrics endpoint

**Endpoints:**
- HTTP Health: `http://localhost:8000/v2/health/ready`
- gRPC: `localhost:8001`
- Metrics: `http://localhost:8002/metrics`

### 3. `trtexec.sh`

Runs `trtexec` (TensorRT execution tool) inside the running TensorRT container.

**Usage:**
```bash
./trtexec.sh [trtexec arguments]
```

**Environment Variables:**
- `TENSORRT_CONTAINER_NAME`: Container name (default: `tensorrt_dev`)
- `TRTEXEC_PATH`: Path to trtexec in container (default: `/usr/src/tensorrt/bin/trtexec`)

**Examples:**
```bash
# Convert ONNX to TensorRT engine
./trtexec.sh --onnx=model.onnx --saveEngine=model.plan --fp16

# Benchmark existing engine
./trtexec.sh --loadEngine=model.plan --shapes=input:1x3x224x224

# Full optimization with profiling
./trtexec.sh --onnx=model.onnx --saveEngine=model.plan --fp16 --verbose --dumpLayerInfo
```

**Note:** The TensorRT container must be running (started with `run_tensorrt_container.sh`) before using this script.

## Typical Workflow

### 1. Start TensorRT Container
```bash
./run_tensorrt_container.sh
```

### 2. Convert/Optimize Models
```bash
# Convert ONNX to TensorRT engine
./trtexec.sh --onnx=model.onnx --saveEngine=model.plan --fp16

# Or interact with container directly
docker exec -it tensorrt_dev bash
```

### 3. Prepare Model Repository for Triton
```bash
# Create model repository structure
mkdir -p models/my_model/1
# Copy your model files (config.pbtxt, model.plan, etc.)
```

### 4. Start Triton Server
```bash
./run_triton_container.sh
```

### 5. Test Inference
```bash
# Check health
curl http://localhost:8000/v2/health/ready

# Send inference request (example)
curl -X POST http://localhost:8000/v2/models/my_model/infer \
  -H "Content-Type: application/json" \
  -d @inference_request.json
```

## Directory Structure

```
trt-triton-runner/
├── README.md
├── run_tensorrt_container.sh    # Start TensorRT dev container
├── run_triton_container.sh      # Start Triton Inference Server
└── trtexec.sh                   # Run trtexec in TensorRT container
```

## Image Selection Logic

### TensorRT Images

**Jetson:**
- Reads TensorRT version from `/usr/lib/aarch64-linux-gnu/libnvinfer.so`
- Uses `nvcr.io/nvidia/l4t-tensorrt:rX.Y.Z-devel` format
- Example: TensorRT 8.6.1 → `l4t-tensorrt:r8.6.1-devel`
- See available tags: [TensorRT on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/l4t-tensorrt)

**Non-Jetson:**
- Default: `nvcr.io/nvidia/tensorrt:25.10-py3`
- Can be overridden with `TENSORRT_TAG` or `TENSORRT_IMAGE`

### Triton Images

**Jetson:**
- L4T 36.x (JetPack 6.x): `tritonserver:25.10-py3-igpu`
- L4T 35.x (JetPack 5.x): `tritonserver:24.08-py3-igpu`
- Older: `tritonserver:23.12-py3-igpu`

**Non-Jetson:**
- Default: `tritonserver:25.10-py3`
- Can be overridden with `TRITON_TAG` or `TRITON_IMAGE`

See available tags: [Triton Inference Server on NGC](https://catalog.ngc.nvidia.com/orgs/nvidia/containers/tritonserver)

## Troubleshooting

### TensorRT version detection fails on Jetson
If the script cannot detect TensorRT version:
```bash
# Manually specify the image
TENSORRT_IMAGE=nvcr.io/nvidia/l4t-tensorrt:r8.6.1-devel ./run_tensorrt_container.sh
```

### Container already exists
The scripts automatically remove existing containers with the same name. If you encounter issues:
```bash
# Manually remove container
docker rm -f tensorrt_dev
docker rm -f triton_server
```

### Network issues
Both containers use the same Docker network (`triton-net` by default) so they can communicate. If you need a different network:
```bash
NETWORK_NAME=my-network ./run_tensorrt_container.sh
NETWORK_NAME=my-network ./run_triton_container.sh
```

### Permission issues
Ensure Docker has proper permissions and NVIDIA runtime is configured:
```bash
# Check NVIDIA runtime
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

## License

This repository contains utility scripts for managing TensorRT and Triton Inference Server containers. The scripts are provided as-is for convenience.

## Contributing

Feel free to submit issues or pull requests for improvements.

