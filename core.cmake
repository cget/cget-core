include(CMakeParseArguments)

cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0012 NEW)

find_package(Git)
if(NOT GIT_FOUND)
    message(FATAL_ERROR "Git is required in the path, or you must set ")
endif()

EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config cget.organizeAsSubModule OUTPUT_VARIABLE CGET_ORGANIZE_AS_SUBMODULES)
EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config cget.useSSHForGithub OUTPUT_VARIABLE CGET_USE_SSH_FOR_GITHUB)

if (NOT DEFINED CGET_VERBOSE_LEVEL)
  EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config cget.verbose OUTPUT_VARIABLE CGET_VERBOSE_LEVEL)
endif()

if (NOT DEFINED CGET_VERBOSE_LEVEL)
  set(CGET_VERBOSE_LEVEL 5)
endif()

if (NOT DEFINED CGET_CORE_DIR)
  set(CGET_CORE_DIR "${CMAKE_SOURCE_DIR}/")
  set(CGET_IS_ROOT_DIR ON)

  ADD_CUSTOM_TARGET(cget-clean-packages COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_BIN_DIR}")
  ADD_CUSTOM_TARGET(cget-rebuild-packages)
endif()

FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_CORE_HASH)
FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_PACKAGE_HASH)

set(CGET_CORE_VERSION 0.1.4)

if (NOT CGET_BIN_DIR)
  SET(CGET_BIN_DIR "${CMAKE_SOURCE_DIR}/.cget-bin/")
endif ()

function(CGET_MESSAGE LVL)
  if(NOT CGET_VERBOSE_LEVEL LESS LVL)
    message("cget: ${ARGN}")
  endif()
endfunction()

macro(CGET_EXECUTE_PROCESS)
  CGET_MESSAGE(3 "Running exec process: ${ARGN}")
  execute_process(${ARGN} RESULT_VARIABLE EXECUTE_RESULT)
  if(EXECUTE_RESULT)
    message(FATAL_ERROR "Execute process '${ARGN}' failed with '${EXECUTE_RESULT}', result: ${RESULT_VARIABLE}")
  endif()
endmacro()

if (NOT CGET_PACKAGE_DIR)
  SET(CGET_PACKAGE_DIR ${CGET_BIN_DIR}/packages)
endif ()

if(CGET_ORGANIZE_AS_SUBMODULES AND NOT EXISTS ${CGET_PACKAGE_DIR}/.git)
  FILE(MAKE_DIRECTORY ${CGET_PACKAGE_DIR})  
  CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} init WORKING_DIRECTORY ${CGET_PACKAGE_DIR})
endif()

SET(CGET_INSTALL_DIR ${CGET_BIN_DIR}/install_root/${CMAKE_GENERATOR})

set(CGET_BUILD_CONFIGS ${CMAKE_CONFIGURATION_TYPES})
if(NOT CGET_BUILD_CONFIGS)
        set(CGET_BUILD_CONFIGS ${CMAKE_BUILD_TYPE})
    else()
        set(CGET_BUILD_CONFIGS "Debug;Release")
endif()

set(CGET_VERBOSE_SUFFIX OFF)

IF(CGET_VERBOSE_SUFFIX)
    SET(OLD_SUFFIX "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    SET(CMAKE_FIND_LIBRARY_SUFFIXES)
    foreach(suffix ${OLD_SUFFIX})
        foreach(configuration ${CGET_BUILD_CONFIGS})
            list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES "_${configuration}${suffix}")
        endforeach()
    endforeach()   
    CGET_MESSAGE(3 "${OLD_SUFFIX} vs ${CMAKE_FIND_LIBRARY_SUFFIXES}")
ELSE()
    set(CMAKE_DEBUG_POSTFIX "d")
ENDIF()
    
set(CMAKE_FIND_ROOT_PATH ${CGET_INSTALL_DIR})
FILE(MAKE_DIRECTORY ${CGET_INSTALL_DIR}/lib/cmake)
list(APPEND CMAKE_PREFIX_PATH ${CGET_INSTALL_DIR} ${CGET_INSTALL_DIR}/lib/cmake)
list(APPEND CMAKE_MODULE_PATH ${CGET_INSTALL_DIR}/lib/cmake)
set(CMAKE_LIBRARY_PATH ${CGET_INSTALL_DIR}/lib)

