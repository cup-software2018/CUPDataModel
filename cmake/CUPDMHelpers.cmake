# ------------------------------------------------------------
# CUPDMHelpers.cmake
# Platform detection, privilege detection, and auto-install helpers.
# Included by the top-level CMakeLists.txt; sets the following variables:
#   CUPDM_IS_ROOT, CUPDM_IS_UBUNTU, CUPDM_OS_ID
#   CUPDM_BASH/APT/DNF/YUM/SNAP_EXECUTABLE, CUPDM_DEBIAN_PKG_EXECUTABLE
# Defines functions:
#   cupdm_install_system_packages(<pkg>...)
#   cupdm_install_system_packages_snap(<pkg>...)
#   cupdm_try_find_root()
# ------------------------------------------------------------

find_program ( CUPDM_BASH_EXECUTABLE bash )
find_program ( CUPDM_APT_EXECUTABLE apt )
find_program ( CUPDM_APT_GET_EXECUTABLE apt-get )
find_program ( CUPDM_DNF_EXECUTABLE dnf )
find_program ( CUPDM_YUM_EXECUTABLE yum )
find_program ( CUPDM_SNAP_EXECUTABLE snap )

# ---- OS / distro detection ----
if ( EXISTS "/etc/os-release" )
  file ( READ "/etc/os-release" _cupdm_os_release )
  string ( REGEX MATCH "^ID=(.+)$" _cupdm_os_id_line "${_cupdm_os_release}" )
  if ( _cupdm_os_id_line )
    string ( REGEX REPLACE "^ID=(.+)$" "\\1" CUPDM_OS_ID "${_cupdm_os_id_line}" )
    string ( STRIP "${CUPDM_OS_ID}" CUPDM_OS_ID )
    string ( REPLACE "\"" "" CUPDM_OS_ID "${CUPDM_OS_ID}" )
  else ()
    set ( CUPDM_OS_ID "" )
  endif ()
else ()
  set ( CUPDM_OS_ID "" )
endif ()

if ( CUPDM_APT_EXECUTABLE )
  set ( CUPDM_DEBIAN_PKG_EXECUTABLE ${CUPDM_APT_EXECUTABLE} )
elseif ( CUPDM_APT_GET_EXECUTABLE )
  set ( CUPDM_DEBIAN_PKG_EXECUTABLE ${CUPDM_APT_GET_EXECUTABLE} )
else ()
  set ( CUPDM_DEBIAN_PKG_EXECUTABLE "" )
endif ()

if ( CUPDM_OS_ID STREQUAL "ubuntu" )
  set ( CUPDM_IS_UBUNTU TRUE )
else ()
  set ( CUPDM_IS_UBUNTU FALSE )
endif ()

# ---- Privilege detection ----
if ( UNIX AND NOT APPLE )
  execute_process ( COMMAND id -u OUTPUT_VARIABLE _CUPDM_UID OUTPUT_STRIP_TRAILING_WHITESPACE )
  if ( _CUPDM_UID STREQUAL "0" )
    set ( CUPDM_IS_ROOT TRUE )
  else ()
    set ( CUPDM_IS_ROOT FALSE )
  endif ()
else ()
  set ( CUPDM_IS_ROOT FALSE )
endif ()

# ---- Auto-install helpers ----

