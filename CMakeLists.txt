# ------------------------------------------------------------
# CUPDataModel top-level CMakeLists.txt
# Provides offline data-reading libraries for CUPDAQ raw data:
#   - RawObjs   : ROOT-based raw event/channel objects
#   - HDF5Utils : HDF5-based event I/O utilities (optional)
# ------------------------------------------------------------
cmake_minimum_required ( VERSION 3.16 )
project ( CUPDataModel VERSION 1.0.0 LANGUAGES CXX )

set ( CMAKE_EXPORT_COMPILE_COMMANDS ON )

# ---- C++ Standard ----
set ( CMAKE_CXX_STANDARD 17 )
set ( CMAKE_CXX_STANDARD_REQUIRED ON )
set ( CMAKE_CXX_EXTENSIONS OFF )

include ( GNUInstallDirs )

# ---- Relocatable RPATH Settings (Linux) ----
set ( CMAKE_SKIP_BUILD_RPATH FALSE )
set ( CMAKE_BUILD_WITH_INSTALL_RPATH FALSE )
set ( CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE )
set ( CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}" )

# ---- ROOT ----
find_package ( ROOT REQUIRED COMPONENTS Core RIO )
include ( ${ROOT_USE_FILE} )

# ---- Global Compiler Settings ----
add_compile_options ( -O2 )

# ---- HDF5 (optional) ----
option ( CUPDM_ENABLE_HDF5 "Enable HDF5-based utilities" ON )

if ( CUPDM_ENABLE_HDF5 )
  find_package ( HDF5 QUIET COMPONENTS C CXX HL )

  if ( HDF5_FOUND )
    message ( STATUS "HDF5 found (${HDF5_VERSION}): enabling HDF5Utils module" )
    add_compile_definitions ( ENABLE_HDF5 )
    add_subdirectory ( HDF5Utils )
  else ()
    message ( STATUS "HDF5 not found: skipping HDF5Utils module" )
    set ( CUPDM_ENABLE_HDF5 OFF CACHE BOOL "Enable HDF5-based utilities" FORCE )
  endif ()
else ()
  message ( STATUS "HDF5 disabled" )
endif ()

# ---- Submodules ----
add_subdirectory ( RawObjs )

# ---- CMake Package Config ----
include ( CMakePackageConfigHelpers )

configure_package_config_file (
    cmake/CUPDataModelConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUPDataModel
)

write_basic_package_version_file (
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install ( EXPORT CUPDataModelTargets
    NAMESPACE   CUPDataModel::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUPDataModel
)

install ( FILES
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/CUPDataModel
)

# ---- Environment Setup Script ----
file ( WRITE ${CMAKE_BINARY_DIR}/setup_cupdm.sh
  "#!/bin/bash
# CUPDataModel Environment Setup Script
# Generated automatically by CMake.

export CUPDM_DIR=\"\$(builtin cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"

export LD_LIBRARY_PATH=\"\$CUPDM_DIR/${CMAKE_INSTALL_LIBDIR}:\$LD_LIBRARY_PATH\"
export ROOT_INCLUDE_PATH=\"\$CUPDM_DIR/include:\$ROOT_INCLUDE_PATH\"
export CMAKE_PREFIX_PATH=\"\$CUPDM_DIR:\$CMAKE_PREFIX_PATH\"

echo \"[CUPDataModel] Environment loaded from: \$CUPDM_DIR\"
" )

install ( FILES ${CMAKE_BINARY_DIR}/setup_cupdm.sh DESTINATION . )
