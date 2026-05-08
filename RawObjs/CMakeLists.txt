set ( MODULE_NAME RawObjs )
message ( STATUS "Configuring ${MODULE_NAME} ..." )

file ( GLOB MODULE_HEADERS CONFIGURE_DEPENDS inc/*.hh )
file ( GLOB MODULE_SOURCES CONFIGURE_DEPENDS src/*.cc )

file ( COPY ${CMAKE_CURRENT_SOURCE_DIR}/inc/
     DESTINATION ${CUPDM_HEADER_OUTPUT_PATH}
     FILES_MATCHING PATTERN "*.hh" )
file ( COPY ${CMAKE_CURRENT_SOURCE_DIR}/inc/LinkDef.h
     DESTINATION ${CUPDM_HEADER_OUTPUT_PATH}/${MODULE_NAME} )

set ( DICT_I_FLAGS -I${CUPDM_HEADER_OUTPUT_PATH} -I${ROOT_INCLUDE_DIRS} )

set ( DICT_HEADERS "" )
foreach ( _h ${MODULE_HEADERS} )
    get_filename_component ( _n ${_h} NAME )
    list ( APPEND DICT_HEADERS ${CUPDM_HEADER_OUTPUT_PATH}/${_n} )
endforeach ()

ROOT_GENERATE_DICTIONARY ( G__${MODULE_NAME}
    ${DICT_HEADERS}
    LINKDEF ${CUPDM_HEADER_OUTPUT_PATH}/${MODULE_NAME}/LinkDef.h
    OPTIONS ${DICT_I_FLAGS} -Wno-inconsistent-missing-override
)

add_library ( ${MODULE_NAME} SHARED
    ${MODULE_SOURCES}
    G__${MODULE_NAME}.cxx
)

target_include_directories ( ${MODULE_NAME}
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/inc>
        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

target_link_libraries ( ${MODULE_NAME}
    PUBLIC
        ROOT::Core
        ROOT::RIO
)

set ( _INSTALL_HDRS "" )
foreach ( _h ${MODULE_HEADERS} )
    get_filename_component ( _n ${_h} NAME )
    list ( APPEND _INSTALL_HDRS ${_n} )
endforeach ()

# ---- Install ----
install ( TARGETS ${MODULE_NAME}
    EXPORT  CUPDataModelTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install ( DIRECTORY inc/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.hh"
)
install ( CODE "
    set ( _libdir \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}\" )
    set ( _incdir \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_INCLUDEDIR}\" )
    set ( _headers \"\" )
    foreach ( _n ${_INSTALL_HDRS} )
        list ( APPEND _headers \"\${_incdir}/\${_n}\" )
    endforeach ()
    message ( STATUS \"[CUPDataModel] Regenerating PCM for ${MODULE_NAME}\" )
    execute_process (
        COMMAND \"${ROOT_BINDIR}/rootcling\"
            -f \"\${_libdir}/G__${MODULE_NAME}_tmp.cxx\"
            -s \"\${_libdir}/lib${MODULE_NAME}.so\"
            -rml \"lib${MODULE_NAME}.so\"
            -rmf \"\${_libdir}/lib${MODULE_NAME}.rootmap\"
            -I\"\${_incdir}\"
            -Wno-inconsistent-missing-override
            \${_headers}
            \"${CMAKE_CURRENT_SOURCE_DIR}/inc/LinkDef.h\"
        RESULT_VARIABLE _rc
        ERROR_VARIABLE _err
    )
    file ( REMOVE \"\${_libdir}/G__${MODULE_NAME}_tmp.cxx\" )
    if ( _rc )
        message ( WARNING \"[CUPDataModel] PCM regeneration failed for ${MODULE_NAME}: \${_err}\" )
    endif ()
" )

add_subdirectory ( test )
