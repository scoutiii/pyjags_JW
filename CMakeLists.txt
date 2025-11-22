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
    set(_jags_lib_patterns
      "${JAGS_RUNTIME_LIBDIR}/jags*.dll"
      "${JAGS_RUNTIME_LIBDIR}/jrmath*.dll"
    )
  elseif(APPLE)
    set(_jags_lib_patterns
      "${JAGS_RUNTIME_LIBDIR}/libjags*.dylib"
      "${JAGS_RUNTIME_LIBDIR}/libjrmath*.dylib"
    )
  else()
    set(_jags_lib_patterns
      "${JAGS_RUNTIME_LIBDIR}/libjags*.so"
      "${JAGS_RUNTIME_LIBDIR}/libjrmath*.so"
    )
  endif()
  set(JAGS_RUNTIME_LIBS "")
  foreach(_pattern IN LISTS _jags_lib_patterns)
    file(GLOB _libs CONFIGURE_DEPENDS "${_pattern}")
    if(_libs)
      list(APPEND JAGS_RUNTIME_LIBS ${_libs})
    endif()
  endforeach()
  list(REMOVE_DUPLICATES JAGS_RUNTIME_LIBS)
  if(NOT JAGS_RUNTIME_LIBS)
    message(FATAL_ERROR "Unable to locate JAGS libraries under ${JAGS_RUNTIME_LIBDIR} (patterns: ${_jags_lib_patterns})")
  endif()
  install(FILES ${JAGS_RUNTIME_LIBS} DESTINATION "${_vendor_lib_dest}")

  if(NOT WIN32 AND NOT APPLE)
    set(_toolchain_vendor_libs "")

    if(CMAKE_CXX_COMPILER AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} "-print-file-name=libstdc++.so.6"
        OUTPUT_VARIABLE _stdcxx_path
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
      )
      if(_stdcxx_path AND EXISTS "${_stdcxx_path}" AND NOT IS_DIRECTORY "${_stdcxx_path}")
        get_filename_component(_stdcxx_dir "${_stdcxx_path}" DIRECTORY)
        file(GLOB _stdcxx_variants CONFIGURE_DEPENDS "${_stdcxx_dir}/libstdc++.so*")
        if(_stdcxx_variants)
          list(APPEND _toolchain_vendor_libs ${_stdcxx_variants})
        else()
          list(APPEND _toolchain_vendor_libs "${_stdcxx_path}")
        endif()
      else()
        message(WARNING "Could not determine path to libstdc++.so.6 from ${CMAKE_CXX_COMPILER}")
      endif()

      execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} "-print-file-name=libgcc_s.so.1"
        OUTPUT_VARIABLE _gccs_path
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
      )
      if(_gccs_path AND EXISTS "${_gccs_path}" AND NOT IS_DIRECTORY "${_gccs_path}")
        get_filename_component(_gccs_dir "${_gccs_path}" DIRECTORY)
        file(GLOB _gccs_variants CONFIGURE_DEPENDS "${_gccs_dir}/libgcc_s.so*")
        if(_gccs_variants)
          list(APPEND _toolchain_vendor_libs ${_gccs_variants})
        else()
          list(APPEND _toolchain_vendor_libs "${_gccs_path}")
        endif()
      else()
        message(WARNING "Could not determine path to libgcc_s.so.1 from ${CMAKE_CXX_COMPILER}")
      endif()
    endif()

    find_program(PYJAGS_GFORTRAN_EXECUTABLE NAMES gfortran)
    if(PYJAGS_GFORTRAN_EXECUTABLE)
      execute_process(
        COMMAND ${PYJAGS_GFORTRAN_EXECUTABLE} "-print-file-name=libgfortran.so.5"
        OUTPUT_VARIABLE _gfortran_path
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
      )
      if(_gfortran_path AND EXISTS "${_gfortran_path}" AND NOT IS_DIRECTORY "${_gfortran_path}")
        get_filename_component(_gfortran_dir "${_gfortran_path}" DIRECTORY)
        file(GLOB _gfortran_variants CONFIGURE_DEPENDS "${_gfortran_dir}/libgfortran.so*")
        if(_gfortran_variants)
          list(APPEND _toolchain_vendor_libs ${_gfortran_variants})
        else()
          list(APPEND _toolchain_vendor_libs "${_gfortran_path}")
        endif()
      else()
        message(WARNING "gfortran located at ${PYJAGS_GFORTRAN_EXECUTABLE} but libgfortran.so.5 not found via -print-file-name")
      endif()
    else()
      message(STATUS "gfortran executable not found; libgfortran will not be bundled unless provided by JAGS installation.")
    endif()

    if(_toolchain_vendor_libs)
      list(REMOVE_DUPLICATES _toolchain_vendor_libs)
      install(FILES ${_toolchain_vendor_libs} DESTINATION "${_vendor_lib_dest}")
    else()
      message(WARNING "No GNU toolchain runtime libraries detected for bundling; resulting wheel may depend on system libstdc++/libgcc_s/libgfortran.")
    endif()
  endif()

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

  # Normalize RPATH of vendored JAGS libraries and modules so they resolve within the wheel.
  if(NOT WIN32)
    find_program(PATCHELF_EXECUTABLE patchelf)
    if(PATCHELF_EXECUTABLE)
      install(CODE "
        file(GLOB _vendored_libs \"\${CMAKE_INSTALL_PREFIX}/${_vendor_lib_dest}/libjags*.so*\" \"\${CMAKE_INSTALL_PREFIX}/${_vendor_lib_dest}/libjrmath*.so*\")
        foreach(_lib IN LISTS _vendored_libs)
          execute_process(COMMAND \"${PATCHELF_EXECUTABLE}\" --force-rpath --set-rpath \"\$ORIGIN\" \"\${_lib}\" RESULT_VARIABLE _r)
          if(NOT _r EQUAL 0)
            message(WARNING \"Failed to set RPATH on \${_lib}\")
          endif()
        endforeach()

        file(GLOB_RECURSE _vendored_modules \"\${CMAKE_INSTALL_PREFIX}/${_vendor_lib_dest}/JAGS/modules-${JAGS_VERSION_MAJOR}/*.so\")
        foreach(_mod IN LISTS _vendored_modules)
          execute_process(COMMAND \"${PATCHELF_EXECUTABLE}\" --force-rpath --set-rpath \"\$ORIGIN/../..\" \"\${_mod}\" RESULT_VARIABLE _r2)
          if(NOT _r2 EQUAL 0)
            message(WARNING \"Failed to set RPATH on \${_mod}\")
          endif()
        endforeach()
      ")
    else()
      message(WARNING "patchelf not found; vendored JAGS modules may not locate libjags at runtime.")
    endif()
  endif()
endif()