list(APPEND CMAKE_INSTALL_RPATH ${CMAKE_LIBRARY_PATH})

if(MSVC)
    cget_message(3 "Setting up paths for '${CMAKE_GENERATOR}'")
    if("${CMAKE_GENERATOR}" MATCHES "Win64")
        set(CGET_ARCH "x64")
    else()
        set(CGET_ARCH "x86")
    endif()
    if("${CMAKE_GENERATOR}" MATCHES "Visual Studio 14 2015")
        SET(CGET_MSVC_RUNTIME "v140")
    elseif("${CMAKE_GENERATOR}" MATCHES "Visual Studio 12 2013")
        SET(CGET_MSVC_RUNTIME "v120")
    else()
        MESSAGE(FATAL_ERROR " Generator not recognized ${CMAKE_GENERATOR}")
    endif()
    SET(CGET_NUGET_PATH_HINT "${CGET_MSVC_RUNTIME}.windesktop.msvcstl.dyn.rt-dyn.${CGET_ARCH}")
endif()

macro(CGET_NUGET_BUILD name version)    
    CGET_MESSAGE(3 "CGET_NUGET_BUILD ${ARGV}")
    set(OUTPUTDIR ${CGET_INSTALL_DIR})
    if(REPO_DIR)
        set(OUTPUTDIR ${REPO_DIR})
    endif()
    set(VERSION_SPEC "")
    if(version)
        set(VERSION_SPEC "-version ${version}")
    endif()
    set(searchsuffix ${ARGN})
    if(NOT CGET_NUGET OR NOT EXISTS "${CGET_NUGET}")
        cget_message(2 "Nuget path ${CGET_NUGET}")
        set(CGET_NUGET)
        find_program(CGET_NUGET nuget)
        if(NOT CGET_NUGET  OR NOT EXISTS "${CGET_NUGET}")
            file(DOWNLOAD https://dist.nuget.org/win-x86-commandline/latest/nuget.exe "${CGET_INSTALL_DIR}/bin/nuget.exe")
            find_program(CGET_NUGET nuget REQUIRED)
        endif()
    endif()
    CGET_EXECUTE_PROCESS(COMMAND ${CGET_NUGET} install ${name}${searchsuffix} ${VERSION_SPEC} -outputdirectory "${OUTPUTDIR}")
    
    file(GLOB_RECURSE DLLS "${OUTPUTDIR}" "${OUTPUTDIR}/*.dll")
    file(GLOB_RECURSE LIBS "${OUTPUTDIR}" "${OUTPUTDIR}/*.lib")
    file(GLOB_RECURSE INCLUDE_DIR LIST_DIRECTORIES true "${OUTPUTDIR}/*/include/")
    
    file(COPY ${DLLS} DESTINATION "${CGET_INSTALL_DIR}/bin")
    file(COPY ${LIBS} DESTINATION "${CGET_INSTALL_DIR}/lib")
    
    foreach(DIR ${INCLUDE_DIR})
        IF(DIR MATCHES ".*/include$")
            file(COPY ${DIR} DESTINATION "${CGET_INSTALL_DIR}/")    
        ENDIF()
    endforeach()
    
    
    message("Getting ${OUTPUTDIR} ${INCLUDE_DIR}")
    set(NUGET_DIR "${OUTPUTDIR}/${name}.${CGET_NUGET_PATH_HINT}.${version}")
    set(CGET_${name}_NUGET_DIR ${NUGET_DIR} CACHE STRING "" FORCE)
    set(LIB_DIR "${NUGET_DIR}/lib/native/${CGET_MSVC_RUNTIME}/windesktop/msvcstl/dyn/rt-dyn/${CGET_ARCH}/")
    list(APPEND CMAKE_LIBRARY_PATH "${LIB_DIR}/debug" "${LIB_DIR}/release")
    list(APPEND CMAKE_INCLUDE_PATH "${NUGET_DIR}/build/native/include")
    include_directories("${NUGET_DIR}/build/native/include")     
    CGET_WRITE_CGET_SETTINGS_FILE()    
    CGET_MESSAGE(3 "END CGET_NUGET_BUILD ${ARGV}")
endmacro()

CGET_MESSAGE(3 "Install dir: ${CGET_INSTALL_DIR}")
CGET_MESSAGE(3 "Bin dir: ${CGET_BIN_DIR}")

include_directories("${CGET_INSTALL_DIR}/include")
link_directories("${CGET_INSTALL_DIR}" "${CMAKE_LIBRARY_PATH}")

function(CGET_WRITE_CGET_SETTINGS_FILE)
  set(WRITE_STR "SET(CMAKE_INSTALL_PREFIX \t\"${CGET_INSTALL_DIR}\" CACHE PATH \"\")\n")    
  
  foreach(varname CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH CGET_BIN_DIR CMAKE_CONFIGURATION_TYPES CMAKE_INSTALL_RPATH CGET_PACKAGE_DIR CGET_INSTALL_DIR CGET_CORE_DIR CMAKE_FIND_ROOT_PATH CMAKE_PREFIX_PATH BUILD_SHARED_LIBS CMAKE_FIND_LIBRARY_SUFFIXES)
    if(DEFINED ${varname})
      set(WRITE_STR "${WRITE_STR}SET(${varname} \t\"${${varname}}\" CACHE STRING \"\")\n")
    endif()
  endforeach()
  
  
  foreach(configuration ${CGET_BUILD_CONFIGS})
    STRING(TOUPPER ${configuration} configuration_upper)
    IF(CGET_VERBOSE_SUFFIX)    
      set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"_${configuration_upper}\" CACHE STRING \"\")\n")      
    elseif(DEFINED CMAKE_${configuration_upper}_POSTFIX)
      set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"${CMAKE_${configuration_upper}_POSTFIX}\" CACHE STRING \"\")\n")      
    endif()
  endforeach()    
  

  CGET_MESSAGE(2 "Writing load file to ${CGET_BIN_DIR}/load.cmake")
  file(WRITE "${CGET_BIN_DIR}/load.cmake" "${WRITE_STR}")    
