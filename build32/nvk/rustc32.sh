#!/bin/bash
# rustc32.sh -- the cross file's Rust compiler: Mesa's Rust parts for 32-bit
# Switch programs, as armv7-unknown-linux-gnueabi (the soft-float EABI our C
# code uses; std comes from rustup and links against libnx32's newlib, with
# src/nouveau/vulkan/rust_switch_stubs.c). Meson's sanity check builds and runs
# a program, so it keeps the host target and the host linker. Proc macros
# never come here: they are built for the build machine with the plain rustc
# on PATH.
for arg in "$@"; do
  case "$arg" in
    *sanity_check_for_rust.rs*|*sanitycheckrs.rs*)
      args=()
      skip=0
      for a in "$@"; do
        if [ $skip = 1 ]; then
          skip=0
          case "$a" in linker=*) continue ;; esac
          args+=(-C "$a")
          continue
        fi
        case "$a" in
          -Clinker=*) ;;
          -C) skip=1 ;;
          *) args+=("$a") ;;
        esac
      done
      exec rustc "${args[@]}"
      ;;
  esac
done
exec rustc --target=armv7-unknown-linux-gnueabi "$@"
