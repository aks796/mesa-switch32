#!/bin/sh
# build32.sh -- build Mesa for 32-bit (AArch32) Switch programs in vita2hos's
# toolchain image, into build32/prefix. Arguments go to
# build32/build_mesa32.sh: setup, build, install, all (the default) or
# linktest.
#
# Mesa is built against libnx32: a libnx32 checkout next to this one, built
# (../libnx32/prefix), or the prefix LIBNX32 names. Set TOOLCHAIN_IMAGE to use
# another image.
#
# "build32.sh nvk [step]" builds the Vulkan variant instead (NVK next to GL,
# build32/build_nvk32.sh, into build32/prefix-nvk) in the image
# build32/Docker.nvk32 makes, tagged mesa32-nvk.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT=build_mesa32.sh
IMAGE="${TOOLCHAIN_IMAGE:-ghcr.io/vita2hos/devcontainer/vita2hos:latest}"
if [ "$1" = nvk ]; then
  shift
  SCRIPT=build_nvk32.sh
  IMAGE="${TOOLCHAIN_IMAGE:-mesa32-nvk}"
  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker build --platform linux/amd64 -f "$HERE/build32/Docker.nvk32" -t "$IMAGE" "$HERE/build32"
  fi
fi
LIBNX32="${LIBNX32:-$HERE/../libnx32/prefix}"
NX=/opt/devkitpro/libnx32
if [ ! -f "$LIBNX32/lib/libnx.a" ] || [ ! -f "$LIBNX32/include/switch.h" ]; then
  echo "build32.sh: no libnx32 at $LIBNX32" >&2
  echo "  clone github.com/aks796/libnx32 next to this folder and run its ./build.sh, or set LIBNX32" >&2
  exit 1
fi
LIBNX32="$(cd "$LIBNX32" && pwd)"
echo "build32.sh: using libnx32 from $LIBNX32"
exec docker run --rm --platform linux/amd64 \
  -v "$HERE:/work" \
  -v "$LIBNX32/include/switch:$NX/include/switch:ro" \
  -v "$LIBNX32/include/switch.h:$NX/include/switch.h:ro" \
  -v "$LIBNX32/lib/libnx.a:$NX/lib/libnx.a:ro" \
  -v "$LIBNX32/lib/libnxd.a:$NX/lib/libnxd.a:ro" \
  -v "$LIBNX32/switch32.ld:$NX/switch32.ld:ro" \
  -w /work "$IMAGE" bash -lc "./build32/$SCRIPT $*"
