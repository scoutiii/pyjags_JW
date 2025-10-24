cmake_minimum_required(VERSION 3.20)
project(pyjags_console LANGUAGES CXX)

# --- Options & policies
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Built by scikit-build-core
if(NOT DEFINED SKBUILD)
  message(FATAL_ERROR "This project is intended to be built via scikit-build-core")
endif()

# --- Python, NumPy, pybind11
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module NumPy)
find_package(pybind11 REQUIRED CONFIG)

# --- Locate JAGS (prefer pkg-config for include/libs)
# The install scripts ensure a usable jags.pc under $JAGS_PREFIX/lib/pkgconfig
find_package(PkgConfig REQUIRED)
if(DEFINED ENV{JAGS_PREFIX})
  set(ENV{PKG_CONFIG_PATH} "$ENV{JAGS_PREFIX}/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")
endif()
pkg_check_modules(JAGS REQUIRED jags)

# JAGS include/lib hints (for backup find_library if needed)
set(JAGS_INCLUDE_DIR ${JAGS_INCLUDEDIR})
find_library(JAGS_LIB NAMES jags jags-4
  HINTS ${JAGS_LIBDIR} ${JAGS_LIBRARY_DIRS}
)

if(NOT JAGS_LIB)
  message(FATAL_ERROR "Could not find JAGS library")
endif()

# --- Sources
set(CONSOLE_SRC "${PROJECT_SOURCE_DIR}/pyjags/console.cc")
if(NOT EXISTS "${CONSOLE_SRC}")
  message(FATAL_ERROR "Expected source not found: ${CONSOLE_SRC}")
endif()

# --- Build extension module
pybind11_add_module(console MODULE "${CONSOLE_SRC}")
target_include_directories(console PRIVATE ${JAGS_INCLUDE_DIR})
target_link_libraries(console PRIVATE ${JAGS_LIB})

# Ensure canonical extension name (no 'lib' prefix)
set_target_properties(console PROPERTIES PREFIX "")

# --- RPATH for bundled libs
if(APPLE)
  # @loader_path is where the extension lives inside the wheel
  set_target_properties(console PROPERTIES
    MACOSX_RPATH ON
    INSTALL_RPATH "@loader_path"
    BUILD_WITH_INSTALL_RPATH ON
  )
elseif(UNIX)
  # $ORIGIN is the extension’s dir; auditwheel will rewrite and bundle deps
  set_target_properties(console PROPERTIES
    BUILD_RPATH "\$ORIGIN"
    INSTALL_RPATH "\$ORIGIN"
  )
endif()

# Be explicit about symbol visibility on *nix
if(NOT MSVC)
  target_compile_options(console PRIVATE -fvisibility=hidden)
endif()

# --- Install: scikit-build-core will infer this and place the .so in the package dir
# Nothing else to install; the py package files are handled by sdist/wheel config.
