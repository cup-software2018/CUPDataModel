set ( MODULE_NAME HDF5Utils )
message ( STATUS "Configuring ${MODULE_NAME} ..." )

file ( GLOB MODULE_HEADERS CONFIGURE_DEPENDS inc/*.hh )
file ( GLOB MODULE_SOURCES CONFIGURE_DEPENDS src/*.cc )

# Allow ROOT_GENERATE_DICTIONARY to locate headers by filename
include_directories ( ${CMAKE_CURRENT_SOURCE_DIR}/inc ${HDF5_INCLUDE_DIRS} )

# Pass filenames only — rootcling embeds #include "*.hh" (no absolute path) in PCM/rootmap
set ( DICT_HEADERS "" )
foreach ( _h ${MODULE_HEADERS} )
    get_filename_component ( _n ${_h} NAME )
    list ( APPEND DICT_HEADERS ${_n} )
endforeach ()

ROOT_GENERATE_DICTIONARY ( G__${MODULE_NAME}
    ${DICT_HEADERS}
    LINKDEF ${CMAKE_CURRENT_SOURCE_DIR}/inc/LinkDef.h
    OPTIONS
        -I${CMAKE_CURRENT_SOURCE_DIR}/inc
        -I${HDF5_INCLUDE_DIRS}
        -Wno-inconsistent-missing-override
    NOINSTALL
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
        hdf5::hdf5
        hdf5::hdf5_cpp
)

# ---- Install ----
install ( TARGETS ${MODULE_NAME}
    EXPORT  CUPDataModelTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
install ( DIRECTORY inc/
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    FILES_MATCHING PATTERN "*.hh"
)
# PCM/rootmap have relative includes — safe to copy from build tree directly
install ( FILES
    ${CMAKE_CURRENT_BINARY_DIR}/lib${MODULE_NAME}_rdict.pcm
    ${CMAKE_CURRENT_BINARY_DIR}/lib${MODULE_NAME}.rootmap
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

add_subdirectory ( test )
