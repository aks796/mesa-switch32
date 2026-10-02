#!/bin/bash
# build_mesa32.sh -- Mesa for 32-bit (AArch32) Switch programs: EGL, desktop
# GL and GLES 1/2/3 on the gallium nouveau driver, with Mesa's Horizon backend
# (no libdrm). Static libraries, installed into build32/prefix.
#
# Run inside the toolchain image (../build32.sh does that). Steps: setup,
# build, install, all (the default: those three), or linktest (links a small
# EGL program against the installed libraries as GLES 2/3, GL and GLES 1).
#
# Built with int-sized enums (-fno-short-enums), as Mesa expects. devkitARM
# and libnx32 use short enums; of the libnx32 structs whose layout depends on
# that, Mesa uses only NvMap: the fields before its enum field, which sit at
# the same offsets either way, and the enum field itself, read as the one byte
# libnx32 stores (nouveau_horizon_memory.c). zlib and expat come from Mesa's
# wrap files, built for the target.
set -euo pipefail
cd "$(dirname "$0")/.."
TOP=$PWD
B=$TOP/build32
WORK=$B/work
PREFIX=$B/prefix
NX=$DEVKITPRO/libnx32
TC=$DEVKITPRO/devkitARM/bin/arm-none-eabi
ARCH=(-march=armv8-a+crc+crypto -mtune=cortex-a57 -mfloat-abi=softfp -mfpu=neon-fp-armv8
      -mtp=soft -fPIE -ftls-model=local-exec)
step=${1:-all}

# PyYAML: Mesa's code generators need it, and the image has none.
if ! python3 -c 'import yaml' 2>/dev/null; then
  [ -d "$B/pydeps/yaml" ] || pip3 install --quiet --target "$B/pydeps" pyyaml
  export PYTHONPATH="$B/pydeps${PYTHONPATH:+:$PYTHONPATH}"
fi

flags() { local o=""; for a in "$@"; do o+="'$a',"; done; echo "${o%,}"; }

setup() {
  mkdir -p "$WORK" "$B/pkgconfig-empty"
  local C=("${ARCH[@]}" -D__SWITCH__ -DHAVE_TIMESPEC_GET -fno-short-enums
           -ffunction-sections -fdata-sections -isystem "$NX/include")
  local L=("${ARCH[@]}" -fno-short-enums -specs="$NX/switch32.specs" -Wl,-z,notext
           -Wl,--no-enum-size-warning -L"$NX/lib" -lnx)
  # pkg_config_libdir points at an empty folder so nothing from the image's
  # own (x86) system is picked up: zlib and expat fall back to their wraps.
  cat > "$WORK/cross.txt" <<EOF
[binaries]
c = '${TC}-gcc'
cpp = '${TC}-g++'
ar = '${TC}-gcc-ar'
strip = '${TC}-strip'
pkg-config = '$(command -v pkg-config)'

[properties]
pkg_config_libdir = '$B/pkgconfig-empty'

[built-in options]
c_args = [$(flags "${C[@]}")]
cpp_args = [$(flags "${C[@]}")]
c_link_args = [$(flags "${L[@]}")]
cpp_link_args = [$(flags "${L[@]}")]

[host_machine]
system = 'horizon'
cpu_family = 'arm'
cpu = 'cortex-a57'
endian = 'little'
EOF
  rm -rf "$WORK/mesa"
  meson setup "$WORK/mesa" "$TOP" \
    --cross-file "$WORK/cross.txt" \
    --default-library=static --prefix="$PREFIX" --libdir=lib \
    --buildtype=release -Doptimization=2 -Db_ndebug=true -Db_lto=false \
    -Dvulkan-drivers= -Dgallium-drivers=nouveau -Dgallium-rusticl=false \
    -Dplatforms=switch -Degl-native-platform=switch \
    -Dglx=disabled -Degl=enabled -Dopengl=true -Dgles1=enabled -Dgles2=enabled \
    -Dgbm=disabled -Dglvnd=disabled -Dteflon=false \
    -Dvideo-codecs= -Dshader-cache=enabled -Dxmlconfig=auto -Dexpat=auto \
    -Dzlib=enabled -Dzstd=disabled -Dtools=[] -Dllvm=disabled \
    -Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled \
    -Dselinux=false -Dperfetto=false -Dsysprof=false -Ddisplay-info=disabled \
    -Dcpp_rtti=false -Dbuild-tests=false
}

build() { ninja -C "$WORK/mesa" -j"$(nproc)"; }

install() {
  rm -rf "$PREFIX"
  meson install -C "$WORK/mesa" --quiet
  for pc in "$PREFIX"/lib/pkgconfig/*.pc; do
    sed -i 's|^prefix=.*|prefix=${pcfiledir}/../..|' "$pc"
  done
  # libGLESv1_CM and libGLESv2 are one object each, and 59 functions (glClear,
  # glBindTexture...) are in both, so a program using GLES 1 and GLES 2 could
  # not link both. GLES 1's are made weak: where GLES 2 has the same function
  # it is used, and GLES 1's own (glMatrixMode, glOrthof...) still link. Both
  # copies call the same slot of the same dispatch table.
  "${TC}-objcopy" --weaken "$PREFIX/lib/libGLESv1_CM.a"
  ls -l "$PREFIX/lib"
}

case "$step" in
  setup) setup ;;
  build) build ;;
  install) install ;;
  all) setup; build; install ;;
  linktest) "$B/linktest/run.sh" ;;
  *) echo "unknown step $step (setup, build, install, all, linktest)" >&2; exit 1 ;;
esac
