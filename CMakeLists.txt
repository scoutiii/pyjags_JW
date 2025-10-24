# CMakeLists.txt
cmake_minimum_required(VERSION 3.20)
project(pyjags_console LANGUAGES CXX)

# Python & NumPy
find_package(Python COMPONENTS Interpreter Development.Module NumPy REQUIRED)

# pybind11
find_package(pybind11 CONFIG REQUIRED)

# JAGS via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(JAGS REQUIRED jags)

# Ensure the source exists (helps when building from an sdist)
set(CONSOLE_SRC "${PROJECT_SOURCE_DIR}/pyjags/console.cc")
if(NOT EXISTS "${CONSOLE_SRC}")
  message(FATAL_ERROR "Expected source not found: ${CONSOLE_SRC}")
endif()

# Extension target (absolute path avoids CWD surprises)
pybind11_add_module(console MODULE
  "${CONSOLE_SRC}"
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

# If pkg-config reported extra -L/-Wl flags, honor them
target_link_options(console PRIVATE ${JAGS_LDFLAGS_OTHER})

target_link_libraries(console PRIVATE
  pybind11::module
  ${JAGS_LIBRARIES}
)

# RPATH inside wheels
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

# Install the extension inside the Python package
install(TARGETS console
  LIBRARY DESTINATION pyjags
  ARCHIVE DESTINATION pyjags
  RUNTIME DESTINATION pyjags
)
