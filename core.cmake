include(CMakeParseArguments)

if(NOT CGET_CORE_DIR)
  set(CGET_IS_ROOT_DIR TRUE)    
  set(CGET_CORE_DIR "${CMAKE_SOURCE_DIR}/")
endif()
  
set_property( GLOBAL PROPERTY USE_FOLDERS ON)
include("${CGET_CORE_DIR}/.cget/cget_utilities.cmake" REQUIRED)
include("${CGET_CORE_DIR}/.cget/setup.cmake" REQUIRED)
include("${CGET_CORE_DIR}/.cget/nuget.cmake" REQUIRED)
include("${CGET_CORE_DIR}/.cget/homebrew.cmake" REQUIRED)

if(MSVC)
	include("${CGET_CORE_DIR}/.cget/msvc_sln.cmake" REQUIRED)
endif()

CGET_MESSAGE(13 "Install dir: ${CGET_INSTALL_DIR}")
CGET_MESSAGE(13 "Bin dir: ${CGET_BIN_DIR}")
CGET_MESSAGE(13 "Bin dir: ${CGET_CORE_DIR}")

macro(CGET_REGISTER_INSTALL_DIR INSTALL_DIR)
  if (EXISTS ${INSTALL_DIR})
    if (NOT CGET_IS_SCRIPT_MODE)

      CGET_MESSAGE(15 "Registering install dir ${INSTALL_DIR}")
      include_directories("${INSTALL_DIR}/include")
      link_directories("${INSTALL_DIR}")

      FILE(MAKE_DIRECTORY ${INSTALL_DIR}/lib/cmake)
      list(APPEND CMAKE_FIND_ROOT_PATH ${INSTALL_DIR})
      list(APPEND CMAKE_PREFIX_PATH ${INSTALL_DIR} ${INSTALL_DIR}/lib/cmake)
      list(APPEND CMAKE_MODULE_PATH ${INSTALL_DIR}/lib/cmake)
      list(APPEND CMAKE_LIBRARY_PATH ${INSTALL_DIR}/lib)

      FILE(WRITE "${CMAKE_BINARY_DIR}/cget-env.cmake" "")
      
      foreach (varname CMAKE_FIND_ROOT_PATH CMAKE_PREFIX_PATH CMAKE_MODULE_PATH CMAKE_LIBRARY_PATH)
        if (DEFINED ${varname})
            STRING(REPLACE "\\" "/" varvalue "${${varname}}")
	    SET(${varname} ${${varname}})
	    FILE(APPEND "${CMAKE_BINARY_DIR}/cget-env.cmake" "\nSET(${varname}  \"${${varname}}\" CACHE INTERNAL \"\")")
        endif ()
    endforeach ()
      
      file(APPEND "${CMAKE_BINARY_DIR}/cget-usages" "${INSTALL_DIR}\n")      
    endif()
  endif()
endmacro()

#CGET_REGISTER_INSTALL_DIR("${CGET_INSTALL_DIR}")

function(CGET_WRITE_CGET_SETTINGS_FILE)
    foreach (varname CMAKE_INCLUDE_PATH CMAKE_LIBRARY_PATH CGET_BIN_DIR CMAKE_CONFIGURATION_TYPES CMAKE_INSTALL_RPATH 
					 CGET_PACKAGE_DIR CGET_INSTALL_DIR CGET_CORE_DIR CMAKE_FIND_ROOT_PATH CMAKE_PREFIX_PATH 
					BUILD_SHARED_LIBS CMAKE_FIND_LIBRARY_SUFFIXES CGET_BUILD_CONFIGS)
        if (DEFINED ${varname})
            STRING(REPLACE "\\" "/" varvalue "${${varname}}")
            set(WRITE_STR "${WRITE_STR}SET(${varname} \t\"${varvalue}\" CACHE STRING \"\")\n")
        endif ()
    endforeach ()

    foreach (configuration ${CGET_BUILD_CONFIGS})
        STRING(TOUPPER ${configuration} configuration_upper)
        IF (CGET_VERBOSE_SUFFIX)
            set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"_${configuration_upper}\" CACHE STRING \"\")\n")
        elseif (DEFINED CMAKE_${configuration_upper}_POSTFIX)
            set(WRITE_STR "${WRITE_STR}SET(CMAKE_${configuration_upper}_POSTFIX \t\"${CMAKE_${configuration_upper}_POSTFIX}\" CACHE STRING \"\")\n")
        endif ()
    endforeach ()

    CGET_MESSAGE(12 "Writing load file to ${CGET_BIN_DIR}/load.cmake")
    file(WRITE "${CGET_BIN_DIR}/load.cmake" "${WRITE_STR}")
endfunction()

