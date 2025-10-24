cmake_minimum_required(VERSION 3.20)
project(pyjags_console LANGUAGES CXX)

# --- Python, NumPy, pybind11 ---
# Development.Module gives us the Python extension suffix and link flags,
# NumPy gives us the headers for array conversions (even if console.cc doesn’t need them now).
find_package(Python REQUIRED COMPONENTS Interpreter Development.Module NumPy)
find_package(pybind11 CONFIG REQUIRED)

# --- JAGS via pkg-config ---
find_package(PkgConfig REQUIRED)
pkg_check_modules(JAGS REQUIRED jags)

# Source (explicit path makes sdists predictable)
set(CONSOLE_SRC "${PROJECT_SOURCE_DIR}/pyjags/console.cc")
if(NOT EXISTS "${CONSOLE_SRC}")
  message(FATAL_ERROR "Expected source not found: ${CONSOLE_SRC}")
endif()

# Build the extension module
add_library(console MODULE "${CONSOLE_SRC}")
target_compile_features(console PRIVATE cxx_std_17)

# Include + link paths
target_include_directories(console PRIVATE
  ${Python_INCLUDE_DIRS}
  ${Python_NumPy_INCLUDE_DIRS}
  ${JAGS_INCLUDE_DIRS}
)

# On some distros pkg-config provides link dirs separately
if(JAGS_LIBRARY_DIRS)
  target_link_directories(console PRIVATE ${JAGS_LIBRARY_DIRS})
endif()

# Link against pybind11 (module flavor), Python, and JAGS
target_link_libraries(console PRIVATE
  pybind11::module
  ${Python_LIBRARIES}
  ${JAGS_LIBRARIES}
)

# Ensure we get "console.<abi>.<plat>.so" (no "lib" prefix) and correct suffix
set_target_properties(console PROPERTIES
  PREFIX ""
  SUFFIX "${Python_EXTENSION_SUFFIX}"
)

# Stricter linking on Linux to fail fast if something is missing
if(APPLE)
  # Let undefined symbols resolve at runtime against Python on macOS
  target_link_options(console PRIVATE "-Wl,-undefined,dynamic_lookup")
else()
  target_link_options(console PRIVATE "-Wl,--no-undefined")
endif()

# RPATH so the loader can find vendored libs placed by auditwheel/delocate
# Linux uses $ORIGIN; macOS uses @loader_path
if(APPLE)
  set_target_properties(console PROPERTIES
    BUILD_RPATH "@loader_path"
    INSTALL_RPATH "@loader_path"
  )
else()
  set_target_properties(console PROPERTIES
    BUILD_RPATH "\$ORIGIN"
    INSTALL_RPATH "\$ORIGIN"
  )
endif()

# Install into the pyjags/ package within the wheel
install(TARGETS console
  LIBRARY DESTINATION pyjags
)
