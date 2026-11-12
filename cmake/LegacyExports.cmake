execute_process(COMMAND "${NM}" -g "${ARCHIVE}"
  OUTPUT_VARIABLE nm_output
  RESULT_VARIABLE nm_result
  ERROR_QUIET)
if(NOT nm_result EQUAL 0)
  message(FATAL_ERROR "${NM} -g ${ARCHIVE} failed")
endif()

string(REPLACE "\n" ";" lines "${nm_output}")
set(symbols)
foreach(line IN LISTS lines)
  if(line MATCHES "^[0-9a-fA-F]+ [A-TV-Z] (.+)$")
    list(APPEND symbols "${CMAKE_MATCH_1}")
  endif()
endforeach()
list(REMOVE_DUPLICATES symbols)
list(SORT symbols)
list(JOIN symbols "\n" contents)
file(WRITE "${OUTPUT}" "${contents}\n")