if (CGET_IS_ROOT_DIR)
  CGET_WRITE_CGET_SETTINGS_FILE()  
  CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/cget-usages")
endif ()

STRING(MD5 CMAKE_BINARY_DIR_HASH "${CMAKE_BINARY_DIR}")
FILE(WRITE "${CGET_BIN_DIR}/cget-used-from/${CMAKE_BINARY_DIR_HASH}" "${CMAKE_BINARY_DIR}")
FILE(WRITE "${CMAKE_BINARY_DIR}/cget-env.cmake" "")

function(CGET_NORMALIZE_CMAKE_FILES DIR SUFFIX NEW_SUFFIX)
    file(GLOB config_files RELATIVE "${DIR}" "${DIR}/*${SUFFIX}")
    foreach (config_file ${config_files})
        STRING(REPLACE "${SUFFIX}" "" root_name "${config_file}")
        STRING(TOLOWER "${root_name}" root_name)
        CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E copy "${DIR}/${config_file}" "${DIR}/${root_name}-${NEW_SUFFIX}")
    endforeach ()
endfunction()

SET(REL_BUILD_DIR "build-${CGET_CMAKE_GENERATOR_NO_SPACES}")
if (CMAKE_BUILD_TYPE)
    SET(RELEASE_REL_BUILD_DIR "${REL_BUILD_DIR}-Release")
    SET(REL_BUILD_DIR "${REL_BUILD_DIR}-${CMAKE_BUILD_TYPE}")
endif ()

macro(CGET_FILE_CONTENTS filename var)
    if (EXISTS ${filename})
        file(READ ${filename} "${var}")
    endif ()
endmacro()

CGET_FILE_CONTENTS("${CGET_INSTALL_DIR}/.install" INSTALL_CACHE_VAL)
if (NOT INSTALL_CACHE_VAL STREQUAL CGET_CORE_VERSION)
    CGET_MESSAGE(3 "Install out of date ${INSTALL_CACHE_VAL} vs ${CGET_CORE_VERSION}")
    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_INSTALL_DIR}")

    file(WRITE "${CGET_INSTALL_DIR}/.install" "${CGET_CORE_VERSION}")
endif ()

