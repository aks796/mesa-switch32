# mesa-switch32

**Mesa 26.2 for 32-bit (AArch32) Nintendo Switch programs**

**If you don't know whether you need this, stick to [mesa32](https://github.com/aks796/mesa32)**
(Mesa 20.1), which the released ports are built with.

OpenGL, OpenGL ES 1/2/3 and EGL for 32-bit Switch programs, on the Tegra X1
GPU through Mesa's Gallium Nouveau driver.

This is a fork of [danfromtico's mesa-switch](https://github.com/danfromtico/mesa-switch)
(Mesa 26.2.3, with its own Horizon GPU backend in place of libdrm_nouveau),
built as AArch32. It builds with [libnx32](https://github.com/aks796/libnx32)
in vita2hos's AArch32 toolchain image.

It runs on hardware in several 32-bit ports of Android games, for GLES 1, 2
and 3, through [android32](https://github.com/aks796/android32).

Vulkan (NVK) and Zink are not built: they need Rust, LLVM, libclc and
SPIRV-Tools cross-built for AArch32 first.

---

## What you get

Static libraries for AArch32 (ARMv8-A, softfp, NEON), with headers and
pkg-config files:

* `libEGL.a`: EGL with the Switch frontend, the Gallium Nouveau (NVC0) driver
  and the Horizon backend
* `libGLESv2.a`: OpenGL ES 2.0 and 3.x (up to 3.2)
* `libGLESv1_CM.a`: OpenGL ES 1.1
* `libGL.a`: desktop OpenGL
* `libglapi.a`, `libmesa_util.a`, `libmesa_util_c11.a`, `libmesa_util_simd.a`,
  `libblake3.a`: what they need
* `libexpat.a`, `libz.a`: from Mesa's wrap files, built for the target
* the rest of Mesa's static libraries (`libnir.a`, `libnouveau_horizon.a`...),
  which `libEGL.a` already contains

Link them into your program. There are no shared libraries on the Switch.

---

## How this differs from mesa-switch

The changes are the commits on top of mesa-switch's `main`:

* **Short enums**: libnx32 is built with `-fshort-enums`, Mesa is not (below).
  `NvMap`'s kind is read as the one byte libnx32 stores.
* **glthread** is off unless asked for, per context (below). mesa-switch had it
  on for every context.
* The build scripts, a link test and this README. mesa-switch's README is kept
  as `README.mesa-switch.rst`.

**Short enums.** devkitARM makes enums as small as their values, and libnx32
is built that way. Mesa is built here with int-sized enums
(`-fno-short-enums`), as its code expects. The two meet only in libnx32's
`NvMap`, whose `kind` field is an enum: one byte in libnx32, four in Mesa.
Mesa reads it as a byte. The fields before it sit at the same offsets either
way. Link with `-Wl,--no-enum-size-warning`.

**glthread.** Mesa's glthread runs a context's GL calls on a worker thread.
It also copies every enabled client-side vertex array at each draw, including
arrays the current state does not read. A program written for a driver on its
own thread can leave a stale pointer enabled, and glthread reads past its end.
So it is opt-in, as in mesa32. To use it, call this before the context is
first made current, from the thread that will use it:

```c
EGLBoolean switch_egl_start_glthread(EGLDisplay dpy, EGLContext ctx);
```

The worker calls `void switch_egl_glthread_hook(void)` once when it starts, if
the program defines it, for example to set the thread's priority and cores.
`MESA_GLTHREAD=true` in the environment turns it on for every context.

---

## Requirements

* Docker
* The AArch32 toolchain image `ghcr.io/vita2hos/devcontainer/vita2hos`, which
  has devkitArm, Meson and Ninja (the build adds PyYAML)
* [libnx32](https://github.com/aks796/libnx32), built

---

## Building

Build libnx32 first. With a libnx32 checkout next to this one:

```text
libnx32/
mesa-switch32/
```

```bash
(cd libnx32 && ./build.sh)
(cd mesa-switch32 && ./build32.sh)
```

`build32.sh` builds in the toolchain image, with libnx32's files mounted over
the image's stock ones. To use a libnx32 installed somewhere else:

```bash
LIBNX32=/path/to/libnx32/prefix ./build32.sh
```

The libraries are installed into `build32/prefix/`:

```text
build32/prefix/
├── include/
│   └── EGL/  GLES/  GLES2/  GLES3/  KHR/  GL/  zlib.h  expat.h ...
└── lib/
    ├── libEGL.a  libGLESv2.a  libGLESv1_CM.a  libGL.a  libglapi.a
    ├── libmesa_util*.a  libblake3.a  libexpat.a  libz.a ...
    └── pkgconfig/
```

A full build takes a while under Docker's x86 emulation. `build32.sh` also
takes a step: `setup`, `build`, `install`, or `linktest`, which links a small
EGL program against the installed libraries as GLES 2/3, GL and GLES 1. Build
files go into `build32/work/`, with the Meson cross file
(`build32/work/cross.txt`).

---

## Using it

Compile with the same flags as libnx32:

```text
-march=armv8-a+crc+crypto -mtune=cortex-a57 -mfloat-abi=softfp
-mfpu=neon-fp-armv8 -mtp=soft -fPIE -ftls-model=local-exec
```

and link with, in this order:

```text
-lEGL -lGLESv2 -lGLESv1_CM -lglapi -lmesa_util_c11 -lblake3 -lmesa_util
-lmesa_util_simd -lexpat -lz -lstdc++ -lnx -lm -Wl,--no-enum-size-warning
```

or ask pkg-config (`PKG_CONFIG_LIBDIR=build32/prefix/lib/pkgconfig`,
`pkg-config --static --libs egl glesv2`). GLES 1 and GLES 2 can be linked
together: the functions both define are the same, and GLES 1's copies are made
weak at install. Create the EGL window surface on libnx's default window
(`nwindowGetDefault()`).

Things to know:

* The Horizon backend keeps CPU-visible memory coherent with the cache
  maintenance syscalls. A program with its own NPDM (an NSP, or an `exefs.nsp`
  override) must allow SVCs `0x5D`, `0x5E` and `0x5F`, or it stops at
  `eglGetDisplay` with "Undefined System Call 0x5E".
* The GPU's memory comes from the process heap. Leave free heap for it.

---

## Upstream

* Mesa: [gitlab.freedesktop.org/mesa/mesa](https://gitlab.freedesktop.org/mesa/mesa)
* mesa-switch: [github.com/danfromtico/mesa-switch](https://github.com/danfromtico/mesa-switch)

Problems that are not specific to AArch32 belong upstream. mesa-switch's own
README is kept as `README.mesa-switch.rst`.

---

## Credits

**AArch32 build and fixes**: aks796

Mesa is by the Mesa developers. The Switch port of Mesa (mesa-switch, its
Horizon backend and Switch EGL) is by danfromtico and its contributors.

The AArch32 toolchain and libnx port are by [xerpi](https://github.com/xerpi),
from [vita2hos](https://github.com/xerpi/vita2hos).

---

## License

MIT, like upstream Mesa. Individual files carry their own license headers.
See [docs/license.rst](docs/license.rst).
