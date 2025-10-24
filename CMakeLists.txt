cmake_minimum_required(VERSION 3.20)
project(pyjags_console LANGUAGES CXX)

# Python, NumPy, pybind11
find_package(Python COMPONENTS Interpreter Development.Module NumPy REQUIRED)
find_package(pybind11 CONFIG REQUIRED)

# JAGS via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(JAGS REQUIRED jags)

# Explicit source path + guard (helps sdists)
set(CONSOLE_SRC "${PROJECT_SOURCE_DIR}/pyjags/console.cc")
if(NOT EXISTS "${CONSOLE_SRC}")
  message(FATAL_ERROR "Expected source not found: ${CONSOLE_SRC}")
endif()

# Build the extension module
pybind11_add_module(console MODULE "${CONSOLE_SRC}")

# Ensure the file name is "console.<abi>.<plat>.so" (no "lib" prefix etc.)
# pybind11_add_module already sets this, but these keep it explicit & portable:
set_target_properties(console PROPERTIES
  PREFIX ""  # avoid 'lib' prefix on some platforms/generators
)

# Compile flags
target_compile_features(console PRIVATE cxx_std_14)
if(MSVC)
  target_compile_options(console PRIVATE /W3)
else()
  target_compile_options(console PRIVATE -Wall -Wextra -Wno-deprecated-declarations)
endif()

# Include dirs & link to JAGS
target_include_directories(console PRIVATE
  ${JAGS_INCLUDE_DIRS}
  ${Python_NumPy_INCLUDE_DIRS}
)

# JAGS libs from pkg-config
target_link_libraries(console PRIVATE
  pybind11::module
  ${JAGS_LIBRARIES}
)

# Pass through any extra -L/-Wl flags from pkg-config
target_link_options(console PRIVATE ${JAGS_LDFLAGS_OTHER})

# RPATH suitable for wheels
if(APPLE)
  set_target_properties(console PROPERTIES
    INSTALL_RPATH "@loader_path"
    BUILD_WITH_INSTALL_RPATH ON
  )
else()
  set_target_properties(console PROPERTIES
    INSTALL_RPATH "\$ORIGIN"
    BUILD_WITH_INSTALL_RPATH ON
  )
endif()

# Install the module into the package directory *inside* the wheel
# scikit-build-core collects from the install tree.
install(TARGETS console
  LIBRARY DESTINATION pyjags
  RUNTIME DESTINATION pyjags
  ARCHIVE DESTINATION pyjags
)