macro(CGET_PARSE_OPTIONS name)
    set(options NO_FIND_PACKAGE REGISTRY NOSUBMODULES PROXY ALLOW_SYSTEM NUGET_USE_STATIC NO_FIND_VERSION
            PROGRAM LIBRARY SIMPLE_BUILD)
    set(oneValueArgs GITHUB GIT HG SVN URL BREW_PACKAGE NUGET_PACKAGE NUGET_VERSION VERSION FINDNAME COMMIT_ID
            REGISTRY_VERSION OPTIONS_FILE CMAKE_VERSION CMAKE_PATH SUBMODULE SOLUTION_FILE SOLUTION_OUTPUT_DIR SOLUTION_INC_DIRS)
    set(multiValueArgs OPTIONS FIND_OPTIONS SIMPLE_BUILD_SOURCE_FILES SIMPLE_BUILD_HEADER_FILES COMPONENTS)

    CMAKE_PARSE_ARGUMENTS(ARGS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    IF (NOT DEFINED ARGS_CMAKE_VERSION)
        CGET_PARSE_VERSION(${name} ARGS_VERSION ARGS_CMAKE_VERSION)
    ENDIF ()

    if (DEFINED ARGS_NO_FIND_VERSION)
        SET(ARGS_CMAKE_VERSION "")
    endif ()

    if (NOT ARGS_FINDNAME)
        set(ARGS_FINDNAME "${name}")
    endif ()

    if (NOT ARGS_CMAKE_PATH)
        set(ARGS_CMAKE_PATH src)
    endif ()

    IF (ARGS_SIMPLE_BUILD_SOURCE_FILES OR ARGS_SIMPLE_BUILD_HEADER_FILES)
        SET(ARGS_SIMPLE_BUILD ON)
    ENDIF ()

    IF (ARGS_SIMPLE_BUILD)
        set(ARGS_NO_FIND_PACKAGE ON)
    ENDIF ()

    CGET_MESSAGE(15 "PARSE_OPTIONS ${ARGV} ")
    if (ARGS_REGISTRY)
        set(ARGS_GITHUB "cget/${name}.cget")
        set(ARGS_PROXY ON)
    endif ()

    if (ARGS_GITHUB)
        if (CGET_USE_SSH_FOR_GITHUB)
            set(ARGS_GIT "git@github.com:${ARGS_GITHUB}")
        else ()
            set(ARGS_GIT "https://github.com/${ARGS_GITHUB}.git")
        endif ()
    endif ()

    if (ARGS_SUBMODULE)
        EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/${ARGS_SUBMODULE}"
                OUTPUT_VARIABLE SUBMODULE_VERSION)
        STRING(STRIP "${SUBMODULE_VERSION}" SUBMODULE_VERSION)

        EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} diff-index --quiet --cached HEAD --
                WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/${ARGS_SUBMODULE}" RESULT_VARIABLE IS_DIRTY)

        if(${IS_DIRTY})

            EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} diff
                    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/${ARGS_SUBMODULE}" OUTPUT_VARIABLE DIRTY_DIFF)

            STRING(MD5 Diff_Hash "${DIRTY_DIFF}")
            SET(SUBMODULE_VERSION "${SUBMODULE_VERSION}-${Diff_Hash}")
        endif()
    endif ()


    SET(REPO_HASH_STRING  "${name} ${ARGS_GIT} ${ARGS_VERSION} ${NOSUBMODULES} ${ARGS_COMMIT_ID} ${ARGS_REGISTRY_VERSION}")
    SET(BUILD_HASH_STRING "${name} ${ARGS_OPTIONS} ${ARGS_NOSUBMODULES} ${CGET_CORE_VERSION} ${ARGS_NUGET_PACKAGE} ${ARGS_NUGET_USE_STATIC} ${ARGS_NUGET_VERSION} ${ARGS_BREW_PACKAGE}  ${ARGS_VERSION} ${ARGS_COMMIT_ID} ${ARGS_REGISTRY_VERSION}${SUBMODULE_VERSION}")
    
    string(MD5 Repo_Hash "${REPO_HASH_STRING}")
    string(MD5 Build_Hash "${BUILD_HASH_STRING}")

    SET(CHECKOUT_TAG "${ARGS_VERSION}")
    if (ARGS_PROXY)
        SET(CGET_REQUESTED_VERSION ${ARGS_VERSION})
        SET(CHECKOUT_TAG "${ARGS_REGISTRY_VERSION}")
    endif ()

    set(REPO_DIR_SUFFIX "${CHECKOUT_TAG}${ARGS_COMMIT_ID}")

    SET(NO_VERSION_SPECIFIED OFF)
    SET(NEW_VERSION_AVAILABLE OFF)

    if ("" STREQUAL "${CHECKOUT_TAG}" OR "master" STREQUAL "${CHECKOUT_TAG}")
        set(CHECKOUT_TAG "master")
        if (NOT DEFINED ARGS_COMMIT_ID)
            SET(NO_VERSION_SPECIFIED ON)
        endif ()
    endif ()

    if ("" STREQUAL "${REPO_DIR_SUFFIX}")
        set(REPO_DIR_SUFFIX "HEAD")
    endif ()

    if (ARGS_PROXY)
        set(REPO_DIR_SUFFIX "${REPO_DIR_SUFFIX}.cget")
    endif ()

    set(REPO_DIR "${CGET_PACKAGE_DIR}/${name}/${REPO_DIR_SUFFIX}")

    set(INSTALL_DIR "${CGET_INSTALL_DIR}/${name}/${REPO_DIR_SUFFIX}/${Build_Hash}")

    set(BUILD_DIR "${REPO_DIR}/${REL_BUILD_DIR}")
    if (DEFINED RELEASE_REL_BUILD_DIR)
        set(RELEASE_BUILD_DIR "${REPO_DIR}/${RELEASE_REL_BUILD_DIR}")
    endif ()
    if (NOT ARGS_PROXY)
        set(CGET_${name}_REPO_DIR "${REPO_DIR}" CACHE STRING "" FORCE)
        set(CGET_${name}_BUILD_DIR "${BUILD_DIR}" CACHE STRING "" FORCE)
        set(CGET_${name}_INSTALL_DIR "${INSTALL_DIR}" CACHE STRING "" FORCE)
    endif ()


    if (ARGS_SUBMODULE)
        set(REPO_DIR "${CMAKE_SOURCE_DIR}/${ARGS_SUBMODULE}")
    endif ()

    if ((MSVC OR MINGW) AND ARGS_NUGET_PACKAGE)
        SET(CGET_RETRIEVE_MECHANISM NUGET)
    elseif (APPLE AND ARGS_BREW_PACKAGE)
        SET(CGET_RETRIEVE_MECHANISM BREW)
    elseif (ARGS_GIT)
        SET(CGET_RETRIEVE_MECHANISM GIT)
    elseif (ARGS_SVN)
        SET(CGET_RETRIEVE_MECHANISM SVN)
    elseif (ARGS_HG)
        SET(CGET_RETRIEVE_MECHANISM HG)
    elseif (ARGS_URL)
        SET(CGET_RETRIEVE_MECHANISM URL)
    elseif (ARGS_SUBMODULE)
        SET(CGET_RETRIEVE_MECHANISM SUBMODULE)
    else ()
        MESSAGE(FATAL_ERROR "Couldn't determine retrieval mechanism")
    endif ()

    if (NOT CGET_${name}_FIRST_OPTIONS_RUN)
        SET(SETUP_LOG_LEVEL 15)
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "Setup for ${name}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tCGET_RETRIEVE_MECHANISM: ${CGET_RETRIEVE_MECHANISM}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tNUGET_PACKAGE: ${ARGS_NUGET_PACKAGE}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tBREW_PACKAGE: ${ARGS_BREW_PACKAGE}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tCMAKE_BUILD_TYPE: ${CMAKE_BUILD_TYPE}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tCOMMIT_ID: ${ARGS_COMMIT_ID} ${ARGS_VERSION} ${SUBMODULE_VERSION}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tCHECKOUT_TAG: ${CHECKOUT_TAG} (${NO_VERSION_SPECIFIED})")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tFIND_OPTIONS: ${ARGS_OPTIONS} COMPONENETS ${ARGS_COMPONENTS}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tFIND VERSION: ${ARGS_CMAKE_VERSION}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tREPO_DIR: ${REPO_DIR} ${ARGS_CMAKE_PATH}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tINSTALL_DIR: ${INSTALL_DIR}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tBUILD_DIR: ${BUILD_DIR}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tRELEASE_BUILD_DIR: ${RELEASE_BUILD_DIR}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tCMAKE_CONFIGURATION_TYPES: ${CMAKE_CONFIGURATION_TYPES}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tBuild_Hash: ${Build_Hash} - ${name} ${ARGS_OPTIONS} ${ARGS_NOSUBMODULES} ${CGET_BUILD_CONFIGS} ${CGET_CORE_VERSION}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\tRepo_Hash: ${Repo_Hash}")
        CGET_MESSAGE(${SETUP_LOG_LEVEL} "\t${ARGS_SIMPLE_BUILD} ${ARGS_SIMPLE_BUILD_SOURCE_FILES}")

	SET(CGET_${name}_FIRST_OPTIONS_RUN ON)
    endif ()
