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

macro(CGET_GET_CONFIG name var)
    EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config ${name} OUTPUT_VARIABLE ${var})
    if(${VAR})
        CGET_MESSAGE(2 "Using setting ${var} from git config: ${${var}}")
    endif()
    STRING(STRIP "${${var}}" ${var})
endmacro()

CGET_GET_CONFIG(cget.organizeAsSubModule CGET_ORGANIZE_AS_SUBMODULES)
CGET_GET_CONFIG(cget.useSSHForGithub CGET_USE_SSH_FOR_GITHUB)
CGET_GET_CONFIG(cget.mirror CGET_CONFIG_MIRROR)
CGET_GET_CONFIG(cget.sharedBinLocation CGET_SHARED_BIN_DIR)

if(DEFINED CMAKE_SCRIPT_MODE_FILE)
    SET(CGET_IS_SCRIPT_MODE ON)
endif()

if (NOT DEFINED CGET_VERBOSE_LEVEL)
    EXECUTE_PROCESS(COMMAND ${GIT_EXECUTABLE} config cget.verbose OUTPUT_VARIABLE CGET_VERBOSE_LEVEL)
endif ()

if (NOT DEFINED CGET_VERBOSE_LEVEL)
    set(CGET_VERBOSE_LEVEL 5)
endif ()

set(CGET_CORE_VERSION 0.1.5)

if (NOT DEFINED CGET_CORE_DIR)
    set(CGET_CORE_DIR "${CMAKE_SOURCE_DIR}/")
    set(CGET_IS_ROOT_DIR ON)

    CGET_ADD_CUSTOM_TARGET(cget-clean-packages COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_BIN_DIR}")
    CGET_ADD_CUSTOM_TARGET(cget-rebuild-packages COMMAND ${CMAKE_COMMAND} -E remove "${CGET_BIN_DIR}/packages/*/*/.built")
endif ()

FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_CORE_HASH)
FILE(MD5 ${CGET_CORE_DIR}/.cget/core.cmake CGET_PACKAGE_HASH)

if (NOT CGET_BIN_DIR)
    if(CGET_SHARED_BIN_DIR)
        SET(CGET_BIN_DIR "${CGET_SHARED_BIN_DIR}/")
    else()
        SET(CGET_BIN_DIR "${CMAKE_SOURCE_DIR}/.cget-bin/")
    endif()
    SET(CGET_TEMP_DIR "${CGET_BIN_DIR}temp")
    EXECUTE_PROCESS(COMMAND ${CMAKE_COMMAND} -E remove_directory "${CGET_TEMP_DIR}")
    FILE(MAKE_DIRECTORY "${CGET_TEMP_DIR}")
endif ()

if (NOT CGET_PACKAGE_DIR)
    SET(CGET_PACKAGE_DIR ${CGET_BIN_DIR}packages)
endif ()

if (CGET_ORGANIZE_AS_SUBMODULES AND NOT EXISTS "${CGET_CORE_DIR}/.cget/.added")
    EXECUTE_PROCESS(COMMAND git submodule add "${CGET_CORE_DIR}/.cget" WORKING_DIRECTORY ${CGET_CORE_DIR} OUTPUT_QUIET ERROR_QUIET )
    CGET_EXECUTE_PROCESS(COMMAND git add "${CGET_CORE_DIR}/.cget" WORKING_DIRECTORY ${CGET_CORE_DIR})
    EXECUTE_PROCESS(COMMAND git commit -m "Registered cget core" WORKING_DIRECTORY ${CGET_CORE_DIR} OUTPUT_QUIET ERROR_QUIET )
    FILE(WRITE "${CGET_CORE_DIR}/.cget/.added" "")
endif()

STRING(REPLACE " " "_" CGET_CMAKE_GENERATOR_NO_SPACES "${CMAKE_GENERATOR}")
SET(CGET_INSTALL_DIR ${CGET_BIN_DIR}install_root/${CGET_CMAKE_GENERATOR_NO_SPACES})
SET($ENV{PATH} "$ENV{PATH};${CGET_INSTALL_DIR}/bin")

if(CGET_ORGANIZE_AS_SUBMODULES AND NOT EXISTS ${CGET_PACKAGE_DIR}/.git)
    FILE(MAKE_DIRECTORY ${CGET_PACKAGE_DIR})
    CGET_EXECUTE_PROCESS(COMMAND git init WORKING_DIRECTORY ${CGET_PACKAGE_DIR})
endif()

set(CGET_BUILD_CONFIGS ${CMAKE_CONFIGURATION_TYPES})
if (NOT CGET_BUILD_CONFIGS)
    set(CGET_BUILD_CONFIGS ${CMAKE_BUILD_TYPE})
else ()
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

list(APPEND CMAKE_INSTALL_RPATH ${CMAKE_LIBRARY_PATH})

if (CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(CGET_ARCH "x64")
    set(CGET_ARCH_WIN_NAME "x64")
else ()
    set(CGET_ARCH "x86")
    set(CGET_ARCH_WIN_NAME "Win32")
endif ()
