#!/usr/bin/env bash
# Start the load: Kokoro TTS (CPU PyTorch) as a container on 127.0.0.1:8880.
# Public image, no auth, 8 OpenMP threads matched to --cpus 8. This is the
# configuration that reproduces the fault; other thread counts were not tried.
set -eu
RT=${RT:-$(command -v podman || command -v docker)}
IMAGE=${IMAGE:-ghcr.io/remsky/kokoro-fastapi-cpu:latest}
$RT rm -f kokoro-repro >/dev/null 2>&1 || true
$RT run -d --name kokoro-repro -p 127.0.0.1:8880:8880 \
  -e USE_GPU=false -e OMP_NUM_THREADS=8 --cpus 8 --memory 8g "$IMAGE"
echo "waiting for the model to load..."
for i in $(seq 1 120); do
  curl -sf -o /dev/null localhost:8880/v1/models && { echo "kokoro ready on 127.0.0.1:8880"; exit 0; }
  sleep 2
done
echo "kokoro did not come up; $RT logs kokoro-repro" >&2; exit 1