endmacro()
macro(CGET_SIMPLE_BUILD name)
    CGET_PARSE_OPTIONS(${ARGV})
    IF (NOT ARGS_SIMPLE_BUILD_SOURCE_FILES)
        file(GLOB_RECURSE SIMPLE_BUILD_SOURCE_FILES "${REPO_DIR}/*.cc" "${REPO_DIR}/*.cpp" "${REPO_DIR}/*.c")
    else ()
        CGET_PREPEND_TO_LIST(SIMPLE_BUILD_SOURCE_FILES "${REPO_DIR}" ${ARGS_SIMPLE_BUILD_SOURCE_FILES})
    ENDIF ()

    IF (NOT ARGS_SIMPLE_BUILD_HEADER_FILES)
        file(GLOB_RECURSE SIMPLE_BUILD_HEADER_FILES "${REPO_DIR}" "${REPO_DIR}/*.h" "${REPO_DIR}/*.hpp")
    else ()
        CGET_PREPEND_TO_LIST(SIMPLE_BUILD_HEADER_FILES "${REPO_DIR}" ${ARGS_SIMPLE_BUILD_HEADER_FILES})
    ENDIF ()

    ADD_LIBRARY(${name} STATIC ${SIMPLE_BUILD_SOURCE_FILES} ${SIMPLE_BUILD_HEADER_FILES})
    FILE(COPY ${SIMPLE_BUILD_HEADER_FILES} DESTINATION ${CGET_INSTALL_DIR}/include/${name})
    CGET_MESSAGE(3 "Adding project ${name} with ${SIMPLE_BUILD_SOURCE_FILES} ${SIMPLE_BUILD_HEADER_FILES} -- ${ARGS_SIMPLE_BUILD_SOURCE_FILES}")
    target_include_directories(${name} PUBLIC "${REPO_DIR}")
