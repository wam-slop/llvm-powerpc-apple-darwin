FROM debian:trixie AS build

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates cmake g++ gcc libssl-dev make ninja-build python3 uuid-dev \
 && rm -rf /var/lib/apt/lists/*

COPY . /src

ARG JOBS=16
ARG NATIVE_ARCHS="ppc;ppc64"
ENV CMAKE_BUILD_PARALLEL_LEVEL=${JOBS}

RUN --mount=type=cache,target=/build \
    cmake -G Ninja -S /src -B /build -DPPC_DARWIN_LLVM_COMPILE_JOBS=${JOBS} \
      "-DPPC_DARWIN_NATIVE_ARCHS=${NATIVE_ARCHS}" \
 && cmake --build /build \
 && rm -rf /opt/ppc-darwin \
 && cmake --install /build --prefix /opt/ppc-darwin \
 && mkdir -p /artifacts \
 && tar -C /opt -czf /artifacts/llvm-powerpc-apple-darwin-cross.tar.gz ppc-darwin \
 && cp /build/llvm-powerpc-apple-darwin-native.tar.gz /artifacts/

FROM scratch AS artifacts
COPY --from=build /artifacts/ /

FROM debian:trixie AS toolchain

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      cmake libssl3t64 libuuid1 make ninja-build pkg-config \
 && rm -rf /var/lib/apt/lists/*

COPY --from=build /opt/ppc-darwin /opt/ppc-darwin
ENV PATH=/opt/ppc-darwin/bin:$PATH

RUN --mount=type=bind,from=build,source=/src/sdks,target=/opt/ppc-darwin/SDKs \
    printf 'int main(void) { return 0; }\n' > /tmp/probe.c \
 && for target in powerpc-apple-darwin8 powerpc-apple-darwin9 powerpc64-apple-darwin9 \
                  i386-apple-darwin8 i386-apple-darwin9 x86_64-apple-darwin9; do \
      $target-clang /tmp/probe.c -o /tmp/probe-$target || exit 1; \
      $target-clang++ -x c++ /tmp/probe.c -o /tmp/probe-$target-cxx || exit 1; \
    done \
 && rm -f /tmp/probe*
