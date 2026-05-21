# ------------------------------------------------------------
# CUPDataModel top-level CMakeLists.txt
# Provides offline data-reading libraries for CUPDAQ raw data:
# - RawObjs   : ROOT-based raw event/channel objects
# - HDF5Utils : HDF5-based event I/O utilities (optional)
# ------------------------------------------------------------
cmake_minimum_required ( VERSION 3.16 )
project ( CUPDataModel VERSION 1.0.0 LANGUAGES CXX )

set ( CMAKE_EXPORT_COMPILE_COMMANDS ON )

# ---- C++ Standard ----
set ( CMAKE_CXX_STANDARD 17 )
set ( CMAKE_CXX_STANDARD_REQUIRED ON )
set ( CMAKE_CXX_EXTENSIONS OFF )

include ( GNUInstallDirs )

option ( CUPDM_AUTO_INSTALL_DEPENDENCIES "Automatically install missing system dependencies when running as root" ON )

# Platform detection, privilege detection, and auto-install helpers
include ( cmake/CUPDMHelpers.cmake )

# ---- Install Prefix ----
# When running as root with no explicit prefix, install into ROOT's system search path
if ( CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT )
  if ( CUPDM_IS_ROOT )
    set ( CMAKE_INSTALL_PREFIX "/usr" CACHE PATH "Install path prefix" FORCE )
    set ( CMAKE_INSTALL_LIBDIR "lib64/root" CACHE PATH "Library install directory" FORCE )
    message ( STATUS "Running as root: defaulting install prefix to /usr (libs → /usr/lib64/root)" )
  else ()
    message ( STATUS "CMAKE_INSTALL_PREFIX not specified; defaulting to ${CMAKE_INSTALL_PREFIX}" )
  endif ()
else ()
  message ( STATUS "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}" )
endif ()

# ---- ROOT ----
cupdm_try_find_root ()
# Expose ROOT headers globally so rootcling can locate them in subdirectories
include_directories ( ${ROOT_INCLUDE_DIRS} )

# ---- Relocatable RPATH Settings (Linux) ----
set ( CMAKE_SKIP_BUILD_RPATH FALSE )
set ( CMAKE_BUILD_WITH_INSTALL_RPATH FALSE )
set ( CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE )
set ( CMAKE_INSTALL_RPATH "$ORIGIN/../${CMAKE_INSTALL_LIBDIR}" )

# ---- Global Compiler Settings ----
add_compile_options ( -O2 )

# ---- HDF5 (optional) ----
option ( CUPDM_ENABLE_HDF5 "Enable HDF5-based utilities" ON )

if ( CUPDM_ENABLE_HDF5 )
  find_package ( HDF5 QUIET COMPONENTS C )

  if ( NOT HDF5_FOUND AND CUPDM_AUTO_INSTALL_DEPENDENCIES AND CUPDM_IS_ROOT )
    if ( CUPDM_DNF_EXECUTABLE )
      cupdm_install_system_packages ( "hdf5" "hdf5-devel" )
    elseif ( CUPDM_IS_UBUNTU AND CUPDM_DEBIAN_PKG_EXECUTABLE )
      cupdm_install_system_packages ( "libhdf5-dev" )
    else ()
      message ( WARNING "Unsupported platform for HDF5 auto-install. Only RedHat (dnf) and Ubuntu (apt) are supported." )
    endif ()
    find_package ( HDF5 QUIET COMPONENTS C )
  endif ()

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

# cmake config goes to lib64/cmake/ (not lib64/root/cmake/) so find_package works
string ( REGEX REPLACE "/.*$" "" _cupdm_libbase "${CMAKE_INSTALL_LIBDIR}" )
set ( CUPDM_CMAKE_PACKAGE_DIR "${_cupdm_libbase}/cmake/CUPDataModel" )

configure_package_config_file (
    cmake/CUPDataModelConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfig.cmake
    INSTALL_DESTINATION ${CUPDM_CMAKE_PACKAGE_DIR}
)

write_basic_package_version_file (
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install ( EXPORT CUPDataModelTargets
    NAMESPACE CUPDataModel::
    DESTINATION ${CUPDM_CMAKE_PACKAGE_DIR}
)

install ( FILES
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/CUPDataModelConfigVersion.cmake
    DESTINATION ${CUPDM_CMAKE_PACKAGE_DIR}
)

# ---- Run ldconfig after installing to a system path ----
install ( CODE "
  if (UNIX AND NOT APPLE)
    if (CMAKE_INSTALL_PREFIX MATCHES \"^(/usr|/usr/local)(/.*)?$\")
      message(STATUS \"Running ldconfig...\")
      execute_process(COMMAND ldconfig)
    endif()
  endif()
")

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
