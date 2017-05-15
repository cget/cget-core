cmake_policy(SET CMP0011 NEW)
cmake_policy(SET CMP0012 NEW)

find_program(Git_EXECUTABLE git HINTS
        "C:/Program Files (x86)/SmartGitHg/git/bin"
        "C:/Program Files (x86)/SmartGit/git/bin"
        "C:/Program Files/SmartGitHg/git/bin"
        "C:/Program Files/SmartGit/git/bin"
        "C:/Program Files (x86)/Git/bin"
        "C:/Program Files/Git/bin")
find_package(Git)

if (NOT GIT_FOUND)
    message(FATAL_ERROR "Git is required in the path. If you have git or a tool that uses git installed, please file an issue with your path to git so it could be added to the default list to check.")
endif ()

macro(CGET_GET_CONFIG name var default datatype desc)
	if(NOT DEFINED ${var})
		EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config ${name} OUTPUT_VARIABLE ${var})
		if(NOT "${${var}}" STREQUAL "")
            CGET_MESSAGE(2 "Using setting ${var} from git config: ${${var}}")
		else()
			SET(${var} "${default}")			
		endif()
		STRING(STRIP "${${var}}" ${var})
		SET(${var} "${${var}}" CACHE ${datatype} "${desc}" FORCE)
	endif()
    CGET_MESSAGE(2 "Checking setting ${name} ${var} from git config: ${${var}}")
endmacro()

SET(CGET_CONFIG_SHARED_BIN_DIR_DEFAULT "OFF")
IF(DEFINED ENV{HOME})
	SET(CGET_CONFIG_SHARED_BIN_DIR_DEFAULT "$ENV{HOME}/.cget-bin")
ELSEIF(DEFINED ENV{USERPROFILE})	
	STRING(REPLACE "\\" "/" CGET_CONFIG_SHARED_BIN_DIR_DEFAULT "$ENV{USERPROFILE}/.cget-bin")
ENDIF()

CGET_GET_CONFIG(cget.organizeAsSubModule CGET_CONFIG_ORGANIZE_AS_SUBMODULES ON BOOL "Organize packages as submodules")
CGET_GET_CONFIG(cget.useSSHForGithub CGET_CONFIG_USE_SSH_FOR_GITHUB OFF BOOL "Setup github packages for ssh acces")
CGET_GET_CONFIG(cget.mirror CGET_CONFIG_MIRROR "" PATH "")
CGET_GET_CONFIG(cget.sharedBinLocation CGET_CONFIG_SHARED_BIN_DIR "${CGET_CONFIG_SHARED_BIN_DIR_DEFAULT}" PATH "Use given directory to store all projects .cget-bin")
CGET_GET_CONFIG(cget.verbose CGET_CONFIG_VERBOSE_LEVEL "5" STRING "Verbosity 0-100. Higher emits more messages")
CGET_GET_CONFIG(cget.forceFullRebuild CGET_CONFIG_FORCE_FULL_REBUILD "TRUE" BOOL "Set to false to allow partial rebuilds")

if(DEFINED CMAKE_SCRIPT_MODE_FILE)
    SET(CGET_IS_SCRIPT_MODE ON)
endif()

SET(CGET_MAJOR_VERSION 0)
SET(CGET_MINOR_VERSION 1)
SET(CGET_PATCH_VERSION 5)
SET(CGET_CORE_VERSION "${CGET_MAJOR_VERSION}.${CGET_MINOR_VERSION}.${CGET_PATCH_VERSION}")

if(NOT TARGET cget-clean-packages)
    CGET_ADD_CUSTOM_TARGET(cget-clean-packages COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_BIN_DIR}")
    CGET_ADD_CUSTOM_TARGET(cget-rebuild-packages COMMAND ${CMAKE_COMMAND} -E remove "${CGET_BIN_DIR}/packages/*/*/.built")
endif ()

FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_CORE_HASH)
FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_PACKAGE_HASH)

