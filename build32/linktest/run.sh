#!/bin/bash
# Links main.c against build32/prefix three ways (GLES 2/3, GL, GLES 1).
set -uo pipefail
cd "$(dirname "$0")"
NX=$DEVKITPRO/libnx32
P=$PWD/../prefix
CC=$DEVKITPRO/devkitARM/bin/arm-none-eabi-gcc
ARCH="-march=armv8-a+crc+crypto -mtune=cortex-a57 -mfloat-abi=softfp -mfpu=neon-fp-armv8 -mtp=soft -fPIE -ftls-model=local-exec"
export PKG_CONFIG_LIBDIR=$P/lib/pkgconfig
rc=0
for t in gles2:glesv2 gl:gl gles1:glesv1_cm; do
  name=${t%%:*}; pc=${t#*:}
  def=$(echo "TEST_$name" | tr a-z A-Z)
  [ "$name" = gles2 ] && def=TEST_GLES2
  libs=$(pkg-config --static --libs egl $pc)
  if $CC $ARCH -D__SWITCH__ -D$def -fno-short-enums -O2 -isystem $NX/include -I$P/include main.c -o test_$name.elf \
      -specs=$NX/switch32.specs -Wl,-z,notext -Wl,--no-enum-size-warning -L$NX/lib $libs -lnx -lm 2> link_$name.log; then
    echo "$name: linked ($(stat -c %s test_$name.elf) bytes)"
  else
    echo "$name: FAILED"; grep -E "undefined reference|error" link_$name.log | sed 's/.*undefined reference to/undefined:/' | sort | uniq -c | sort -rn | head -40
    rc=1
  fi
done
exit $rc
