cmake_minimum_required(VERSION 3.23)
project(pyjags_console LANGUAGES CXX)

include(GNUInstallDirs)

find_package(Python COMPONENTS Interpreter Development.Module NumPy REQUIRED)
find_package(pybind11 CONFIG REQUIRED)
find_package(PkgConfig REQUIRED)

option(PYJAGS_VENDOR_JAGS "Bundle a JAGS runtime inside the wheel" ON)
set(PYJAGS_VENDOR_JAGS_ROOT "" CACHE PATH "Use this JAGS installation instead of pkg-config discovery when bundling")

pkg_check_modules(JAGS REQUIRED IMPORTED_TARGET jags)
pkg_get_variable(JAGS_PREFIX jags prefix)
pkg_get_variable(JAGS_LIBDIR jags libdir)
pkg_get_variable(JAGS_INCLUDEDIR jags includedir)
pkg_get_variable(JAGS_MODULEDIR jags moduledir)

set(JAGS_VERSION_MAJOR "")
if(JAGS_VERSION)
  string(REGEX MATCH "^[0-9]+" JAGS_VERSION_MAJOR "${JAGS_VERSION}")
endif()

if(NOT JAGS_INCLUDEDIR)
  set(JAGS_INCLUDEDIR "${JAGS_PREFIX}/include")
endif()

if(NOT JAGS_LIBDIR)
  set(JAGS_LIBDIR "${JAGS_PREFIX}/lib")
endif()

set(JAGS_RUNTIME_LIBDIR "")
set(JAGS_RUNTIME_MODULEDIR "")

set(_jags_runtime_lib_candidates "")
set(_jags_runtime_module_candidates "")

if(PYJAGS_VENDOR_JAGS_ROOT)
  list(APPEND _jags_runtime_lib_candidates "${PYJAGS_VENDOR_JAGS_ROOT}/lib")
  if(JAGS_VERSION_MAJOR)
    list(APPEND _jags_runtime_module_candidates "${PYJAGS_VENDOR_JAGS_ROOT}/lib/JAGS/modules-${JAGS_VERSION_MAJOR}")
  endif()
endif()

if(JAGS_LIBDIR)
  list(APPEND _jags_runtime_lib_candidates "${JAGS_LIBDIR}")
endif()

if(JAGS_PREFIX)
  list(APPEND _jags_runtime_lib_candidates "${JAGS_PREFIX}/lib")
  if(JAGS_VERSION_MAJOR)
    list(APPEND _jags_runtime_module_candidates "${JAGS_PREFIX}/lib/JAGS/modules-${JAGS_VERSION_MAJOR}")
  endif()
endif()

if(JAGS_MODULEDIR)
  list(APPEND _jags_runtime_module_candidates "${JAGS_MODULEDIR}")
endif()

foreach(_candidate IN LISTS _jags_runtime_lib_candidates)
  if(NOT _candidate)
    continue()
  endif()
  if(NOT IS_ABSOLUTE "${_candidate}")
    file(REAL_PATH "${_candidate}" _candidate)
  endif()
  if(EXISTS "${_candidate}")
    set(JAGS_RUNTIME_LIBDIR "${_candidate}")
    break()
  endif()
endforeach()

foreach(_candidate IN LISTS _jags_runtime_module_candidates)
  if(NOT _candidate)
    continue()
  endif()
  if(NOT IS_ABSOLUTE "${_candidate}")
    file(REAL_PATH "${_candidate}" _candidate)
  endif()
  if(EXISTS "${_candidate}")
    set(JAGS_RUNTIME_MODULEDIR "${_candidate}")
    break()
  endif()
endforeach()

set(CONSOLE_SRC "${PROJECT_SOURCE_DIR}/pyjags/console.cc")
if(NOT EXISTS "${CONSOLE_SRC}")
  message(FATAL_ERROR "Expected source not found: ${CONSOLE_SRC}")
endif()

pybind11_add_module(console MODULE "${CONSOLE_SRC}")

set_target_properties(console PROPERTIES
  PREFIX ""
)

target_compile_features(console PRIVATE cxx_std_14)
if(MSVC)
  target_compile_options(console PRIVATE /W3)
else()
  target_compile_options(console PRIVATE -Wall -Wextra -Wno-deprecated-declarations)
endif()

target_include_directories(console PRIVATE
  ${JAGS_INCLUDE_DIRS}
  ${Python_NumPy_INCLUDE_DIRS}
)

target_link_libraries(console PRIVATE
  pybind11::module
  PkgConfig::JAGS
)

if(JAGS_LDFLAGS_OTHER)
  target_link_options(console PRIVATE ${JAGS_LDFLAGS_OTHER})
endif()

if(APPLE)
  set(_console_rpath "@loader_path;@loader_path/_vendor/jags/lib")
elseif(WIN32)
  set(_console_rpath "")
else()
  set(_console_rpath "$ORIGIN;$ORIGIN/_vendor/jags/lib")
endif()

if(NOT WIN32)
  set_target_properties(console PROPERTIES
    INSTALL_RPATH "${_console_rpath}"
    BUILD_RPATH "${_console_rpath}"
    BUILD_WITH_INSTALL_RPATH ON
  )
endif()

install(TARGETS console
  LIBRARY DESTINATION pyjags
  RUNTIME DESTINATION pyjags
  ARCHIVE DESTINATION pyjags
)

if(PYJAGS_VENDOR_JAGS AND JAGS_RUNTIME_LIBDIR)
  set(_vendor_lib_dest "pyjags/_vendor/jags/lib")
  if(WIN32)
    file(GLOB JAGS_RUNTIME_LIBS CONFIGURE_DEPENDS "${JAGS_RUNTIME_LIBDIR}/jags*.dll")
  elseif(APPLE)
    file(GLOB JAGS_RUNTIME_LIBS CONFIGURE_DEPENDS "${JAGS_RUNTIME_LIBDIR}/libjags*.dylib")
  else()
    file(GLOB JAGS_RUNTIME_LIBS CONFIGURE_DEPENDS "${JAGS_RUNTIME_LIBDIR}/libjags*.so*")
  endif()
  if(NOT JAGS_RUNTIME_LIBS)
    message(FATAL_ERROR "Unable to locate JAGS libraries under ${JAGS_RUNTIME_LIBDIR}")
  endif()
  install(FILES ${JAGS_RUNTIME_LIBS} DESTINATION "${_vendor_lib_dest}")

  if(JAGS_RUNTIME_MODULEDIR AND EXISTS "${JAGS_RUNTIME_MODULEDIR}")
    if(NOT JAGS_VERSION_MAJOR)
      message(WARNING "Unable to determine JAGS major version; copying module tree verbatim.")
      install(DIRECTORY "${JAGS_RUNTIME_MODULEDIR}/" DESTINATION "${_vendor_lib_dest}/JAGS")
    else()
      install(DIRECTORY "${JAGS_RUNTIME_MODULEDIR}/" DESTINATION "${_vendor_lib_dest}/JAGS/modules-${JAGS_VERSION_MAJOR}")
    endif()
  else()
    message(WARNING "JAGS modules directory not found; runtime modules will not be bundled.")
  endif()
endif()