ENDMACRO()
macro(CGET_BUILD_CMAKE name)
    CGET_PARSE_OPTIONS(${ARGV})
    separate_arguments(ARGS_OPTIONS)

    set(CMAKE_ROOT ${REPO_DIR})
    if (NOT EXISTS ${REPO_DIR}/CMakeLists.txt)
        IF (EXISTS ${REPO_DIR}/${ARGS_CMAKE_PATH}/CMakeLists.txt)
            set(CMAKE_ROOT ${REPO_DIR}/${ARGS_CMAKE_PATH})
        else ()
            set(CMAKE_ROOT ${REPO_DIR}/cmake)
        endif ()
    endif ()

    if (DEFINED ARGS_OPTIONS_FILE)
        SET(USER_INCLUDE_FILE "-C${ARGS_OPTIONS_FILE}")
    endif ()

    set(CMAKE_OPTIONS ${ARGS_OPTIONS}
            -DCMAKE_INSTALL_RPATH_USE_LINK_PATH:BOOL=ON
            -C${CGET_BIN_DIR}/load.cmake
            -C${CMAKE_BINARY_DIR}/cget-env.cmake
            ${USER_INCLUDE_FILE}
            -G${CMAKE_GENERATOR}
            -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}
            --no-warn-unused-cli
            )

    if (ARGS_PROXY)
        list(APPEND CMAKE_OPTIONS -DCGET_REQUESTED_VERSION=${CGET_REQUESTED_VERSION})
    endif ()

    if (NOT "${CMAKE_TOOLCHAIN_FILE}" STREQUAL "")
        set(sub_toolchain_file ${CMAKE_TOOLCHAIN_FILE})
        if (NOT IS_ABSOLUTE ${sub_toolchain_file})
            set(sub_toolchain_file ${CGET_CORE_DIR}/${CMAKE_TOOLCHAIN_FILE})
        endif ()
        list(APPEND CMAKE_OPTIONS -DCMAKE_TOOLCHAIN_FILE=${sub_toolchain_file})
    endif ()

    if (DEFINED CMAKE_BUILD_TYPE AND NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
        FILE(MAKE_DIRECTORY "${RELEASE_BUILD_DIR}")
        CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY "${BUILD_DIR}")
        CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE} WORKING_DIRECTORY "${BUILD_DIR}")

        if (RELEASE_BUILD_DIR)
            # Some find configs only care about the release package, so build that too
            CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Release ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY "${RELEASE_BUILD_DIR}")
            CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config Release WORKING_DIRECTORY "${RELEASE_BUILD_DIR}")
        endif ()
    else ()
        # Set up the packages
        CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} ${CMAKE_OPTIONS} ${CMAKE_ROOT} WORKING_DIRECTORY ${BUILD_DIR})

        # Do a build for reach configuration
        CGET_MESSAGE(1 "Building ${CGET_BUILD_CONFIGS} (${CMAKE_BUILD_TYPE})")
        foreach (configuration ${CGET_BUILD_CONFIGS})
            CGET_MESSAGE(2 " ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR}")
            CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} --build . --target install --config ${configuration} WORKING_DIRECTORY ${BUILD_DIR})
        endforeach ()
    endif ()
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
    if (APPLE AND ARGS_BREW_PACKAGE)
        set(CGET_${name}_BUILT 1)
        CGET_BREW_BUILD(${ARGS_BREW_PACKAGE} "${ARGS_BREW_VERSION}")
    elseif (ARGS_SOLUTION_FILE)
		CGET_MSVC_SLN_BUILD(${ARGS_SOLUTION_FILE})
		set(CGET_${name}_BUILT 1)
    elseif ((MSVC OR MINGW) AND ARGS_NUGET_PACKAGE)
        set(CGET_${name}_BUILT 1)
        CGET_NUGET_BUILD(${ARGS_NUGET_PACKAGE} "${ARGS_NUGET_VERSION}")
    elseif (EXISTS "${REPO_DIR}/include.cmake")
        set(CGET_${name}_BUILT 1)
    elseif (ARGS_SIMPLE_BUILD)
        CGET_SIMPLE_BUILD(${ARGV})
        set(CGET_${name}_BUILT 1)
    elseif (EXISTS ${REPO_DIR}/CMakeLists.txt OR EXISTS ${REPO_DIR}/cmake/CMakeLists.txt OR EXISTS ${REPO_DIR}/${ARGS_CMAKE_PATH}/CMakeLists.txt)
        CGET_BUILD_CMAKE(${ARGV})
        set(CGET_${name}_BUILT 1)
    elseif (EXISTS ${REPO_DIR}/autogen.sh)
      CGET_EXECUTE_PROCESS(COMMAND ./autogen.sh ${ARGS_OPTIONS} WORKING_DIRECTORY ${REPO_DIR})
    endif ()
          
    foreach (config_variant configure config bootstrap makefile Makefile)
        if (NOT CGET_${name}_BUILT AND EXISTS ${REPO_DIR}/${config_variant})
            # Some config variants can't deal with spaces
            SET(TEMP_DIR "/tmp/cget/install_root")
            SET(TEMP_SRC_DIR "/tmp/cget/${name}")

            CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${TEMP_DIR}")
            if (EXISTS "${TEMP_SRC_DIR}")
                CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${TEMP_SRC_DIR}")
            endif ()
            FILE(MAKE_DIRECTORY ${TEMP_DIR})

            CGET_EXECUTE_PROCESS(COMMAND cp -R "${REPO_DIR}" "${TEMP_SRC_DIR}")

	    if(NOT "${config_variant}" STREQUAL "Makefile")
              CGET_EXECUTE_PROCESS(COMMAND ./${config_variant} --prefix=${TEMP_DIR} ${ARGS_OPTIONS} WORKING_DIRECTORY ${TEMP_SRC_DIR})
	    endif()	    
            CGET_EXECUTE_PROCESS(COMMAND make WORKING_DIRECTORY ${TEMP_SRC_DIR})

	    EXECUTE_PROCESS(COMMAND make install WORKING_DIRECTORY ${TEMP_SRC_DIR} RESULT_VARIABLE EXECUTE_RESULT ERROR_VARIABLE ERROR_RESULT)

	    if (EXECUTE_RESULT)
	      if(${EXECUTE_RESULT} STREQUAL "2") # no target
		message(WARNING "No install target exists; giving it a good guess")
		
		CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E
		  copy_directory "${TEMP_SRC_DIR}/" "${TEMP_DIR}")
		
	      else()
		message(FATAL_ERROR "Execute process '${ARGN}' failed with '${EXECUTE_RESULT}', result: ${RESULT_VARIABLE} ${ERROR_RESULT}")
	      endif()
	    endif ()

            CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E copy_directory "${TEMP_DIR}" "${INSTALL_DIR}")

            set(CGET_${name}_BUILT 1)
        endif ()
    endforeach ()

    if (NOT CGET_${name}_BUILT)
        message(FATAL_ERROR "Couldn't identify build system for ${name} in ${REPO_DIR}")
    endif ()

    CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "Config.cmake" "config.cmake")
    CGET_NORMALIZE_CMAKE_FILES("${BUILD_DIR}" "ConfigVersion.cmake" "config-version.cmake")
