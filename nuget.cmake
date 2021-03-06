if (MSVC)
  SET(CGET_MSVC_RUNTIME "${CMAKE_VS_PLATFORM_TOOLSET}")
  if (NOT CGET_MSVC_RUNTIME)
    # Implies a CMake build using VS compiler but not a VS project generator (NMake/Ninja/etc)
    if(DEFINED ENV{VCToolsVersion}) # VCToolsVersion is defined in VS2017+ and doesn't match app version (15.0 = v141)
      STRING(REPLACE "." "" "VCToolsVersion_short" "$ENV{VCToolsVersion}")
      STRING(SUBSTRING ${VCToolsVersion_short} 0 3 VCToolsVersion_short)
      SET(CGET_MSVC_RUNTIME  "v${VCToolsVersion_short}")
    else() # VS2015 and older app version matches toolchain version (14.0 = v140)
      STRING(REPLACE "." "" "VisualStudioVersion_no_period" "$ENV{VisualStudioVersion}" )
      SET(CGET_MSVC_RUNTIME "v${VisualStudioVersion_no_period}")
    endif()
  endif()
  if (NOT CGET_MSVC_RUNTIME)
    MESSAGE(FATAL_ERROR " Generator not recognized ${CMAKE_GENERATOR} (${CMAKE_VS_PLATFORM_TOOLSET}")
  endif ()
  SET(CGET_DYN_NUGET_PATH_HINT "${CGET_MSVC_RUNTIME}.windesktop.msvcstl.dyn.rt-dyn.${CGET_ARCH}")
  SET(CGET_STATIC_NUGET_PATH_HINT "${CGET_MSVC_RUNTIME}.windesktop.msvcstl.dyn.rt-static.${CGET_ARCH}")

  if(CGET_MSVC_RUNTIME MATCHES "v142")
    set(CGET_MSVC_RUNTIME_YEAR 2019)
  elseif(CGET_MSVC_RUNTIME MATCHES "v141")
    set(CGET_MSVC_RUNTIME_YEAR 2017)
  elseif(CGET_MSVC_RUNTIME MATCHES "v140")
    set(CGET_MSVC_RUNTIME_YEAR 2015)
  elseif(CGET_MSVC_RUNTIME MATCHES "v120")
    set(CGET_MSVC_RUNTIME_YEAR 2013)
  elseif(CGET_MSVC_RUNTIME MATCHES "v110")
    set(CGET_MSVC_RUNTIME_YEAR 2012)
  elseif(CGET_MSVC_RUNTIME MATCHES "v100")
    set(CGET_MSVC_RUNTIME_YEAR 2010)
  elseif(CGET_MSVC_RUNTIME MATCHES "v90")
    set(CGET_MSVC_RUNTIME_YEAR 2008)            
  elseif(CGET_MSVC_RUNTIME MATCHES "v80")
    set(CGET_MSVC_RUNTIME_YEAR 2005)            
  endif()
endif ()

macro(CGET_GET_LIBS_FROM_DIR OUTPUTDIR LIBTYPE)
  CGET_HAS_DEPENDENCY(file-type-utils GITHUB cget/file-type-utils COMMIT_ID c22f01e13fb8af960ba1b13c0cafce79f37688d7 )
  
  file(GLOB_RECURSE DLLS "${OUTPUTDIR}" "${OUTPUTDIR}/*.dll")
  CGET_FILTER_INCOMPATIBLE(DLLS ${LIBTYPE})

  file(GLOB_RECURSE LIBS "${OUTPUTDIR}" "${OUTPUTDIR}/*.lib")
  CGET_FILTER_INCOMPATIBLE(LIBS ${LIBTYPE})

  CGET_FILTER_BY_RUNTIME(DLLS_DEBUG DLLS "${CGET_MSVC_RUNTIME} DEBUG")
  CGET_FILTER_BY_RUNTIME(DLLS_RELEASE DLLS "${CGET_MSVC_RUNTIME} RELEASE")

  CGET_ALL_FILENAME_COMPONENTS(DLLS_DEBUG_NAMES "${DLLS_DEBUG}" NAME_WE)
  CGET_ALL_FILENAME_COMPONENTS(DLLS_RELEASE_NAMES "${DLLS_RELEASE}" NAME_WE)

  file(GLOB_RECURSE INCLUDE_DIR LIST_DIRECTORIES true "${OUTPUTDIR}/*/include/")

  CGET_MESSAGE(2 "${name} nuget package provides Release ${DLLS_RELEASE}")
  CGET_MESSAGE(2 "${name} nuget package provides Debug ${DLLS_DEBUG}")
  CGET_MESSAGE(2 "${name} nuget package provides Libs ${LIBS}")
  if(NOT DLLS AND NOT LIBS)
    message(FATAL_ERROR "Package ${name} doesn't provide any libraries, please check your configuration")
  endif()

  file(COPY ${LIBS} DESTINATION "${CGET_${name}_INSTALL_DIR}/lib")
  file(COPY ${DLLS_RELEASE} DESTINATION "${CGET_${name}_INSTALL_DIR}/bin")

  # For debug dlls, we have to make sure they don't have the exact same name
  foreach(DLL_DEBUG ${DLLS_DEBUG})

    GET_FILENAME_COMPONENT(DLL_DEBUG_NAME "${DLL_DEBUG}" NAME_WE)
    LIST(FIND DLLS_RELEASE_NAMES ${DLL_DEBUG_NAME} IDX)
    if(NOT IDX EQUAL -1)

      # If they do, we rename the debug dll to use the 'd' suffix
      #GET_FILENAME_COMPONENT(DLL_DIR "${DLL_DEBUG}" DIRECTORY)
      #SET(NEWNAME "${CGET_${name}_INSTALL_DIR}/bin/${DLL_DEBUG_NAME}d.dll")
      #FILE(RENAME "${DLL_DEBUG}" "${NEWNAME}")

      # We have to regenerate the libs for both release and debug since the copy above let it in an indeterminate state
      #CGET_DLL2LIB("${NEWNAME}" "${CGET_${name}_INSTALL_DIR}/lib")
      #CGET_DLL2LIB("${CGET_${name}_INSTALL_DIR}/bin/${DLL_DEBUG_NAME}.dll" "${CGET_${name}_INSTALL_DIR}/lib")
    else()
      # No conflict! Just copy it
      FILE(COPY "${DLL_DEBUG}" DESTINATION "${CGET_${name}_INSTALL_DIR}/bin")
      CGET_MESSAGE(2 "Providing ${DLL_DEBUG} since it doesn't clash with a release binary")
    endif()
  endforeach()

  foreach (DIR ${INCLUDE_DIR})
    IF (DIR MATCHES ".*/include$")
      file(COPY ${DIR} DESTINATION "${CGET_${name}_INSTALL_DIR}/")
    ENDIF ()
  endforeach ()
