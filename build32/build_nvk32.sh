#!/bin/bash
# build_nvk32.sh -- Mesa for 32-bit (AArch32) Switch programs with Vulkan:
# NVK (with the NAK compiler, in Rust) next to EGL, desktop GL and GLES 1/2/3
# on the gallium nouveau driver, as build_mesa32.sh builds them. Static
# libraries, installed into build32/prefix-nvk.
#
# Run inside the NVK image (../build32.sh nvk does that; the image is
# build32/Docker.nvk32). Steps: host, setup, build, install, all (the default:
# those four).
#
# NVK needs two programs that run on the build machine while it builds,
# mesa_clc and vtn_bindgen2 (its OpenCL C kernels are compiled to NIR then):
# the host step builds them natively with the image's LLVM, into
# work/nvk-host. The cross build then uses them through a native file.
#
# The Rust parts are built for armv7-unknown-linux-gnueabi (nvk/rustc32.sh)
# and bindgen parses Mesa's headers as our C compiler sees them
# (nvk/bindgen32.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
TOP=$PWD
B=$TOP/build32
WORK=$B/work
HOST=$WORK/nvk-host
CROSS=$WORK/mesa-nvk
PREFIX=$B/prefix-nvk
NX=$DEVKITPRO/libnx32
TC=$DEVKITPRO/devkitARM/bin/arm-none-eabi
ARCH=(-march=armv8-a+crc+crypto -mtune=cortex-a57 -mfloat-abi=softfp -mfpu=neon-fp-armv8
      -mtp=soft -fPIE -ftls-model=local-exec)
step=${1:-all}

flags() { local o=""; for a in "$@"; do o+="'$a',"; done; echo "${o%,}"; }

host() {
  rm -rf "$HOST"
  meson setup "$HOST" "$TOP" \
    --buildtype=release -Db_ndebug=true \
    -Dvulkan-drivers= -Dgallium-drivers= -Dplatforms= \
    -Dglx=disabled -Degl=disabled -Dopengl=false -Dgles1=disabled -Dgles2=disabled \
    -Dshader-cache=disabled -Dtools=[] -Dllvm=enabled \
    -Dmesa-clc=enabled -Dprecomp-compiler=enabled -Dinstall-mesa-clc=true \
    -Dbuild-tests=false
  ninja -C "$HOST" src/compiler/clc/mesa_clc src/compiler/spirv/vtn_bindgen2
}

setup() {
  mkdir -p "$WORK" "$B/pkgconfig-empty"
  local C=("${ARCH[@]}" -D__SWITCH__ -DHAVE_TIMESPEC_GET -fno-short-enums
           -ffunction-sections -fdata-sections -isystem "$NX/include")
  local L=("${ARCH[@]}" -fno-short-enums -specs="$NX/switch32.specs" -Wl,-z,notext
           -Wl,--no-enum-size-warning -L"$NX/lib" -lnx)
  # As in build_mesa32.sh, plus Rust and bindgen. pkg_config_libdir points at
  # an empty folder so nothing from the image's own (x86) system is picked
  # up: zlib and expat fall back to their wraps.
  cat > "$WORK/cross-nvk.txt" <<EOF
[binaries]
c = '${TC}-gcc'
cpp = '${TC}-g++'
ar = '${TC}-gcc-ar'
strip = '${TC}-strip'
pkg-config = '$(command -v pkg-config)'
rust = '$B/nvk/rustc32.sh'
bindgen = '$B/nvk/bindgen32.sh'

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
  cat > "$WORK/native-nvk.txt" <<EOF
[binaries]
mesa_clc = '$HOST/src/compiler/clc/mesa_clc'
vtn_bindgen2 = '$HOST/src/compiler/spirv/vtn_bindgen2'
EOF
  rm -rf "$CROSS"
  meson setup "$CROSS" "$TOP" \
    --cross-file "$WORK/cross-nvk.txt" --native-file "$WORK/native-nvk.txt" \
    --default-library=static --prefix="$PREFIX" --libdir=lib \
    --buildtype=release -Doptimization=2 -Db_ndebug=true -Db_lto=false \
    -Dvulkan-drivers=nouveau -Dgallium-drivers=nouveau -Dgallium-rusticl=false \
    -Dmesa-clc=system -Dprecomp-compiler=system \
    -Dplatforms=switch -Degl-native-platform=switch \
    -Dglx=disabled -Degl=enabled -Dopengl=true -Dgles1=enabled -Dgles2=enabled \
    -Dgbm=disabled -Dglvnd=disabled -Dteflon=false \
    -Dvideo-codecs= -Dshader-cache=enabled -Dxmlconfig=auto -Dexpat=auto \
    -Dzlib=enabled -Dzstd=disabled -Dtools=[] -Dllvm=disabled \
    -Dvalgrind=disabled -Dlibunwind=disabled -Dlmsensors=disabled \
    -Dselinux=false -Dperfetto=false -Dsysprof=false -Ddisplay-info=disabled \
    -Dcpp_rtti=false -Dbuild-tests=false
}

build() { ninja -C "$CROSS" -j"$(nproc)"; }

install() {
  rm -rf "$PREFIX"
  meson install -C "$CROSS" --quiet
  for pc in "$PREFIX"/lib/pkgconfig/*.pc; do
    sed -i 's|^prefix=.*|prefix=${pcfiledir}/../..|' "$pc"
  done
  # See build_mesa32.sh: GLES 1's copies of the functions GLES 2 also has.
  "${TC}-objcopy" --weaken "$PREFIX/lib/libGLESv1_CM.a"
  ls -l "$PREFIX/lib"
}

case "$step" in
  host) host ;;
  setup) setup ;;
  build) build ;;
  install) install ;;
  all) host; setup; build; install ;;
  *) echo "unknown step $step (host, setup, build, install, all)" >&2; exit 1 ;;
esac
