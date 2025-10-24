cmake_minimum_required(VERSION 3.20)
project(pyjags_console LANGUAGES CXX)

# --- Python & NumPy (headers) ---
# scikit-build-core wires CMake's FindPython.
find_package(Python 3.11 COMPONENTS Interpreter Development.Module NumPy REQUIRED)

# --- pybind11 (provided by pip pybind11 wheel) ---
# Using CONFIG allows CMake to find pybind11's CMake package from the pip install.
find_package(pybind11 CONFIG REQUIRED)

# --- JAGS detection ---
# Prefer pkg-config for system JAGS; fallback to manual hints if needed.
find_package(PkgConfig REQUIRED)
pkg_check_modules(JAGS REQUIRED jags)

# If you want a more robust fallback, you can add:
# find_path(JAGS_INCLUDE_DIR jags/jags.h HINTS $ENV{JAGS_ROOT}/include)
# find_library(JAGS_LIBRARY jags HINTS $ENV{JAGS_ROOT}/lib $ENV{JAGS_ROOT}/lib64)
# and then use those if pkg-config isn't found. For now, pkg-config is required.

# --- Target: the extension module ---
# NOTE: Use the *filename* "console" (no dots). We'll install it under pyjags/ so it imports as pyjags.console
pybind11_add_module(console MODULE
    pyjags/console.cc
)

# C++ standard & warnings
target_compile_features(console PRIVATE cxx_std_14)
if (MSVC)
    target_compile_options(console PRIVATE /W3)
else()
    target_compile_options(console PRIVATE -Wall -Wextra -Wno-deprecated-declarations)
endif()

# Include dirs & link to JAGS
target_include_directories(console PRIVATE
    ${JAGS_INCLUDE_DIRS}
    ${Python_NumPy_INCLUDE_DIRS}
)

target_link_libraries(console PRIVATE
    pybind11::module
    ${JAGS_LIBRARIES}
)

# If JAGS needs extra link flags from pkg-config:
target_link_options(console PRIVATE ${JAGS_LDFLAGS_OTHER})

# Define the JAGS version macro if your C++ uses it
target_compile_definitions(console PRIVATE PYJAGS_JAGS_VERSION="4.3.2")

# On Linux, don't bake in rpaths to conda libstdc++; let system libstdc++ resolve.
if(APPLE)
  # Adjust if you need custom rpaths on macOS
  set_target_properties(console PROPERTIES
    INSTALL_RPATH "@loader_path"
  )
elseif(UNIX)
  set_target_properties(console PROPERTIES
    INSTALL_RPATH "$ORIGIN"
  )
endif()

# --- Install: place the extension **inside** the pyjags package ---
# This makes the wheel contain pyjags/console*.so so you can "import pyjags.console"
install(TARGETS console
  LIBRARY DESTINATION pyjags
  ARCHIVE DESTINATION pyjags
  RUNTIME DESTINATION pyjags
)