endfunction()

if(CGET_IS_ROOT_DIR)
  CGET_WRITE_CGET_SETTINGS_FILE()
endif()

macro(CGET_PARSE_VERSION NAME INPUT RESULT)
  SET(${RESULT} ${${INPUT}})
  STRING(TOLOWER "${${RESULT}}" ${RESULT})
  STRING(TOLOWER ${NAME} CGET_${NAME}_LOWER)
  STRING(REPLACE "${CGET_${NAME}_LOWER}" "" ${RESULT} "${${RESULT}}")
  STRING(REGEX MATCH "([0-9]+[\\._]?)+" ${RESULT} "${${RESULT}}")
  STRING(REPLACE "_" "." ${RESULT} "${${RESULT}}")
endmacro()

function(CGET_NORMALIZE_CMAKE_FILES DIR SUFFIX NEW_SUFFIX)
  file(GLOB config_files RELATIVE "${DIR}" "${DIR}/*${SUFFIX}")
  foreach (config_file ${config_files})
    STRING(REPLACE "${SUFFIX}" "" root_name "${config_file}")
    STRING(TOLOWER "${root_name}" root_name)
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E copy "${DIR}/${config_file}" "${DIR}/${root_name}-${NEW_SUFFIX}")
  endforeach ()

endfunction()

SET(REL_BUILD_DIR "build-${CMAKE_GENERATOR}")
if(CMAKE_BUILD_TYPE)
  SET(RELEASE_REL_BUILD_DIR "${REL_BUILD_DIR}-Release")  
  SET(REL_BUILD_DIR "${REL_BUILD_DIR}-${CMAKE_BUILD_TYPE}")
endif()

macro(CGET_FILE_CONTENTS filename var)
  if(EXISTS ${filename})
    file(READ ${filename} "${var}")
  endif()
endmacro()