endfunction(CGET_FORCE_BUILD)


function(CGET_RESET_BUILD)
  #    CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${BUILD_DIR}")
  #    IF (DEFINED RELEASE_BUILD_DIR)
  #      CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${RELEASE_BUILD_DIR}")
  #    ENDIF ()
  file(WRITE "${INSTALL_DIR}/.installed" "")
  file(WRITE "${INSTALL_DIR}/.options" "")	
endfunction()

function(CGET_BUILD)
    CGET_PARSE_OPTIONS(${ARGV})
    CGET_FILE_CONTENTS("${INSTALL_DIR}/.installed" BUILD_CACHE_VAL)

    if (ARGS_SIMPLE_BUILD OR NOT BUILD_CACHE_VAL STREQUAL Build_Hash)
      CGET_MESSAGE(3 "Build out of date ${BUILD_CACHE_VAL} vs ${Build_Hash}")

      CGET_FORCE_BUILD(${ARGV})
      CGET_MESSAGE(3 "Update build file ${INSTALL_DIR}/.installed to ${Build_Hash}")

      IF(EXISTS "${INSTALL_DIR}")
	file(WRITE "${INSTALL_DIR}/.installed" "${Build_Hash}")
	file(WRITE "${INSTALL_DIR}/.options" "${BUILD_HASH_STRING}")
	file(WRITE "${INSTALL_DIR}/.repo_options" "${REPO_HASH_STRING}")
      ENDIF()
    endif ()    
endfunction()

macro(CGET_NO_VERSION_SPECIFIED_WARNING)
    if (NO_VERSION_SPECIFIED)
        EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD WORKING_DIRECTORY ${STAGING_DIR} OUTPUT_VARIABLE CURRENT_VERSION)
        STRING(STRIP "${CURRENT_VERSION}" CURRENT_VERSION)
        MESSAGE(AUTHOR_WARNING "No repo version specified for '${name}'. Add 'COMMIT_ID ${CURRENT_VERSION}' to use the current one.")
    endif ()
endmacro()

