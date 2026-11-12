option(PPC_DARWIN_NATIVE "also build the toolchain that runs on Mac OS X" ON)
if(NOT PPC_DARWIN_NATIVE)
  return()
endif()

set(PPC_DARWIN_NATIVE_PREFIX /opt/clang CACHE PATH
    "where the native toolchain is unpacked on the Mac; only used for the tarball layout")
set(PPC_DARWIN_NATIVE_ARCHS "ppc;ppc64" CACHE STRING "host architectures of the native toolchain")

set(native_build "${PROJECT_BINARY_DIR}/native")
set(native_toolchain_file "${toolchain}/share/ppc-darwin/toolchain.cmake")
set(native_host_triple_ppc powerpc-apple-darwin9)
set(native_host_triple_ppc64 powerpc64-apple-darwin9)
set(native_host_triple_i386 i386-apple-darwin9)
set(native_host_triple_x86_64 x86_64-apple-darwin9)
set(native_default_triple_ppc powerpc-apple-darwin9)
set(native_default_triple_ppc64 powerpc-apple-darwin9)
set(native_default_triple_i386 i386-apple-darwin9)
set(native_default_triple_x86_64 x86_64-apple-darwin9)
set(native_link_flags "-static-libstdc++ -framework CoreFoundation")

get_property(cross_targets DIRECTORY PROPERTY BUILDSYSTEM_TARGETS)
list(FILTER cross_targets INCLUDE REGEX "^(merge-.*|driver-config)$")

set(native_roots)
set(native_projects)
foreach(arch IN LISTS PPC_DARWIN_NATIVE_ARCHS)
  if(NOT DEFINED native_host_triple_${arch})
    message(FATAL_ERROR "no host triple for native arch ${arch}")
  endif()
  set(root "${native_build}/${arch}/root")
  set(native_args
    "-DCMAKE_TOOLCHAIN_FILE=${native_toolchain_file}"
    "-DCMAKE_OSX_ARCHITECTURES=${arch}"
    "-DCMAKE_INSTALL_PREFIX=${root}"
  )

  ExternalProject_Add(native-llvm-${arch}
    SOURCE_DIR "${extern}/llvm-project/llvm"
    BINARY_DIR "${native_build}/${arch}/llvm"
    CMAKE_ARGS -C "${extern}/llvm-project/clang/cmake/caches/PowerPCDarwin-native.cmake"
      ${native_args}
      ${llvm_job_args}
      "-DLLVM_HOST_TRIPLE=${native_host_triple_${arch}}"
      "-DLLVM_DEFAULT_TARGET_TRIPLE=${native_default_triple_${arch}}"
      "-DLLVM_NATIVE_TOOL_DIR=${PROJECT_BINARY_DIR}/llvm/bin"
      -DCMAKE_C_FLAGS=-fno-autolink
      -DCMAKE_CXX_FLAGS=-fno-autolink
      "-DCMAKE_EXE_LINKER_FLAGS=${native_link_flags}"
      "-DCMAKE_SHARED_LINKER_FLAGS=${native_link_flags}"
    BUILD_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target distribution
    INSTALL_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target install-distribution
    DEPENDS llvm ${cross_targets}
    BUILD_ALWAYS ON
    USES_TERMINAL_BUILD ON
  )

  ExternalProject_Add(native-cctools-${arch}
    SOURCE_DIR "${extern}/cctools"
    BINARY_DIR "${native_build}/${arch}/cctools"
    CMAKE_ARGS ${native_args} -DCMAKE_BUILD_TYPE=RelWithDebInfo
    DEPENDS ${cross_targets}
    BUILD_ALWAYS ON
  )

  ExternalProject_Add(native-ld64-${arch}
    SOURCE_DIR "${extern}/ld64"
    BINARY_DIR "${native_build}/${arch}/ld64"
    CMAKE_ARGS ${native_args}
      -DCMAKE_BUILD_TYPE=Release
      -DLD64_PROGRAM_NAME=ld64
      "-DCCTOOLS_INCLUDE=${extern}/cctools/include"
      "-DLLVM_SOURCE_INCLUDE=${extern}/llvm-project/llvm/include"
    DEPENDS ${cross_targets}
    BUILD_ALWAYS ON
  )

  list(APPEND native_roots "${root}")
  list(APPEND native_projects native-llvm-${arch} native-cctools-${arch} native-ld64-${arch})
endforeach()

set(native_package_dir "${native_build}/package")
string(REGEX REPLACE "^/+" "" native_prefix_relative "${PPC_DARWIN_NATIVE_PREFIX}")
list(JOIN native_roots "|" native_roots_arg)
set(native_tarball "${PROJECT_BINARY_DIR}/llvm-powerpc-apple-darwin-native.tar.gz")

add_custom_target(native ALL
  COMMAND "${CMAKE_COMMAND}"
    "-DROOTS=${native_roots_arg}"
    "-DOUTPUT=${native_package_dir}/${native_prefix_relative}"
    "-DCROSS=${toolchain}"
    "-DRESOURCE_DIR=${resource_dir}"
    "-DLIPO=${toolchain}/bin/${PPC_DARWIN_TRIPLE}-lipo"
    -P "${PROJECT_SOURCE_DIR}/cmake/NativePackage.cmake"
  COMMAND "${CMAKE_COMMAND}" -E chdir "${native_package_dir}"
    "${CMAKE_COMMAND}" -E tar czf "${native_tarball}" "${native_prefix_relative}"
  BYPRODUCTS "${native_tarball}"
  VERBATIM
)
add_dependencies(native ${native_projects})