CGET_FILE_CONTENTS("${CGET_INSTALL_DIR}/.install" INSTALL_CACHE_VAL)  
if (NOT INSTALL_CACHE_VAL STREQUAL CGET_CORE_VERSION)
    CGET_MESSAGE(3 "Install out of date ${INSTALL_CACHE_VAL} vs ${CGET_CORE_VERSION}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_INSTALL_DIR}")
    
    file(WRITE "${CGET_INSTALL_DIR}/.install" "${CGET_CORE_VERSION}")
endif ()

macro(CGET_PARSE_OPTIONS name)
  set(options NO_FIND_PACKAGE REGISTRY NOSUBMODULES PROXY)
  set(oneValueArgs GITHUB GIT HG SVN URL NUGET_PACKAGE NUGET_VERSION VERSION FINDNAME COMMIT_ID REGISTRY_VERSION OPTIONS_FILE)
  set(multiValueArgs OPTIONS FIND_OPTIONS)

  CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
  CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)

  CGET_MESSAGE(5 "PARSE_OPTIONS ${ARGV} ")
  if (ARGS_REGISTRY)
    set(ARGS_GITHUB "cget/${name}.cget")
    set(ARGS_PROXY ON)
  endif ()

  if (ARGS_GITHUB)
    if(CGET_USE_SSH_FOR_GITHUB)
      set(ARGS_GIT "git@github.com:${ARGS_GITHUB}")
    else()
      set(ARGS_GIT "http://github.com/${ARGS_GITHUB}")
    endif()
  endif ()
    
  string(MD5 Repo_Hash "${name} ${ARGS_GIT} ${ARGS_VERSION} ${NOSUBMODULES} ${ARGS_COMMIT_ID} ${ARGS_REGISTRY_VERSION}")
  string(MD5 Build_Hash "${name} ${ARGS_OPTIONS} ${ARGS_NOSUBMODULES} ${CGET_BUILD_CONFIGS} ${CGET_CORE_VERSION}")

  SET(CHECKOUT_TAG "${ARGS_VERSION}")
  if (ARGS_PROXY)
    SET(CGET_REQUESTED_VERSION ${ARGS_VERSION})
    SET(CHECKOUT_TAG "${ARGS_REGISTRY_VERSION}")
  endif()

  set(REPO_DIR_SUFFIX "${CHECKOUT_TAG}${ARGS_COMMIT_ID}")    

  if("" STREQUAL "${REPO_DIR_SUFFIX}")
    set(REPO_DIR_SUFFIX "HEAD")    
  endif()
  
  if(ARGS_PROXY)
    set(REPO_DIR_SUFFIX "${REPO_DIR_SUFFIX}.cget")
  endif()

  set(REPO_DIR "${CGET_PACKAGE_DIR}/${name}_${REPO_DIR_SUFFIX}")
  set(BUILD_DIR "${REPO_DIR}/${REL_BUILD_DIR}")
  if(DEFINED RELEASE_REL_BUILD_DIR)
    set(RELEASE_BUILD_DIR "${REPO_DIR}/${RELEASE_REL_BUILD_DIR}")
  endif()
  if(NOT ARGS_PROXY)
    set(CGET_${name}_REPO_DIR "${REPO_DIR}" CACHE STRING "" FORCE)
    set(CGET_${name}_BUILD_DIR "${BUILD_DIR}" CACHE STRING "" FORCE)
  endif()

  CGET_MESSAGE(2 "Setup for ${name}")
  CGET_MESSAGE(2 "NUGET_PACKAGE: ${ARGS_NUGET_PACKAGE}")
  CGET_MESSAGE(2 "CMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
  CGET_MESSAGE(2 "COMMIT_ID: ${ARGS_COMMIT_ID}")    
  CGET_MESSAGE(2 "CHECKOUT_TAG: ${CHECKOUT_TAG}")  
  CGET_MESSAGE(2 "REPO_DIR: ${REPO_DIR}")
  CGET_MESSAGE(2 "BUILD_DIR: ${BUILD_DIR}")
  CGET_MESSAGE(2 "RELEASE_BUILD_DIR: ${RELEASE_BUILD_DIR}")
  CGET_MESSAGE(2 "CMAKE_CONFIGURATION_TYPES: ${CMAKE_CONFIGURATION_TYPES}")
endmacro()

macro(CGET_BUILD_CMAKE name)
  CGET_PARSE_OPTIONS(${ARGV})
  separate_arguments(ARGS_OPTIONS)

  set(CMAKE_ROOT ${REPO_DIR})	
  if(NOT EXISTS ${REPO_DIR}/CMakeLists.txt)
    IF(EXISTS ${REPO_DIR}/src/CMakeLists.txt)
        set(CMAKE_ROOT ${REPO_DIR}/src)
    else()
        set(CMAKE_ROOT ${REPO_DIR}/cmake)
    endif()
  endif()

  if(NOT DEFINED ARGS_OPTIONS_FILE)
    SET(ARGS_OPTIONS_FILE ${CGET_BIN_DIR}/load.cmake)
  endif()
  
  set(CMAKE_OPTIONS ${ARGS_OPTIONS}
    -C${ARGS_OPTIONS_FILE}
    -G${CMAKE_GENERATOR}
    --no-warn-unused-cli            
    )

  if (ARGS_PROXY)
    list(APPEND CMAKE_OPTIONS -DCGET_REQUESTED_VERSION=${CGET_REQUESTED_VERSION})
  endif()
  
  if (NOT "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
    set(sub_toolchain_file ${CMAKE_TOOLCHAIN_FILE})
    if (NOT IS_ABSOLUTE ${sub_toolchain_file})
      set(sub_toolchain_file ${CGET_CORE_DIR}/${CMAKE_TOOLCHAIN_FILE})
    endif ()
    list(APPEND CMAKE_OPTIONS -DCMAKE_TOOLCHAIN_FILE=${sub_toolchain_file})
  endif ()

  if(DEFINED CMAKE_BUILD_TYPE)
    FILE(MAKE_DIRECTORY "${RELEASE_BUILD_DIR}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY "${BUILD_DIR}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE}               WORKING_DIRECTORY "${BUILD_DIR}")

    if(RELEASE_BUILD_DIR)
      # Some find configs only care about the release package, so build that too
      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Release             ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY "${RELEASE_BUILD_DIR}")
      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config Release                           WORKING_DIRECTORY "${RELEASE_BUILD_DIR}")
    endif()
  else()

    # Set up the packages
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY ${BUILD_DIR})

    # Do a build for reach configuration
    CGET_MESSAGE(1 "Building ${CGET_BUILD_CONFIGS}")
    foreach(configuration ${CGET_BUILD_CONFIGS})
      CGET_MESSAGE(2 " ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR}")	
      # Some builds define configuration types all their own, so we can't fail here if the config doesn't exist
      EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR})
    endforeach()
  endif()
