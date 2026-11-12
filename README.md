# llvm powerpc-apple-darwin

This repo contains a fork of LLVM that restores support for the `powerpc-apple-darwin` target, allowing you to target OS X Leopard/Tiger on PowerPC and Intel Macs using a modern cross-compilation toolchain, modern C/C++ and Objective-C included.

**THIS PORT WAS DONE WITH AI ASSISTANCE**
If this bothers you, understandable! Please look elsewhere.

## What works

- Mach-O objects written for `ppc` and `ppc64` targets
- `ppc` and `ppc64` code-generation against the Darwin ABI (via AIX's lowering)
- `clang` targets for `powerpc-apple-darwin8`, `powerpc-apple-darwin9`, and `powerpc64-apple-darwin9`
- `clang` targets for `i386-apple-darwin8`, `i386-apple-darwin9`, and `x86_64-apple-darwin9`
- Universal (fat) binaries for `ppc`, `ppc64`, `i386`, and `x86_64` targets
- `libc++` and `libc++abi` support for all targets (with C++23 support!)
- Additional libc fixes for Tiger and Leopard via MacPorts `legacy-support`
- Modern Objective-C syntax and some runtime support on Tiger and Leopard
  - Automatic Reference Counting (ARC) syntax and runtime support
  - Blocks syntax and runtime support
  - `__weak` support on Leopard and later
- Exception handling correctness between `clang` and `gcc`
- Altivec intrinsics
- Link Time Optimization (LTO) (full LTO only, no thin LTO)
- Full cross-compilation support from Linux hosts, modern macOS hosts should also work but haven't been tested
- Full self-hosted builds for Leopard on `ppc` and `ppc64` hosts
- x86_64 binaries work from Leopard -> macOS Golden Gate under Rosetta

## What doesn't

- Blocks as Objective-C objects on Tiger
- `__weak` on Tiger
- `std::atomic::wait` is a busy-wait
- 73 `libc++` tests currently fail on Leopard, mostly due to the oldschool `libc`

## Setup

- Clone recursively
- Install the regular set of LLVM dependencies (CMake, Ninja, Python, etc.)
- Copy `MacOSX10.4u.sdk` and `MacOSX10.5.sdk` from /Developer/SDKs into sdks/
- `cmake -G Ninja -S . -B build`
- `cmake --build build`

This will build two things:

1. `build/toolchain/` contains a full cross-compilation toolchain for `powerpc-apple-darwin` and `powerpc64-apple-darwin`
2. `build/llvm-powerpc-apple-darwin-native.tar.gz` contains a self-hosted build of LLVM/`clang` for `powerpc-apple-darwin` and `powerpc64-apple-darwin` built using the cross-compilation toolchain, targeting Leopard. Extract at `/`.

You can skip the self-hosted build by passing `-DPPC_DARWIN_NATIVE=OFF`, or use `-DPPC_DARWIN_NATIVE_ARCHS="ppc;ppc64;i386;x86_64"` to specify the host architectures to build for. The default is `ppc;ppc64`, and they're built as fat binaries.

Usual LLVM compilation caveats apply, this is a very large build run multiple times. It's gonna take a while.