if (NOT CGET_BIN_DIR)
    if(CGET_CONFIG_SHARED_BIN_DIR)
        SET(CGET_BIN_DIR "${CGET_CONFIG_SHARED_BIN_DIR}/${CGET_MAJOR_VERSION}.${CGET_MINOR_VERSION}/")
    else()
        SET(CGET_BIN_DIR "${CMAKE_SOURCE_DIR}/.cget-bin/${CGET_MAJOR_VERSION}.${CGET_MINOR_VERSION}/")
    endif()
    SET(CGET_TEMP_DIR "${CGET_BIN_DIR}temp")
    EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_TEMP_DIR}")
    FILE(MAKE_DIRECTORY "${CGET_TEMP_DIR}")
endif ()

if (NOT CGET_PACKAGE_DIR)
    SET(CGET_PACKAGE_DIR ${CGET_BIN_DIR}packages)
endif ()

STRING(REPLACE " " "_" CGET_CMAKE_GENERATOR_NO_SPACES "${CMAKE_GENERATOR}")
SET(CGET_INSTALL_DIR ${CGET_BIN_DIR}install_root/${CGET_CMAKE_GENERATOR_NO_SPACES})
SET($ENV{PATH} "$ENV{PATH};${CGET_INSTALL_DIR}/bin")

if(CGET_CONFIG_ORGANIZE_AS_SUBMODULES AND NOT EXISTS ${CGET_PACKAGE_DIR}/.git)
    FILE(MAKE_DIRECTORY ${CGET_PACKAGE_DIR})
    CGET_EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} init WORKING_DIRECTORY ${CGET_PACKAGE_DIR})
endif()

if (NOT "${CMAKE_CONFIGURATION_TYPES}")
  set(CGET_BUILD_CONFIGS ${CMAKE_BUILD_TYPE})
  
  if (NOT CGET_BUILD_CONFIGS)
    set(CMAKE_BUILD_TYPE "Debug")
    set(CGET_BUILD_CONFIGS "Debug")
  endif ()
else()
    set(CGET_BUILD_CONFIGS "Debug;Release")
endif ()

set(CGET_VERBOSE_SUFFIX OFF)

IF (CGET_VERBOSE_SUFFIX)
    SET(OLD_SUFFIX "${CMAKE_FIND_LIBRARY_SUFFIXES}")
    SET(CMAKE_FIND_LIBRARY_SUFFIXES)
    foreach (suffix ${OLD_SUFFIX})
        foreach (configuration ${CGET_BUILD_CONFIGS})
            list(APPEND CMAKE_FIND_LIBRARY_SUFFIXES "_${configuration}${suffix}")
        endforeach ()
    endforeach ()
    CGET_MESSAGE(3 "${OLD_SUFFIX} vs ${CMAKE_FIND_LIBRARY_SUFFIXES}")
ELSE ()
    set(CMAKE_DEBUG_POSTFIX "d")
ENDIF ()

set(CMAKE_FIND_ROOT_PATH ${CGET_INSTALL_DIR})
FILE(MAKE_DIRECTORY ${CGET_INSTALL_DIR}/lib/cmake)
list(APPEND CMAKE_PREFIX_PATH ${CGET_INSTALL_DIR} ${CGET_INSTALL_DIR}/lib/cmake)
list(APPEND CMAKE_MODULE_PATH ${CGET_INSTALL_DIR}/lib/cmake)
set(CMAKE_LIBRARY_PATH ${CGET_INSTALL_DIR}/lib)
set(CMAKE_INCLUDE_PATH ${CGET_INSTALL_DIR}/include)

list(APPEND CMAKE_INSTALL_RPATH ${CMAKE_LIBRARY_PATH})

if (CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(CGET_ARCH "x64")
    set(CGET_ARCH_WIN_NAME "x64")
else ()
    set(CGET_ARCH "x86")
    set(CGET_ARCH_WIN_NAME "Win32")
endif ()
