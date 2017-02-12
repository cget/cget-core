
macro(CGET_MSVC_SLN_BUILD sln_file)	
	CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_MAKE_PROGRAM} /property:Configuration=Release /property:Platform=${CGET_ARCH_WIN_NAME} "${REPO_DIR}/${sln_file}")
	CGET_EXECUTE_PROCESS(COMMAND ${CMAKE_MAKE_PROGRAM} /property:Configuration=Debug /property:Platform=${CGET_ARCH_WIN_NAME} "${REPO_DIR}/${sln_file}")
	
	if(ARGS_SOLUTION_OUTPUT_DIR)
		CGET_GET_LIBS_FROM_DIR("${REPO_DIR}/${ARGS_SOLUTION_OUTPUT_DIR}" "")
	endif()
	 
	foreach (DIR ${ARGS_SOLUTION_INC_DIRS})
		  file(COPY "${REPO_DIR}/${DIR}" DESTINATION "${CGET_INSTALL_DIR}/")		
    endforeach ()
endmacro()