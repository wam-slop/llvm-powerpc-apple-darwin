cmake_minimum_required(VERSION 3.31)
project(llvm-powerpc-apple-darwin LANGUAGES NONE)

include(ExternalProject)

set(PPC_DARWIN_TRIPLE powerpc-apple-darwin9)
set(PPC_DARWIN_SDK_DIR "${PROJECT_SOURCE_DIR}/sdks" CACHE PATH
    "directory holding MacOSX10.4u.sdk and MacOSX10.5.sdk")
set(PPC_DARWIN_TOOLCHAIN_DIR "${PROJECT_BINARY_DIR}/toolchain" CACHE PATH
    "where the cross toolchain is put together, and runnable from, before install")
set(PPC_DARWIN_LLVM_COMPILE_JOBS "" CACHE STRING
    "most compile jobs at once in each LLVM build, empty for no limit")
set(PPC_DARWIN_LLVM_LINK_JOBS 2 CACHE STRING "most link jobs at once in each LLVM build")
option(PPC_DARWIN_INSTALL_SDKS
  "copy the SDKs into the install prefix; they're Apple's, so leave this off for anything you give to someone else"
  OFF)

set(extern "${PROJECT_SOURCE_DIR}/extern")
set(toolchain "${PPC_DARWIN_TOOLCHAIN_DIR}")
set(sdks MacOSX10.4u.sdk MacOSX10.5.sdk)

foreach(sdk IN LISTS sdks)
  if(NOT EXISTS "${PPC_DARWIN_SDK_DIR}/${sdk}/usr/lib/libSystem.B.dylib")
    message(FATAL_ERROR "${PPC_DARWIN_SDK_DIR}/${sdk} is missing or isn't a Mac OS X SDK")
  endif()
endforeach()

set(host_args "-DCMAKE_INSTALL_PREFIX=${toolchain}")
foreach(var CMAKE_C_COMPILER CMAKE_CXX_COMPILER CMAKE_C_COMPILER_LAUNCHER CMAKE_CXX_COMPILER_LAUNCHER)
  if(DEFINED ${var})
    list(APPEND host_args "-D${var}=${${var}}")
  endif()
endforeach()

set(llvm_job_args "-DLLVM_PARALLEL_LINK_JOBS=${PPC_DARWIN_LLVM_LINK_JOBS}")
if(PPC_DARWIN_LLVM_COMPILE_JOBS)
  list(APPEND llvm_job_args "-DLLVM_PARALLEL_COMPILE_JOBS=${PPC_DARWIN_LLVM_COMPILE_JOBS}")
endif()

ExternalProject_Add(llvm
  SOURCE_DIR "${extern}/llvm-project/llvm"
  BINARY_DIR "${PROJECT_BINARY_DIR}/llvm"
  CMAKE_ARGS -C "${extern}/llvm-project/clang/cmake/caches/PowerPCDarwin.cmake" ${host_args}
    ${llvm_job_args}
  BUILD_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target distribution
  INSTALL_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target install-distribution
  BUILD_ALWAYS ON
  USES_TERMINAL_BUILD ON
)

ExternalProject_Add(cctools
  SOURCE_DIR "${extern}/cctools"
  BINARY_DIR "${PROJECT_BINARY_DIR}/cctools"
  CMAKE_ARGS ${host_args}
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    "-DCCTOOLS_PROGRAM_PREFIX=${PPC_DARWIN_TRIPLE}-"
  BUILD_ALWAYS ON
)

ExternalProject_Add(ld64
  SOURCE_DIR "${extern}/ld64"
  BINARY_DIR "${PROJECT_BINARY_DIR}/ld64"
  CMAKE_ARGS ${host_args}
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    "-DLD64_PROGRAM_NAME=${PPC_DARWIN_TRIPLE}-ld"
    "-DCCTOOLS_INCLUDE=${extern}/cctools/include"
    "-DLLVM_SOURCE_INCLUDE=${extern}/llvm-project/llvm/include"
  BUILD_ALWAYS ON
)

add_custom_target(driver-config ALL
  COMMAND "${CMAKE_COMMAND}"
    "-DTOOLCHAIN=${toolchain}"
    "-DTRIPLE=${PPC_DARWIN_TRIPLE}"
    "-DSDK_DIR=${PPC_DARWIN_SDK_DIR}"
    "-DFILES=${PROJECT_SOURCE_DIR}/toolchain"
    -P "${PROJECT_SOURCE_DIR}/cmake/DriverConfig.cmake"
  VERBATIM
)
add_dependencies(driver-config llvm cctools ld64)

include(cmake/Runtimes.cmake)
include(cmake/Native.cmake)

install(DIRECTORY "${toolchain}/" DESTINATION . USE_SOURCE_PERMISSIONS
  PATTERN SDKs EXCLUDE)
if(PPC_DARWIN_INSTALL_SDKS)
  foreach(sdk IN LISTS sdks)
    install(DIRECTORY "${PPC_DARWIN_SDK_DIR}/${sdk}" DESTINATION SDKs USE_SOURCE_PERMISSIONS)
  endforeach()
endif()
