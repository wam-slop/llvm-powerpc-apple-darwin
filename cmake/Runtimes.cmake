include("${extern}/llvm-project/cmake/Modules/LLVMVersion.cmake")

set(resource_dir "lib/clang/${LLVM_VERSION_MAJOR}")
set(runtime_toolchain "${toolchain}/share/ppc-darwin/toolchain.cmake")
set(runtime_lipo "${toolchain}/bin/${PPC_DARWIN_TRIPLE}-lipo")
set(runtime_nm "${toolchain}/bin/${PPC_DARWIN_TRIPLE}-nm")
set(runtimes_build "${PROJECT_BINARY_DIR}/runtimes")

set(slice_ppc-10.4 ppc MacOSX10.4u.sdk 10.4)
set(slice_ppc-10.5 ppc MacOSX10.5.sdk 10.5)
set(slice_ppc64-10.5 ppc64 MacOSX10.5.sdk 10.5)
set(slice_intel-10.5 "i386|x86_64" MacOSX10.5.sdk 10.5)
set(slice_i386-10.4 i386 MacOSX10.4u.sdk 10.4)
set(slice_x86_64-10.5 x86_64 MacOSX10.5.sdk 10.5)

set(runtime_slices ppc-10.4 ppc64-10.5 i386-10.4 x86_64-10.5)

function(add_runtime_slice component slice source)
  cmake_parse_arguments(arg "" "" "BUILD_TARGETS;INSTALL_TARGETS;DEPENDS;CMAKE_ARGS" ${ARGN})
  list(GET slice_${slice} 0 archs)
  list(GET slice_${slice} 1 sdk)
  list(GET slice_${slice} 2 min)

  set(build_command)
  if(arg_BUILD_TARGETS)
    set(build_command BUILD_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target ${arg_BUILD_TARGETS})
  endif()
  set(install_command)
  if(arg_INSTALL_TARGETS)
    set(install_command INSTALL_COMMAND "${CMAKE_COMMAND}" --build <BINARY_DIR> --target ${arg_INSTALL_TARGETS})
  endif()

  ExternalProject_Add(${component}-${slice}
    SOURCE_DIR "${source}"
    BINARY_DIR "${runtimes_build}/${component}-${slice}"
    INSTALL_DIR "${runtimes_build}/${component}-${slice}.stage"
    LIST_SEPARATOR |
    CMAKE_ARGS
      "-DCMAKE_TOOLCHAIN_FILE=${runtime_toolchain}"
      -DCMAKE_BUILD_TYPE=Release
      "-DCMAKE_OSX_ARCHITECTURES=${archs}"
      "-DCMAKE_OSX_SYSROOT=${toolchain}/SDKs/${sdk}"
      "-DCMAKE_OSX_DEPLOYMENT_TARGET=${min}"
      "-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>"
      ${arg_CMAKE_ARGS}
    ${build_command}
    ${install_command}
    DEPENDS ${arg_DEPENDS}
    BUILD_ALWAYS ON
  )
endfunction()

function(add_runtime_merge name mode subdir dest)
  set(stages)
  foreach(project IN LISTS ARGN)
    list(APPEND stages "${runtimes_build}/${project}.stage")
  endforeach()
  list(JOIN stages "|" stages_arg)
  add_custom_target(${name} ALL
    COMMAND "${CMAKE_COMMAND}"
      "-DMODE=${mode}"
      "-DSTAGES=${stages_arg}"
      "-DSUBDIR=${subdir}"
      "-DDEST=${toolchain}/${dest}"
      "-DLIPO=${runtime_lipo}"
      -P "${PROJECT_SOURCE_DIR}/cmake/MergeSlices.cmake"
    VERBATIM
  )
  add_dependencies(${name} ${ARGN})
endfunction()

set(builtins_projects)
foreach(slice IN LISTS runtime_slices)
  list(GET slice_${slice} 0 archs)
  list(GET slice_${slice} 1 sdk)
  list(GET slice_${slice} 2 min)
  add_runtime_slice(builtins ${slice} "${extern}/llvm-project/compiler-rt"
    BUILD_TARGETS builtins
    INSTALL_TARGETS install-builtins
    DEPENDS driver-config
    CMAKE_ARGS
      "-DLLVM_DIR=${PROJECT_BINARY_DIR}/llvm/lib/cmake/llvm"
      "-DLLVM_CMAKE_DIR=${PROJECT_BINARY_DIR}/llvm/lib/cmake/llvm"
      -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH
      -DCOMPILER_RT_BUILD_BUILTINS=ON
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF
      -DCOMPILER_RT_BUILD_XRAY=OFF
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF
      -DCOMPILER_RT_BUILD_PROFILE=OFF
      -DCOMPILER_RT_BUILD_MEMPROF=OFF
      -DCOMPILER_RT_BUILD_ORC=OFF
      -DCOMPILER_RT_BUILD_CTX_PROFILE=OFF
      -DCOMPILER_RT_ENABLE_IOS=OFF
      -DCOMPILER_RT_ENABLE_WATCHOS=OFF
      -DCOMPILER_RT_ENABLE_TVOS=OFF
      -DCOMPILER_RT_ENABLE_XROS=OFF
      -DCOMPILER_RT_ENABLE_MACCATALYST=OFF
      "-DDARWIN_macosx_CACHED_SYSROOT=${toolchain}/SDKs/${sdk}"
      "-DDARWIN_macosx_OVERRIDE_SDK_VERSION=${min}"
      "-DDARWIN_osx_BUILTIN_MIN_VER=${min}"
      "-DDARWIN_osx_ARCHS=${archs}"
      "-DDARWIN_osx_BUILTIN_ARCHS=${archs}"
      -DSANITIZER_MIN_OSX_VERSION=10.7
  )
  list(APPEND builtins_projects builtins-${slice})
