# Copyright (C) 2016 Tomasz Miasko
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

__all__ = ['version', 'get_modules_dir', 'set_modules_dir', 'list_modules', 'load_module', 'unload_module']

import ctypes
import ctypes.util
import os
import logging
import sys
from pathlib import Path

logger = logging.getLogger('pyjags')


def _ensure_module_search_path(path):
    """Add the JAGS modules directory to the dynamic loader search path."""
    if not path:
        return
    path = str(path)
    for key in ('LTDL_LIBRARY_PATH', 'JAGS_MODULE_PATH'):
        current = os.environ.get(key)
        parts = current.split(os.pathsep) if current else []
        if path in parts:
            continue
        os.environ[key] = os.pathsep.join([path] + parts) if parts else path


def _prefill_modules_dir_from_package():
    """Eagerly seed module search path before the JAGS runtime initializes."""
    root = Path(__file__).resolve().parent

    candidates = []

    # Vendored wheel layout
    candidates.extend((root / "_vendor" / "jags" / "lib" / "JAGS").glob("modules-*"))

    # auditwheel / delvewheel relocations
    candidates.extend((root.parent / "pyjags_jw.libs" / "JAGS").glob("modules-*"))
    candidates.extend((root.parent / "pyjags.libs" / "JAGS").glob("modules-*"))

    env_root = os.getenv("PYJAGS_VENDOR_JAGS_ROOT")
    if env_root:
        candidates.extend((Path(env_root) / "lib" / "JAGS").glob("modules-*"))

    for candidate in candidates:
        if candidate.is_dir():
            _ensure_module_search_path(candidate)
            return str(candidate)

    return None


# Seed search path (must happen before importing Console / libjags)
modules_dir = _prefill_modules_dir_from_package()

from .console import Console  # noqa: E402


def version():
    """JAGS version as a tuple of ints.

    >>> pyjags.version()
    (3, 4, 0)
    """
    v = Console.version()
    return tuple(map(int, v.split('.')))


if sys.platform.startswith('darwin'):
    def list_shared_objects():
        """Return paths of all currently loaded shared objects."""

        libc = ctypes.util.find_library('c')
        libc = ctypes.cdll.LoadLibrary(libc)

        dyld_image_count = libc._dyld_image_count
        dyld_image_count.argtypes = []
        dyld_image_count.restype = ctypes.c_uint32

        dyld_image_name = libc._dyld_get_image_name
        dyld_image_name.argtypes = [ctypes.c_uint32]
        dyld_image_name.restype = ctypes.c_char_p

        libraries = []

        for index in range(dyld_image_count()):
            libraries.append(dyld_image_name(index))

        return list(map(getattr(os, 'fsdecode', lambda x: x), libraries))

elif sys.platform.startswith('linux'):
    def list_shared_objects():
        """Return paths of all currently loaded shared objects."""

        class dl_phdr_info(ctypes.Structure):
            _fields_ = [
                ('addr', ctypes.c_void_p),
                ('name', ctypes.c_char_p),
                ('phdr', ctypes.c_void_p),
                ('phnum', ctypes.c_uint16),
            ]

        dl_iterate_phdr_callback = ctypes.CFUNCTYPE(
                ctypes.c_int,
                ctypes.POINTER(dl_phdr_info),
                ctypes.POINTER(ctypes.c_size_t),
                ctypes.c_void_p)

        libc = ctypes.util.find_library('c')
        libc = ctypes.cdll.LoadLibrary(libc)
        dl_iterate_phdr = libc.dl_iterate_phdr
        dl_iterate_phdr.argtypes = [dl_iterate_phdr_callback, ctypes.c_void_p]
        dl_iterate_phdr.restype = ctypes.c_int

        libraries = []

        def callback(info, size, data):
            path = info.contents.name
            if path:
                libraries.append(path)
            return 0

        dl_iterate_phdr(dl_iterate_phdr_callback(callback), None)

        return list(map(getattr(os, 'fsdecode', lambda x: x), libraries))

else:
    def list_shared_objects():
        """Return paths of all currently loaded shared objects."""
        return []


def locate_modules_dir_using_shared_objects():
    for path in list_shared_objects():
        name = os.path.basename(path)
        if name.startswith('jags') or name.startswith('libjags'):
            dir = os.path.dirname(path)
            logger.info('Using JAGS library located in %s.', path)
            candidate = os.path.join(dir, 'JAGS', 'modules-{}'.format(version()[0]))
            if os.path.isdir(candidate):
                return candidate
    return None


def locate_modules_dir_from_package():
    root = Path(__file__).resolve().parent
    major = version()[0]

    candidates = [
        root / "_vendor" / "jags" / "lib" / "JAGS" / f"modules-{major}",
        # auditwheel / delvewheel may relocate vendored libs into <package>_vendor.libs
        root.parent / "pyjags_jw.libs" / "JAGS" / f"modules-{major}",
        root.parent / "pyjags.libs" / "JAGS" / f"modules-{major}",
    ]

    env_root = os.getenv("PYJAGS_VENDOR_JAGS_ROOT")
    if env_root:
        candidates.insert(0, Path(env_root) / "lib" / "JAGS" / f"modules-{major}")

    for candidate in candidates:
        if candidate.is_dir():
            logger.info("Using vendored JAGS modules located in %s.", candidate)
            return str(candidate)

    return None


def locate_modules_dir():
    logger.debug('Locating JAGS module directory.')
    dir_path = locate_modules_dir_using_shared_objects()
    if dir_path:
        return dir_path
    return locate_modules_dir_from_package()


def get_modules_dir():
    """Return modules directory."""
    global modules_dir
    if modules_dir is None:
        modules_dir = locate_modules_dir()
        _ensure_module_search_path(modules_dir)
    if modules_dir is None:
        raise RuntimeError(
            'Could not locate JAGS module directory. Use pyjags.set_modules_dir(path) to configure it manually.')
    return modules_dir


def set_modules_dir(directory):
    """Set modules directory."""
    global modules_dir
    modules_dir = directory
    _ensure_module_search_path(modules_dir)


def list_modules():
    """Return a list of loaded modules."""
    return Console.listModules()


def load_module(name, modules_dir=None):
    """Load a module.

    Parameters
    ----------
    name : str
        A name of module to load.
    modules_dir : str, optional
        Directory where modules are located.
    """
    if name not in loaded_modules:
        dir = modules_dir or get_modules_dir()
        _ensure_module_search_path(dir)
        ext = '.so' if os.name == 'posix' else '.dll'
        path = os.path.join(dir, name + ext)
        logger.info('Loading module %s from %s', name, path)
        module = ctypes.cdll.LoadLibrary(path)
        loaded_modules[name] = module
    Console.loadModule(name)

loaded_modules = {}


def unload_module(name):
    """Unload a module."""
    return Console.unloadModule(name)