endmacro()

macro(CGET_BUILD_AUTOCONF name)
  CGET_PARSE_OPTIONS(${ARGV})
  separate_arguments(ARGS_OPTIONS)  
endmacro()

function(CGET_FORCE_BUILD name)
  CGET_PARSE_OPTIONS(${ARGV})

  if (NOT ARGS_OPTIONS)
    CGET_MESSAGE(1 "Building ${name}...")
  else ()
    CGET_MESSAGE(1 "Building ${name}... (With: '${ARGS_OPTIONS}')")
  endif ()
  set(CGET_${name}_BUILT 0)

  file(MAKE_DIRECTORY ${BUILD_DIR})

  if(MSVC AND ARGS_NUGET_PACKAGE)
    set(CGET_${name}_BUILT 1)
  elseif (EXISTS "${REPO_DIR}/include.cmake")
    set(CGET_${name}_BUILT 1)
  elseif (EXISTS ${REPO_DIR}/CMakeLists.txt OR EXISTS ${REPO_DIR}/cmake/CMakeLists.txt OR EXISTS ${REPO_DIR}/src/CMakeLists.txt)
    CGET_BUILD_CMAKE(${ARGV})
    set(CGET_${name}_BUILT 1)
  elseif (EXISTS ${REPO_DIR}/autogen.sh)
    CGET_EXECUTE_PROCESS(COMMAND ./autogen.sh WORKING_DIRECTORY ${REPO_DIR})
  endif ()
 
  foreach (config_variant configure config)
    if (NOT CGET_${name}_BUILT AND EXISTS ${REPO_DIR}/${config_variant})
      STRING(REPLACE " " " " CGET_INSTALL_DIR_SAFE "${CGET_INSTALL_DIR}")
      
      CGET_EXECUTE_PROCESS(COMMAND ./${config_variant} --prefix="${CGET_INSTALL_DIR_SAFE}" ${ARGS_OPTIONS}
        WORKING_DIRECTORY ${REPO_DIR})
      CGET_EXECUTE_PROCESS(COMMAND make
        WORKING_DIRECTORY ${REPO_DIR})
      CGET_EXECUTE_PROCESS(COMMAND make install
        WORKING_DIRECTORY ${REPO_DIR})
      set(CGET_${name}_BUILT 1)
    endif ()
  endforeach ()

  if (NOT CGET_${name}_BUILT)
    message(FATAL_ERROR "Couldn't identify build system for ${name} in ${REPO_DIR}")
  endif ()

  CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "Config.cmake" "config.cmake")
  CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "ConfigVersion.cmake" "config-version.cmake")