function ( cupdm_install_system_packages )
  set ( _pkg_list ${ARGN} )
  list ( JOIN _pkg_list " " _pkg_str )

  if ( NOT CUPDM_IS_ROOT )
    message ( WARNING "CUPDataModel is not running as root; cannot auto-install system packages." )
    return ()
  endif ()

  if ( CUPDM_IS_UBUNTU AND CUPDM_DEBIAN_PKG_EXECUTABLE )
    if ( NOT CUPDM_BASH_EXECUTABLE )
      message ( WARNING "bash not found; cannot execute apt install helper." )
      return ()
    endif ()
    message ( STATUS "Attempting to install system packages with ${CUPDM_DEBIAN_PKG_EXECUTABLE}: ${_pkg_str}" )
    execute_process (
      COMMAND ${CUPDM_BASH_EXECUTABLE} -lc
        "DEBIAN_FRONTEND=noninteractive ${CUPDM_DEBIAN_PKG_EXECUTABLE} update -y && DEBIAN_FRONTEND=noninteractive ${CUPDM_DEBIAN_PKG_EXECUTABLE} install -y ${_pkg_str}"
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _output
      ERROR_VARIABLE  _error
    )
    if ( NOT _result EQUAL 0 )
      message ( WARNING "${CUPDM_DEBIAN_PKG_EXECUTABLE} install failed: ${_error}" )
    endif ()
    return ()
  endif ()

  if ( CUPDM_DNF_EXECUTABLE OR CUPDM_YUM_EXECUTABLE )
    if ( CUPDM_DNF_EXECUTABLE )
      set ( _pkg_manager ${CUPDM_DNF_EXECUTABLE} )
    else ()
      set ( _pkg_manager ${CUPDM_YUM_EXECUTABLE} )
    endif ()
    message ( STATUS "Attempting to install system packages with ${_pkg_manager}: ${_pkg_str}" )
    execute_process (
      COMMAND ${_pkg_manager} install -y ${_pkg_list}
      RESULT_VARIABLE _result
      OUTPUT_VARIABLE _output
      ERROR_VARIABLE  _error
    )
    if ( NOT _result EQUAL 0 )
      message ( WARNING "${_pkg_manager} install failed: ${_error}" )
    endif ()
    return ()
  endif ()

  message ( WARNING "No supported package manager found for auto-installation." )
endfunction ()

function ( cupdm_install_system_packages_snap )
  set ( _pkg_list ${ARGN} )
  list ( JOIN _pkg_list " " _pkg_str )

  if ( NOT CUPDM_IS_ROOT )
    message ( WARNING "CUPDataModel is not running as root; cannot auto-install snap packages." )
    return ()
  endif ()

  if ( NOT CUPDM_SNAP_EXECUTABLE )
    message ( WARNING "snap not found; cannot install snap packages." )
    return ()
  endif ()

  message ( STATUS "Attempting to install snap packages with snap: ${_pkg_str}" )
  execute_process (
    COMMAND ${CUPDM_SNAP_EXECUTABLE} install ${_pkg_str} --classic
    RESULT_VARIABLE _result
    OUTPUT_VARIABLE _output
    ERROR_VARIABLE  _error
  )
  if ( NOT _result EQUAL 0 )
    message ( WARNING "snap install failed: ${_error}" )
  endif ()
endfunction ()

function ( cupdm_try_find_root )
  # Quiet probe only when auto-install might run, to avoid a double "Found ROOT" message
  if ( CUPDM_AUTO_INSTALL_DEPENDENCIES AND CUPDM_IS_ROOT )
    find_package ( ROOT QUIET COMPONENTS Core RIO Hist )

    if ( NOT ROOT_FOUND )
      if ( CUPDM_IS_UBUNTU AND CUPDM_SNAP_EXECUTABLE )
        cupdm_install_system_packages_snap ( "root" )
      elseif ( CUPDM_DNF_EXECUTABLE )
        cupdm_install_system_packages ( "root-*" )
      else ()
        message ( WARNING "Unsupported platform for ROOT auto-install. Only RedHat (dnf) and Ubuntu (snap) are supported." )
      endif ()
    endif ()

    # Clear cached state so the final find_package always runs fresh and prints its message
    unset ( ROOT_FOUND )
    unset ( ROOT_DIR CACHE )
  endif ()

  find_package ( ROOT REQUIRED COMPONENTS Core RIO Hist )
  message ( STATUS "Found ROOT ${ROOT_VERSION}: ${ROOT_DIR}" )
endfunction ()
