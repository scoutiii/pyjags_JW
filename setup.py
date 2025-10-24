from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext
import os, subprocess, sys
from pybind11.setup_helpers import Pybind11Extension, build_ext as pybind_build_ext
import numpy as np

def jags_pkg_config():
    cflags, libs = [], []
    try:
        cflags = subprocess.check_output(["pkg-config", "--cflags", "jags"], text=True).strip().split()
        libs = subprocess.check_output(["pkg-config", "--libs", "jags"], text=True).strip().split()
    except Exception:
        pass
    return cflags, libs

class BuildExt(pybind_build_ext):
    def build_extensions(self):
        cflags, libs = jags_pkg_config()

        # Fallbacks if pkg-config not present or returns nothing
        jags_dir = os.environ.get("JAGS_DIR", "")
        if not cflags and jags_dir:
            cflags += [f"-I{os.path.join(jags_dir, 'include')}"]
        if not libs and jags_dir:
            libs += [f"-L{os.path.join(jags_dir, 'lib')}", "-ljags"]

        # Common conda/homebrew hints (best-effort)
        common_inc = ["/usr/include", "/usr/local/include", "/opt/homebrew/include", "/opt/conda/include"]
        common_lib = ["/usr/lib", "/usr/local/lib", "/opt/homebrew/lib", "/opt/conda/lib"]
        if not any("jags" in " ".join(libs) for libs in [libs]):
            libs += [f"-L{p}" for p in common_lib] + ["-ljags"]

        for ext in self.extensions:
            ext.include_dirs += [np.get_include()]
            ext.extra_compile_args += ["-std=gnu++14", "-DNPY_NO_DEPRECATED_API=NPY_1_7_API_VERSION"]
            ext.extra_compile_args += [flag for flag in cflags if flag.startswith("-I")]
            ext.extra_link_args += libs

        # Check we have -ljags somewhere; fail early with a helpful message
        if not any(arg == "-ljags" or arg.endswith("/libjags.so") for arg in sum([ext.extra_link_args for ext in self.extensions], [])):
            raise RuntimeError(
                "Could not find libjags. Install it first:\n"
                "  Debian/Ubuntu: sudo apt install jags libjags-dev\n"
                "  Homebrew:      brew install jags\n"
                "  Conda:         conda install -c conda-forge jags\n"
                "Or set JAGS_DIR to your JAGS prefix."
            )

        super().build_extensions()

ext_modules = [
    Pybind11Extension(
        "pyjags.console",
        sources=["pyjags/console.cc"],
        include_dirs=[],
        extra_compile_args=[],
        extra_link_args=[],
        language="c++",
    )
]

setup(
    ext_modules=ext_modules,
    cmdclass={"build_ext": BuildExt},
)
