#!/bin/sh
# bindgen32.sh -- bindgen with Clang parsing Mesa's headers as our 32-bit C
# compiler does: bare-metal ARM EABI with int-sized enums (Mesa is built with
# -fno-short-enums; Clang's arm-none-eabi would default to short ones), the
# devkitARM and libnx32 headers, and a shim for C11 atomic types.
HERE=${0%/*}
case "$*" in
  *--version*) exec bindgen "$@" ;;
esac
RES="$(clang -print-resource-dir)/include"
EXTRA="--target=arm-none-eabi -march=armv8-a -mfloat-abi=softfp -fno-short-enums -D__SWITCH__ -DHAVE_TIMESPEC_GET -include $HERE/../../bindgen-atomic-shim.h -isystem $RES -isystem $DEVKITPRO/devkitARM/arm-none-eabi/include -isystem $DEVKITPRO/libnx32/include"
export BINDGEN_EXTRA_CLANG_ARGS="$EXTRA"
exec bindgen "$@"
