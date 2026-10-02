#!/bin/sh
# build32.sh -- build Mesa for 32-bit (AArch32) Switch programs in vita2hos's
# toolchain image, into build32/prefix. Arguments go to
# build32/build_mesa32.sh: setup, build, install, all (the default) or
# linktest.
#
# Mesa is built against libnx32: a libnx32 checkout next to this one, built
# (../libnx32/prefix), or the prefix LIBNX32 names. Set TOOLCHAIN_IMAGE to use
# another image.
set -e
IMAGE="${TOOLCHAIN_IMAGE:-ghcr.io/vita2hos/devcontainer/vita2hos:latest}"
HERE="$(cd "$(dirname "$0")" && pwd)"
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
  -w /work "$IMAGE" bash -lc "./build32/build_mesa32.sh $*"