function(CGET_DIRECT_GET_PACKAGE name)
    CGET_PARSE_OPTIONS(${ARGV})
    CGET_MESSAGE(13 "CGET_DIRECT_GET_PACKAGE ${ARGV}")
    CGET_MESSAGE(1 "Getting ${name}...")

    set(GIT_SUBMODULE_OPTIONS "--recursive")
    if (ARGS_NOSUBMODULES)
        set(GIT_SUBMODULE_OPTIONS "")
    endif ()
    set(STAGING_DIR "${REPO_DIR}")

    if (NOT EXISTS ${STAGING_DIR})
        if (APPLE AND ARGS_BREW_PACKAGE)
            CGET_MESSAGE(3 "Using brew for ${name}")
        elseif ((MSVC OR MINGW) AND ARGS_NUGET_PACKAGE)
            CGET_MESSAGE(3 "Using nuget for ${name}")
          elseif (ARGS_GIT)
            FIND_PACKAGE(Git)
            CGET_MESSAGE(3 "Using git for ${name}")
            if (ARGS_COMMIT_ID)
                set(_GIT_OPTIONS -n)
            else ()
                set(_GIT_OPTIONS --progress --branch=${CHECKOUT_TAG} --depth=1)
            endif ()

            CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} clone ${ARGS_GIT} ${STAGING_DIR} ${_GIT_OPTIONS} ${GIT_SUBMODULE_OPTIONS})

            if (ARGS_COMMIT_ID)
                CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} checkout ${ARGS_COMMIT_ID}
                        WORKING_DIRECTORY ${STAGING_DIR} OUTPUT_QUIET ERROR_QUIET)
            endif ()

            CGET_NO_VERSION_SPECIFIED_WARNING()
        elseif (ARGS_URL)
            FILE(MAKE_DIRECTORY ${STAGING_DIR})
            GET_FILENAME_COMPONENT(file ${ARGS_URL} NAME)
            CGET_MESSAGE(2 "Downloading ${ARGS_URL} into ${CGET_PACKAGE_DIR}/${file}")
            file(DOWNLOAD ${ARGS_URL} ${CGET_PACKAGE_DIR}/${file})
            file(GLOB CURRENT_FILES LIST_DIRECTORIES true ${STAGING_DIR}/*)

            EXECUTE_PROCESS(
                    COMMAND ${CMAKE_COMMAND} -E tar xvf ${CGET_PACKAGE_DIR}/${file}
                    WORKING_DIRECTORY ${STAGING_DIR})

            file(GLOB NEW_FILES LIST_DIRECTORIES true ${STAGING_DIR}/*)
            list(REMOVE_ITEM NEW_FILES ${CURRENT_FILES} "")
            list(LENGTH NEW_FILES EXTRACTED_FOLDER_COUNT)
            cget_message(2 "${EXTRACTED_FOLDER_COUNT} ${NEW_FILES} ${CURRENT_FILES}")
            if (EXTRACTED_FOLDER_COUNT EQUAL 1)
                FILE(GLOB ALL_FILES LIST_DIRECTORIES true "${NEW_FILES}/*")
                cget_message(2 "${ALL_FILES}")
                FILE(COPY ${ALL_FILES} DESTINATION "${STAGING_DIR}")
            endif ()

        elseif (ARGS_HG)
            CGET_HAS_DEPENDENCY(Hg REGISTRY VERSION master ALLOW_SYSTEM)
        elseif (ARGS_SVN)
            CGET_HAS_DEPENDENCY(Subversion REGISTRY VERSION master ALLOW_SYSTEM)
        else ()
            message(FATAL_ERROR "Couldn't find way to get dependency ${name} at ${REPO_DIR}")
        endif ()
    elseif(ARGS_SUBMODULE AND NOT EXISTS "${SUBMODULE}/.git")
            CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} submodule update --init WORKING_DIRECTORY ${STAGING_DIR})
    else ()
        if (NO_VERSION_SPECIFIED AND CGET_RETRIEVE_MECHANISM MATCHES GIT)
            CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} log --oneline -n1 WORKING_DIRECTORY ${STAGING_DIR} OUTPUT_VARIABLE THIS_COMMIT)

            CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} reset --hard HEAD WORKING_DIRECTORY ${STAGING_DIR})

            CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} log --oneline -n1 WORKING_DIRECTORY ${STAGING_DIR} OUTPUT_VARIABLE NEW_COMMIT)

            CGET_NO_VERSION_SPECIFIED_WARNING()

            if (NOT THIS_COMMIT STREQUAL NEW_COMMIT)
              CGET_MESSAGE(2 "New revisions, reseting build.")
	      SET(NEW_VERSION_AVAILABLE ON)
	      CGET_RESET_BUILD()
            endif ()
        endif ()
    endif ()

endfunction()

function(CGET_GET_PACKAGE)
    CGET_MESSAGE(15 "CGET_GET_PACKAGE ${ARGV}")

    CGET_PARSE_OPTIONS(${ARGV})
    CGET_FILE_CONTENTS("${REPO_DIR}/.retrieved" REPO_CACHE_VAL)
    if (ARGS_SUBMODULE)
        #CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} submodule update --init ${REPO_DIR})
    elseif (NOT REPO_CACHE_VAL STREQUAL Repo_Hash)
        CGET_MESSAGE(3 "Repo out of date ${REPO_CACHE_VAL} vs ${Repo_Hash}")
        CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${REPO_DIR}")
        CGET_DIRECT_GET_PACKAGE(${ARGV})
        file(WRITE "${REPO_DIR}/.retrieved" "${Repo_Hash}")
      elseif (NO_VERSION_SPECIFIED)
        CGET_MESSAGE(3 "No version specified -- fetching latest")	
        CGET_DIRECT_GET_PACKAGE(${ARGV})
    ENDIF ()

    CGET_MESSAGE(15 "EXIT CGET_GET_PACKAGE ${ARGV}")
endfunction()

macro(CGET_FIND_DEPENDENCY NAME)
    if (ARGS_PROGRAM)
        find_program(${ARGV})
    elseif (ARGS_LIBRARY)
        string(TOUPPER ${NAME} UPPER_NAME)
        set(${UPPER_NAME}_LIBRARY "${UPPER_NAME}_LIBRARY-NOTFOUND")

        find_library(${UPPER_NAME}_LIBRARY ${ARGV} "PATHS ${CGET_${NAME}_INSTALL_DIR} ${CGET_${NAME}_INSTALL_DIR}/lib")
    else ()
      find_package(${ARGV})     
	
        IF (${${NAME}_FOUND})
            SET(CGET_DEPENDENCY_CONFIG "${CGET_DEPENDENCY_CONFIG}\nFIND_PACKAGE(${NAME} HINTS ${CGET_${NAME}_INSTALL_DIR})")
        ENDIF()
    endif ()
endmacro()

macro(CGET_HAS_DEPENDENCY name)
    LIST(APPEND CGET_CURRENT_CHAIN "${name}")
    CGET_MESSAGE(15 "CGET_HAS_DEPENDENCY ${ARGV}")
    CGET_PARSE_OPTIONS(${ARGV})

    CGET_MESSAGE(12 "Package ${name}(tag: '${CHECKOUT_TAG}') checkout to ${REPO_DIR}, building in ${BUILD_DIR}")
    if (ARGS_ALLOW_SYSTEM)
      CGET_FIND_DEPENDENCY(${ARGS_FINDNAME} ${ARGS_CMAKE_VERSION} COMPONENTS ${ARGS_COMPONENTS} QUIET ${ARGS_FIND_OPTIONS})
      IF (${${ARGS_FINDNAME}_FOUND})
        CGET_MESSAGE(1 "Found system ${name} ${ARGS_CMAKE_VERSION}")
      else()
	CGET_MESSAGE(1 "No system package for ${name} ${ARGS_FINDNAME} ${ARGS_CMAKE_VERSION}")
      ENDIF ()
    endif ()

    if(NOT "${${ARGS_FINDNAME}_FOUND}")
      
      # Check if there is already an installed dir with the correct hash.
      # if there is, we don't need to checkout the repo or attempt a build
      # on it. 
      CGET_FILE_CONTENTS("${INSTALL_DIR}/.installed" BUILD_CACHE_VAL)
      CGET_MESSAGE(15 "Build status ${BUILD_CACHE_VAL} vs ${Build_Hash}")
      if(NEW_VERSION_AVAILABLE OR ARGS_SIMPLE_BUILD OR NOT BUILD_CACHE_VAL STREQUAL Build_Hash)
	CGET_GET_PACKAGE(${ARGV})

	# The include.cmake just gets included and we don't try anything else
	# since specialized instructions exist in that file
	if (EXISTS "${REPO_DIR}/include.cmake")
          set(ARGS_NO_FIND_PACKAGE ON)
          CGET_MESSAGE(13 "Including ${REPO_DIR}/include.cmake")
          include("${REPO_DIR}/include.cmake")
	else()

          CGET_BUILD(${ARGV})
	endif ()
      endif ()
      CGET_REGISTER_INSTALL_DIR("${INSTALL_DIR}")

      if (NOT ARGS_NO_FIND_PACKAGE)
        CGET_MESSAGE(13 "Finding ${name} with ${ARGS_CMAKE_VERSION} ${ARGS_FIND_OPTIONS} in ${CMAKE_PREFIX_PATH} ${CMAKE_LIBRARY_PATH} ${CMAKE_INCLUDE_PATH}")
        CGET_FIND_DEPENDENCY(${ARGS_FINDNAME} ${ARGS_CMAKE_VERSION} REQUIRED ${ARGS_FIND_OPTIONS} COMPONENTS ${ARGS_COMPONENTS})

        IF (${${ARGS_FINDNAME}_FOUND})
          CGET_MESSAGE(2 "Found ${name} ${ARGS_CMAKE_VERSION}")
        ENDIF ()
      endif ()
      CGET_MESSAGE(15 "EXIT CGET_HAS_DEPENDENCY ${ARGV}")
    endif()
endmacro(CGET_HAS_DEPENDENCY) 
 