endfunction(CGET_FORCE_BUILD)

function(CGET_BUILD)
  CGET_PARSE_OPTIONS(${ARGV})
  CGET_FILE_CONTENTS("${BUILD_DIR}/.built" BUILD_CACHE_VAL)

  if(NOT BUILD_CACHE_VAL STREQUAL Build_Hash)
    CGET_MESSAGE(3 "Build out of date ${BUILD_CACHE_VAL} vs ${Build_Hash}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${BUILD_DIR}")
    IF(DEFINED RELEASE_BUILD_DIR)
      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${RELEASE_BUILD_DIR}")
    ENDIF()
    CGET_FORCE_BUILD(${ARGV})
    file(WRITE "${BUILD_DIR}/.built" "${Build_Hash}")           
  endif()
endfunction()

function(CGET_DIRECT_GET_PACKAGE name)
  CGET_PARSE_OPTIONS(${ARGV})
  CGET_MESSAGE(3 "CGET_DIRECT_GET_PACKAGE ${ARGV}")
  CGET_MESSAGE(1 "Getting ${name}...")

  set(GIT_SUBMODULE_OPTIONS "--recursive")
  if (ARGS_NOSUBMODULES)
    set(GIT_SUBMODULE_OPTIONS "")
  endif ()

  set(STAGING_DIR "${REPO_DIR}")

  if (NOT EXISTS ${STAGING_DIR})    
    if (MSVC AND ARGS_NUGET_PACKAGE)
        CGET_NUGET_BUILD(${ARGS_NUGET_PACKAGE} "${ARGS_NUGET_VERSION}")
    elseif (ARGS_GIT)

      if(NOT DEFINED ARGS_COMMIT_ID AND NOT DEFINED CHECKOUT_TAG)
	
      endif()

      SET(NO_VERSION_SPECIFIED OFF)
      if ("" STREQUAL "${CHECKOUT_TAG}")
        set(CHECKOUT_TAG "master")
	if(NOT DEFINED ARGS_COMMIT_ID)
	  SET(NO_VERSION_SPECIFIED ON)
	endif()
      endif ()
           
      if(ARGS_COMMIT_ID)
	set(_GIT_OPTIONS -n)
      else()
	set(_GIT_OPTIONS --progress --branch=${CHECKOUT_TAG} --depth=1)	
      endif()
      
      CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} clone ${ARGS_GIT} ${STAGING_DIR} ${_GIT_OPTIONS} ${GIT_SUBMODULE_OPTIONS} OUTPUT_QUIET ERROR_QUIET)

      if(ARGS_COMMIT_ID)
	CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} checkout ${ARGS_COMMIT_ID}
	  WORKING_DIRECTORY ${STAGING_DIR} OUTPUT_QUIET ERROR_QUIET )	
      endif()

      if(NO_VERSION_SPECIFIED)
	CGET_MESSAGE(2 "Warning: no repo version specified for ${name} (${ARGS_GIT}). It is recommended you set one. The current one is: ")
	CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} log --oneline -n1 WORKING_DIRECTORY ${STAGING_DIR})	
      endif()

      if(CGET_ORGANIZE_AS_SUBMODULES)
	EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} submodule add ${STAGING_DIR} WORKING_DIRECTORY ${CGET_PACKAGE_DIR} OUTPUT_QUIET ERROR_QUIET )
	CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} add -u WORKING_DIRECTORY ${CGET_PACKAGE_DIR})
	EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} commit -m "Registered ${name}" WORKING_DIRECTORY ${CGET_PACKAGE_DIR} OUTPUT_QUIET ERROR_QUIET )            
      endif()
      
    endif ()

  endif ()
