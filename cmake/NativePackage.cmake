cmake_minimum_required(VERSION 3.31)

string(REPLACE "|" ";" roots "${ROOTS}")
list(GET roots 0 first)

set(thin_macho_magics feedface feedfacf cefaedfe cffaedfe)

function(list_tree dir out)
  file(GLOB_RECURSE entries LIST_DIRECTORIES false RELATIVE "${dir}" "${dir}/*")
  list(SORT entries)
  set(${out} "${entries}" PARENT_SCOPE)
endfunction()

function(copy_entry source dest_dir)
  file(MAKE_DIRECTORY "${dest_dir}")
  file(COPY "${source}" DESTINATION "${dest_dir}")
endfunction()

file(REMOVE_RECURSE "${OUTPUT}")
file(MAKE_DIRECTORY "${OUTPUT}")

list_tree("${first}" files)
foreach(root IN LISTS roots)
  list_tree("${root}" root_files)
  if(NOT root_files STREQUAL files)
    message(FATAL_ERROR "${first} and ${root} have different files")
  endif()
endforeach()

set(lipo_count 0)
foreach(file IN LISTS files)
  get_filename_component(subdir "${file}" DIRECTORY)
  set(dest_dir "${OUTPUT}/${subdir}")
  if(IS_SYMLINK "${first}/${file}")
    copy_entry("${first}/${file}" "${dest_dir}")
    continue()
  endif()

  set(all_thin_macho TRUE)
  set(all_identical TRUE)
  file(SHA256 "${first}/${file}" first_hash)
  set(slices)
  foreach(root IN LISTS roots)
    file(READ "${root}/${file}" magic LIMIT 4 HEX)
    if(NOT magic IN_LIST thin_macho_magics)
      set(all_thin_macho FALSE)
    endif()
    file(SHA256 "${root}/${file}" hash)
    if(NOT hash STREQUAL first_hash)
      set(all_identical FALSE)
    endif()
    list(APPEND slices "${root}/${file}")
  endforeach()

  if(all_identical)
    copy_entry("${first}/${file}" "${dest_dir}")
  elseif(all_thin_macho)
    file(MAKE_DIRECTORY "${dest_dir}")
    execute_process(COMMAND "${LIPO}" -create ${slices} -output "${OUTPUT}/${file}"
      RESULT_VARIABLE lipo_result)
    if(NOT lipo_result EQUAL 0)
      message(FATAL_ERROR "lipo failed for ${file}")
    endif()
    file(CHMOD "${OUTPUT}/${file}" FILE_PERMISSIONS
      OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    math(EXPR lipo_count "${lipo_count} + 1")
  else()
    message(FATAL_ERROR "${file} differs between host architectures but isn't a Mach-O pair")
  endif()
endforeach()
message(STATUS "native: ${lipo_count} files lipo'd from ${ROOTS}")

copy_entry("${CROSS}/${RESOURCE_DIR}/lib/darwin" "${OUTPUT}/${RESOURCE_DIR}/lib")
file(GLOB cross_libcxx "${CROSS}/lib/libc++*")
foreach(entry IN LISTS cross_libcxx)
  copy_entry("${entry}" "${OUTPUT}/lib")
endforeach()
copy_entry("${CROSS}/lib/libBlocksRuntime.a" "${OUTPUT}/lib")
copy_entry("${CROSS}/lib/arc" "${OUTPUT}/lib")
copy_entry("${CROSS}/lib/legacy-support" "${OUTPUT}/lib")
foreach(entry c++ LegacySupport Block.h arclite.h)
  copy_entry("${CROSS}/include/${entry}" "${OUTPUT}/include")
endforeach()

foreach(mode clang clang++)
  file(WRITE "${OUTPUT}/bin/${mode}.cfg"
"-mmacosx-version-min=10.5
-idirafter <CFGDIR>/../include
--ld-path=<CFGDIR>/ld64
-mlinker-version=127.2
")
endforeach()
