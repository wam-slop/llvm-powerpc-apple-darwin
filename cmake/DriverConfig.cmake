set(targets
  "${TRIPLE}:MacOSX10.5.sdk:10.5"
  "powerpc-apple-darwin8:MacOSX10.4u.sdk:10.4"
  "powerpc64-apple-darwin9:MacOSX10.5.sdk:10.5"
  "i386-apple-darwin8:MacOSX10.4u.sdk:10.4"
  "i386-apple-darwin9:MacOSX10.5.sdk:10.5"
  "x86_64-apple-darwin9:MacOSX10.5.sdk:10.5"
)
set(driver_names clang clang++ cc c++ gcc g++ cpp)
set(tool_names ld ar ranlib libtool nm nmedit strip otool lipo install_name_tool size strings pkg-config)

function(relink target link)
  file(REMOVE "${link}")
  file(CREATE_LINK "${target}" "${link}" SYMBOLIC)
endfunction()

set(bin "${TOOLCHAIN}/bin")

file(MAKE_DIRECTORY "${TOOLCHAIN}/SDKs")
file(GLOB sdk_paths "${SDK_DIR}/*.sdk")
foreach(sdk_path IN LISTS sdk_paths)
  get_filename_component(sdk_name "${sdk_path}" NAME)
  relink("${sdk_path}" "${TOOLCHAIN}/SDKs/${sdk_name}")
endforeach()

file(INSTALL "${FILES}/toolchain.cmake" DESTINATION "${TOOLCHAIN}/share/ppc-darwin")
file(INSTALL "${FILES}/run-on-target" "${FILES}/register-sdk.sh" DESTINATION "${TOOLCHAIN}/libexec/ppc-darwin"
  FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(INSTALL "${FILES}/pkg-config" DESTINATION "${bin}"
  FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
file(RENAME "${bin}/pkg-config" "${bin}/${TRIPLE}-pkg-config")

foreach(entry IN LISTS targets)
  string(REPLACE ":" ";" fields "${entry}")
  list(GET fields 0 target)
  list(GET fields 1 sdk)
  list(GET fields 2 min)

  foreach(name IN LISTS driver_names)
    relink(clang "${bin}/${target}-${name}")
  endforeach()

  file(WRITE "${bin}/${target}.cfg"
"-isysroot <CFGDIR>/../SDKs/${sdk}
-mmacosx-version-min=${min}
-idirafter <CFGDIR>/../include
--ld-path=<CFGDIR>/${TRIPLE}-ld
-mlinker-version=127.2
")

  if(NOT target STREQUAL TRIPLE)
    foreach(tool IN LISTS tool_names)
      relink("${TRIPLE}-${tool}" "${bin}/${target}-${tool}")
    endforeach()
  endif()
endforeach()

file(MAKE_DIRECTORY "${TOOLCHAIN}/${TRIPLE}/lib" "${TOOLCHAIN}/${TRIPLE}/include")
