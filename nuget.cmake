
if (MSVC)
  SET(CGET_MSVC_RUNTIME "${CMAKE_VS_PLATFORM_TOOLSET}")
  if (NOT CGET_MSVC_RUNTIME)
    MESSAGE(FATAL_ERROR " Generator not recognized ${CMAKE_GENERATOR} (${CMAKE_VS_PLATFORM_TOOLSET}")
  endif ()
  SET(CGET_DYN_NUGET_PATH_HINT "${CGET_MSVC_RUNTIME}.windesktop.msvcstl.dyn.rt-dyn.${CGET_ARCH}")
  SET(CGET_STATIC_NUGET_PATH_HINT "${CGET_MSVC_RUNTIME}.windesktop.msvcstl.dyn.rt-static.${CGET_ARCH}")
endif ()

macro(CGET_NUGET_BUILD name version)
  CGET_MESSAGE(3 "CGET_NUGET_BUILD ${ARGV}")
  set(OUTPUTDIR ${CGET_INSTALL_DIR})
  if (REPO_DIR)
    set(OUTPUTDIR ${REPO_DIR})
  endif ()
  set(VERSION_SPEC "")
  if (version)
    set(VERSION_SPEC "-version ${version}")
  endif ()
  set(searchsuffix ${ARGN})
  if (NOT CGET_NUGET OR NOT EXISTS "${CGET_NUGET}")
    cget_message(2 "Nuget path ${CGET_NUGET}")
    set(CGET_NUGET)
    find_program(CGET_NUGET nuget)
    if (NOT CGET_NUGET OR NOT EXISTS "${CGET_NUGET}")
      file(DOWNLOAD https://dist.nuget.org/win-x86-commandline/latest/nuget.exe "${CGET_INSTALL_DIR}/bin/nuget.exe" EXPECTED_MD5 d2b71f5cfae2d0e1b4a8d993c1ef43b8)
      find_program(CGET_NUGET nuget REQUIRED)
    endif ()
  endif ()
  CGET_EXECUTE_PROCESS(COMMAND ${CGET_NUGET} install ${name}${searchsuffix} ${VERSION_SPEC} -outputdirectory "${OUTPUTDIR}")

  CGET_HAS_DEPENDENCY(file-type-utils GITHUB cget/file-type-utils VERSION master)

  SET(LIBTYPE "SHARED_LIBRARY")
  IF(ARGS_NUGET_USE_STATIC)
    SET(LIBTYPE "STATIC_LIBRARY")
  endif()

  file(GLOB_RECURSE DLLS "${OUTPUTDIR}" "${OUTPUTDIR}/*.dll")
  CGET_FILTER_INCOMPATIBLE(DLLS ${LIBTYPE})

  file(GLOB_RECURSE LIBS "${OUTPUTDIR}" "${OUTPUTDIR}/*.lib")
  CGET_FILTER_INCOMPATIBLE(LIBS ${LIBTYPE})

  CGET_FILTER_BY_RUNTIME(DLLS_DEBUG DLLS "DEBUG")
  CGET_FILTER_BY_RUNTIME(DLLS_RELEASE DLLS "RELEASE")

  CGET_ALL_FILENAME_COMPONENTS(DLLS_DEBUG_NAMES "${DLLS_DEBUG}" NAME_WE)
  CGET_ALL_FILENAME_COMPONENTS(DLLS_RELEASE_NAMES "${DLLS_RELEASE}" NAME_WE)

  file(GLOB_RECURSE INCLUDE_DIR LIST_DIRECTORIES true "${OUTPUTDIR}/*/include/")

  CGET_MESSAGE(2 "${name} nuget package provides ${DLLS} ${LIBS}")
  if(NOT DLLS AND NOT LIBS)
    message(FATAL_ERROR "Package ${name} doesn't provide any libraries, please check your configuration")
  endif()

  file(COPY ${LIBS} DESTINATION "${CGET_INSTALL_DIR}/lib")
  file(COPY ${DLLS_RELEASE} DESTINATION "${CGET_INSTALL_DIR}/bin")

  # For debug dlls, we have to make sure they don't have the exact same name
  foreach(DLL_DEBUG ${DLLS_DEBUG})

    GET_FILENAME_COMPONENT(DLL_DEBUG_NAME "${DLL_DEBUG}" NAME_WE)
    LIST(FIND DLLS_RELEASE_NAMES ${DLL_DEBUG_NAME} IDX)
    if(NOT IDX EQUAL -1)

      # If they do, we rename the debug dll to use the 'd' suffix
      #GET_FILENAME_COMPONENT(DLL_DIR "${DLL_DEBUG}" DIRECTORY)
      #SET(NEWNAME "${CGET_INSTALL_DIR}/bin/${DLL_DEBUG_NAME}d.dll")
      #FILE(RENAME "${DLL_DEBUG}" "${NEWNAME}")

      # We have to regenerate the libs for both release and debug since the copy above let it in an indeterminate state
      #CGET_DLL2LIB("${NEWNAME}" "${CGET_INSTALL_DIR}/lib")
      #CGET_DLL2LIB("${CGET_INSTALL_DIR}/bin/${DLL_DEBUG_NAME}.dll" "${CGET_INSTALL_DIR}/lib")
    else()
      # No conflict! Just copy it
      FILE(COPY "${DLL_DEBUG}" DESTINATION "${CGET_INSTALL_DIR}/bin")
    endif()
  endforeach()

  foreach (DIR ${INCLUDE_DIR})
    IF (DIR MATCHES ".*/include$")
      file(COPY ${DIR} DESTINATION "${CGET_INSTALL_DIR}/")
    ENDIF ()
  endforeach ()

  set(NUGET_DIR "${OUTPUTDIR}/${name}.${CGET_NUGET_PATH_HINT}.${version}")
  set(CGET_${name}_NUGET_DIR ${NUGET_DIR} CACHE STRING "" FORCE)
  set(LIB_DIR "${NUGET_DIR}/lib/native/${CGET_MSVC_RUNTIME}/windesktop/msvcstl/dyn/rt-dyn/${CGET_ARCH}/")
  list(APPEND CMAKE_LIBRARY_PATH "${LIB_DIR}/debug" "${LIB_DIR}/release")
  list(APPEND CMAKE_INCLUDE_PATH "${NUGET_DIR}/build/native/include")
  include_directories("${NUGET_DIR}/build/native/include")
  CGET_WRITE_CGET_SETTINGS_FILE()
  CGET_MESSAGE(3 "END CGET_NUGET_BUILD ${ARGV}")
endmacro()