endmacro()

macro(CGET_NUGET_BUILD name version)
  CGET_MESSAGE(3 "CGET_NUGET_BUILD ${ARGV} ${version}")
  set(OUTPUTDIR ${CGET_${name}_INSTALL_DIR})
  if (REPO_DIR)
    set(OUTPUTDIR ${REPO_DIR})
  endif ()
  set(VERSION_SPEC "")
  if (NOT ${version} STREQUAL "")
    set(VERSION_SPEC "-Version" "${version}")
  endif ()
  set(searchsuffix ${ARGN})
  if (NOT CGET_NUGET OR NOT EXISTS "${CGET_NUGET}")
    cget_message(2 "Nuget path ${CGET_NUGET}")
    set(CGET_NUGET)
    find_program(CGET_NUGET nuget HINTS "${CGET_BIN_DIR}/extras")
    if (NOT CGET_NUGET OR NOT EXISTS "${CGET_NUGET}")
	  FILE(MAKE_DIRECTORY "${CGET_BIN_DIR}/extras")
      file(DOWNLOAD https://dist.nuget.org/win-x86-commandline/v3.5.0/nuget.exe "${CGET_BIN_DIR}/extras/nuget.exe" 
	  EXPECTED_MD5 406324e1744923a530a3f45b8e4fe1eb  STATUS status LOG log)
	    
		list(GET status 0 status_code) 
		list(GET status 1 status_string) 

		if(NOT status_code EQUAL 0) 
		  file(REMOVE "${CGET_BIN_DIR}/extras/nuget.exe")
		  message(FATAL_ERROR "error: downloading 'nuget' failed 
		  status_code: ${status_code} 
		  status_string: ${status_string} 
		  log: ${log}") 
		endif() 
	  
      find_program(CGET_NUGET nuget REQUIRED HINTS "${CGET_BIN_DIR}/extras")
    endif ()
  endif ()
  CGET_EXECUTE_PROCESS(COMMAND ${CGET_NUGET} install ${name}${searchsuffix} ${VERSION_SPEC} -outputdirectory "${OUTPUTDIR}")

  SET(LIBTYPE "SHARED_LIBRARY")
  IF(ARGS_NUGET_USE_STATIC)
    SET(LIBTYPE "STATIC_LIBRARY")
  endif()

  CGET_GET_LIBS_FROM_DIR("${OUTPUTDIR}" ${LIBTYPE})

  set(NUGET_DIR "${OUTPUTDIR}/${name}.${CGET_NUGET_PATH_HINT}.${version}")
  set(CGET_${name}_NUGET_DIR ${NUGET_DIR} CACHE STRING "" FORCE)
  set(LIB_DIR "${NUGET_DIR}/lib/native/${CGET_MSVC_RUNTIME}/windesktop/msvcstl/dyn/rt-dyn/${CGET_ARCH}/")
  list(APPEND CMAKE_LIBRARY_PATH "${LIB_DIR}/debug" "${LIB_DIR}/release")
  list(APPEND CMAKE_INCLUDE_PATH "${NUGET_DIR}/build/native/include")
  include_directories("${NUGET_DIR}/build/native/include")
  CGET_WRITE_CGET_SETTINGS_FILE()
  CGET_MESSAGE(3 "END CGET_NUGET_BUILD ${ARGV}")
endmacro()