endfunction()

function(CGET_GET_PACKAGE)
  CGET_MESSAGE(5 "CGET_GET_PACKAGE ${ARGV}")
  
  CGET_PARSE_OPTIONS(${ARGV})  
  CGET_FILE_CONTENTS("${REPO_DIR}/.retrieved" REPO_CACHE_VAL)
  if (NOT REPO_CACHE_VAL STREQUAL Repo_Hash)
    CGET_MESSAGE(3 "Repo out of date ${REPO_CACHE_VAL} vs ${Repo_Hash}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${REPO_DIR}")
    CGET_DIRECT_GET_PACKAGE(${ARGV})
    file(WRITE "${REPO_DIR}/.retrieved" "${Repo_Hash}")
  ENDIF ()

  CGET_MESSAGE(5 "EXIT CGET_GET_PACKAGE ${ARGV}")
endfunction()

function(CGET_HAS_DEPENDENCY name)
  CGET_PARSE_OPTIONS(${ARGV})
  CGET_MESSAGE(5 "CGET_HAS_DEPENDENCY ${ARGV}")
  CGET_MESSAGE(2 "Checking out ${name}(${CHECKOUT_TAG}) into ${REPO_DIR}, building in ${BUILD_DIR}" )
  
  CGET_GET_PACKAGE(${ARGV})
  
  CGET_FILE_CONTENTS("${BUILD_DIR}/.built" BUILD_CACHE_VAL)

  if(EXISTS "${REPO_DIR}/include.cmake" )
    set(ARGS_NO_FIND_PACKAGE ON)
    CGET_MESSAGE(3 "Including ${REPO_DIR}/include.cmake")
    include("${REPO_DIR}/include.cmake")
  elseif(NOT BUILD_CACHE_VAL STREQUAL Build_Hash)
    CGET_MESSAGE(3 "Build out of date ${BUILD_CACHE_VAL} vs ${Build_Hash}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${BUILD_DIR}")
    IF(DEFINED RELEASE_BUILD_DIR)
      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${RELEASE_BUILD_DIR}")
    ENDIF()
    CGET_BUILD(${ARGV})
    file(WRITE "${BUILD_DIR}/.built" "${Build_Hash}")      
  endif ()
  
  if(NOT ARGS_FINDNAME)
    set(ARGS_FINDNAME "${name}")
  endif()
 
  if (NOT ARGS_NO_FIND_PACKAGE)
    CGET_MESSAGE(3 "Finding ${name} with ${ARGS_CMAKE_VERSION} ${ARGS_FIND_OPTIONS} in ${CMAKE_PREFIX_PATH} ${CMAKE_LIBRARY_PATH} ${CMAKE_INCLUDE_PATH}")
    find_package(${ARGS_FINDNAME} ${ARGS_CMAKE_VERSION} REQUIRED ${ARGS_FIND_OPTIONS}  )

    IF (${${ARGS_FINDNAME}_FOUND})
      CGET_MESSAGE(1 "Found ${name} ${ARGS_CMAKE_VERSION}")
    ENDIF ()
  endif ()
  CGET_MESSAGE(5 "EXIT CGET_HAS_DEPENDENCY ${ARGV}")
endfunction(CGET_HAS_DEPENDENCY) 
 
