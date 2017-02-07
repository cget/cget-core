function(CGET_GET_CONFIG name var)
  EXECUTE_PROCESS(COMMAND git config ${name} OUTPUT_VARIABLE ${var})
  STRING(STRIP "${${var}}" ${var})
  CGET_MESSAGE(3 "Configuration ${var}: ${${var}}")
endfunction()

CGET_GET_CONFIG(cget.organizeAsSubModule CGET_ORGANIZE_AS_SUBMODULES)
CGET_GET_CONFIG(cget.useSSHForGithub CGET_USE_SSH_FOR_GITHUB)
CGET_GET_CONFIG(cget.mirror CGET_CONFIG_MIRROR)
CGET_GET_CONFIG(cget.sharedBinLocation CGET_BIN_DIR)

if(DEFINED CMAKE_SCRIPT_MODE_FILE)
  SET(CGET_IS_SCRIPT_MODE ON)
endif()

if (NOT DEFINED CGET_VERBOSE_LEVEL)
  EXECUTE_PROCESS(COMMAND git config cget.verbose OUTPUT_VARIABLE CGET_VERBOSE_LEVEL)
endif()

if (NOT DEFINED CGET_VERBOSE_LEVEL)
  set(CGET_VERBOSE_LEVEL 5)
endif()