endforeach()
add_runtime_merge(merge-builtins LIBS lib/darwin "${resource_dir}/lib/darwin" ${builtins_projects})

set(legacy_slices_10.4 ppc-10.4 i386-10.4)
set(legacy_slices_10.5 ppc-10.5 ppc64-10.5 intel-10.5)
set(legacy_merges)
set(legacy_projects)
foreach(version 10.4 10.5)
  set(version_projects)
  foreach(slice IN LISTS legacy_slices_${version})
    if(NOT TARGET legacy-support-${slice})
      add_runtime_slice(legacy-support ${slice} "${extern}/legacy-support"
        DEPENDS merge-builtins
        CMAKE_ARGS -DCMAKE_C_FLAGS=-fno-bundled-legacy-support)
      list(APPEND legacy_projects legacy-support-${slice})
    endif()
    list(APPEND version_projects legacy-support-${slice})
  endforeach()
  add_runtime_merge(merge-legacy-support-${version} LIBS lib "lib/legacy-support/${version}"
    ${version_projects})
  list(APPEND legacy_merges merge-legacy-support-${version})
endforeach()
add_runtime_merge(merge-legacy-support-headers TREE include/LegacySupport include/LegacySupport
  ${legacy_projects})
list(APPEND legacy_merges merge-legacy-support-headers)

set(blocks_projects)
set(arclite_projects)
foreach(slice IN LISTS runtime_slices)
  add_runtime_slice(blocks ${slice} "${extern}/llvm-project/compiler-rt/lib/BlocksRuntime"
    DEPENDS ${legacy_merges})
  add_runtime_slice(arclite ${slice} "${extern}/llvm-project/compiler-rt/lib/arclite"
    DEPENDS ${legacy_merges})
  list(APPEND blocks_projects blocks-${slice})
  list(APPEND arclite_projects arclite-${slice})
endforeach()
add_runtime_merge(merge-blocks LIBS lib lib ${blocks_projects})
add_runtime_merge(merge-blocks-headers TREE include include ${blocks_projects})
add_runtime_merge(merge-arclite LIBS lib/arc lib/arc ${arclite_projects})
add_runtime_merge(merge-arclite-headers TREE include include ${arclite_projects})

set(libcxx_legacy_ppc-10.4 10.4)
set(libcxx_legacy_ppc64-10.5 10.5)
set(libcxx_legacy_i386-10.4 10.4)
set(libcxx_legacy_x86_64-10.5 10.5)
set(libcxx_projects)
foreach(slice IN LISTS runtime_slices)
  set(legacy_archive "${toolchain}/lib/legacy-support/${libcxx_legacy_${slice}}/libMacportsLegacySupport.a")
  set(legacy_exports "${runtimes_build}/libcxx-${slice}.legacy-exports")
  add_runtime_slice(libcxx ${slice} "${extern}/llvm-project/runtimes"
    BUILD_TARGETS cxx cxxabi
    INSTALL_TARGETS install-cxx install-cxxabi
    DEPENDS ${legacy_merges} merge-builtins
    CMAKE_ARGS
      "-DLLVM_ENABLE_RUNTIMES=libcxx|libcxxabi"
      -DCMAKE_INSTALL_NAME_DIR=@executable_path
      "-DCMAKE_CXX_FLAGS=-faligned-allocation -fsized-deallocation"
      "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-unexported_symbol,___emutls_get_address ${legacy_archive} -Wl,-unexported_symbols_list,${legacy_exports}"
      -DLIBCXX_CXX_ABI=libcxxabi
      -DLIBCXX_ABI_NAMESPACE=__pd1
      -DLIBCXX_ENABLE_SHARED=ON
      -DLIBCXX_ENABLE_STATIC=ON
      -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON
      -DLIBCXX_STATICALLY_LINK_ABI_IN_SHARED_LIBRARY=ON
      -DLIBCXXABI_ENABLE_SHARED=OFF
      -DLIBCXXABI_ENABLE_STATIC=ON
      -DLIBCXXABI_USE_LLVM_UNWINDER=OFF
      -DLIBCXX_ENABLE_TIME_ZONE_DATABASE=OFF
      -DLIBCXX_ENABLE_VENDOR_AVAILABILITY_ANNOTATIONS=OFF
      -DLIBCXX_PSTL_BACKEND=serial
      "-DLIBCXX_AVAILABILITY_MINIMUM_HEADER_VERSION=${LLVM_VERSION_MAJOR}"
      "-DLIBCXXABI_AVAILABILITY_MINIMUM_HEADER_VERSION=${LLVM_VERSION_MAJOR}"
      -DLIBCXX_EXTRA_SITE_DEFINES=_LIBCPP_INIT_STREAMS_IN_EVERY_TU=1
      -DLIBCXX_INCLUDE_TESTS=OFF
      -DLIBCXXABI_INCLUDE_TESTS=OFF
      -DLIBCXX_INCLUDE_BENCHMARKS=OFF
      -DLIBCXX_INCLUDE_DOCS=OFF
  )
  ExternalProject_Add_Step(libcxx-${slice} legacy-exports
    COMMAND "${CMAKE_COMMAND}"
      "-DNM=${runtime_nm}"
      "-DARCHIVE=${legacy_archive}"
      "-DOUTPUT=${legacy_exports}"
      -P "${PROJECT_SOURCE_DIR}/cmake/LegacyExports.cmake"
    DEPENDERS configure
    ALWAYS ON
  )
  list(APPEND libcxx_projects libcxx-${slice})
endforeach()
add_runtime_merge(merge-libcxx LIBS lib lib ${libcxx_projects})
add_runtime_merge(merge-libcxx-headers TREE include/c++/v1 include/c++/v1 ${libcxx_projects})
