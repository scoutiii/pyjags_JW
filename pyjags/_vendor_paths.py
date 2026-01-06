import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

_DLL_DIR_HANDLES = []
_DLL_DIR_PATHS = set()

_DLL_DEP_RE = re.compile(r"[A-Za-z0-9_.+\-]+\.dll", re.IGNORECASE)


def _vendor_candidates(root):
    candidates = [
        root,
        root / "_vendor" / "jags" / "lib",
        root.parent / "pyjags_jw.libs",
        root.parent / "pyjags.libs",
    ]

    env_root = os.getenv("PYJAGS_VENDOR_JAGS_ROOT")
    if env_root:
        candidates.insert(0, Path(env_root) / "x64" / "bin")
        candidates.insert(0, Path(env_root) / "bin")
        candidates.insert(0, Path(env_root) / "lib")

    return candidates


def ensure_windows_dll_search_path(path):
    if os.name != "nt":
        return
    if not path:
        return
    path = str(path)
    if not os.path.isdir(path):
        return
    if hasattr(os, "add_dll_directory"):
        norm_path = os.path.normcase(os.path.abspath(path))
        if norm_path in _DLL_DIR_PATHS:
            return
        handle = os.add_dll_directory(path)
        _DLL_DIR_HANDLES.append(handle)
        _DLL_DIR_PATHS.add(norm_path)
    else:
        current = os.environ.get("PATH", "")
        parts = current.split(os.pathsep) if current else []
        if path not in parts:
            os.environ["PATH"] = os.pathsep.join([path] + parts) if parts else path


def prefill_vendor_lib_dir():
    root = Path(__file__).resolve().parent
    for candidate in _vendor_candidates(root):
        if candidate.is_dir():
            ensure_windows_dll_search_path(candidate)


def _iter_dlls(path):
    try:
        return sorted(p.name for p in Path(path).glob("*.dll"))
    except OSError:
        return []


def _find_tool(names):
    for name in names:
        path = shutil.which(name)
        if path:
            return path
    return None


def _deps_from_objdump(path):
    objdump = _find_tool(["objdump.exe", "objdump"])
    if not objdump:
        return []
    try:
        output = subprocess.check_output([objdump, "-p", str(path)], text=True, errors="ignore")
    except (OSError, subprocess.CalledProcessError):
        return []
    deps = []
    for line in output.splitlines():
        if "DLL Name:" in line:
            match = _DLL_DEP_RE.search(line)
            if match:
                deps.append(match.group(0))
    return sorted(set(deps))


def _deps_from_dumpbin(path):
    dumpbin = _find_tool(["dumpbin.exe", "dumpbin"])
    if not dumpbin:
        return []
    try:
        output = subprocess.check_output([dumpbin, "/dependents", str(path)], text=True, errors="ignore")
    except (OSError, subprocess.CalledProcessError):
        return []
    deps = []
    for line in output.splitlines():
        match = _DLL_DEP_RE.search(line)
        if match:
            deps.append(match.group(0))
    return sorted(set(deps))


def _deps_for_path(path):
    deps = _deps_from_dumpbin(path)
    if deps:
        return deps
    return _deps_from_objdump(path)


def _locate_dll(name, search_paths):
    for path in search_paths:
        candidate = Path(path) / name
        if candidate.exists():
            return str(candidate)
    return None


def _loaded_modules():
    if os.name != "nt":
        return []
    try:
        import ctypes
        import ctypes.wintypes as wt
    except Exception:
        return []

    TH32CS_SNAPMODULE = 0x00000008
    TH32CS_SNAPMODULE32 = 0x00000010

    class MODULEENTRY32(ctypes.Structure):
        _fields_ = [
            ("dwSize", wt.DWORD),
            ("th32ModuleID", wt.DWORD),
            ("th32ProcessID", wt.DWORD),
            ("GlblcntUsage", wt.DWORD),
            ("ProccntUsage", wt.DWORD),
            ("modBaseAddr", wt.LPVOID),
            ("modBaseSize", wt.DWORD),
            ("hModule", wt.HMODULE),
            ("szModule", wt.WCHAR * 256),
            ("szExePath", wt.WCHAR * 260),
        ]

    kernel32 = ctypes.windll.kernel32
    snapshot = kernel32.CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, 0)
    if snapshot == wt.HANDLE(-1).value:
        return []

    modules = []
    entry = MODULEENTRY32()
    entry.dwSize = ctypes.sizeof(MODULEENTRY32)

    if not kernel32.Module32FirstW(snapshot, ctypes.byref(entry)):
        kernel32.CloseHandle(snapshot)
        return []

    while True:
        if entry.szExePath:
            modules.append(entry.szExePath)
        if not kernel32.Module32NextW(snapshot, ctypes.byref(entry)):
            break

    kernel32.CloseHandle(snapshot)
    return modules


def diagnose_windows_dll_load(context, error=None):
    if os.name != "nt":
        return

    root = Path(__file__).resolve().parent
    candidates = [c for c in _vendor_candidates(root) if c.is_dir()]
    system_root = Path(os.environ.get("SystemRoot", r"C:\Windows"))
    system_dirs = [system_root / "System32", system_root / "SysWOW64"]
    path_dirs = [Path(p) for p in os.environ.get("PATH", "").split(os.pathsep) if p]
    search_paths = [str(p) for p in candidates + system_dirs + path_dirs if p]

    print("PYJAGS Windows DLL diagnostics:", file=sys.stderr)
    print(f"  context: {context}", file=sys.stderr)
    if error:
        print(f"  error: {error}", file=sys.stderr)
    print(f"  python: {sys.executable}", file=sys.stderr)
    print(f"  package_root: {root}", file=sys.stderr)
    print(f"  dll_dirs_added: {sorted(_DLL_DIR_PATHS)}", file=sys.stderr)

    for candidate in candidates:
        dlls = _iter_dlls(candidate)
        print(f"  candidate: {candidate}", file=sys.stderr)
        if dlls:
            print(f"    dlls: {', '.join(dlls)}", file=sys.stderr)
        else:
            print("    dlls: (none)", file=sys.stderr)

    pyds = sorted(root.glob("console*.pyd"))
    if pyds:
        pyd_path = pyds[0]
        print(f"  console_pyd: {pyd_path}", file=sys.stderr)
        deps = _deps_for_path(pyd_path)
        if deps:
            print("  console_pyd deps:", file=sys.stderr)
            for dep in deps:
                location = _locate_dll(dep, search_paths)
                if location:
                    print(f"    {dep}: {location}", file=sys.stderr)
                else:
                    print(f"    {dep}: (not found in search paths)", file=sys.stderr)
        else:
            print("  console_pyd deps: (unable to determine)", file=sys.stderr)
    else:
        print("  console_pyd: (not found)", file=sys.stderr)

    loaded = _loaded_modules()
    if loaded:
        needle = re.compile(r"(jags|jrmath|gfortran|quadmath|gomp|winpthread|libgcc|libstdc\+\+|blas|lapack)", re.IGNORECASE)
        filtered = [m for m in loaded if needle.search(m)]
        if filtered:
            print("  loaded modules (filtered):", file=sys.stderr)
            for mod in filtered:
                print(f"    {mod}", file=sys.stderr)
        else:
            print("  loaded modules (filtered): (none matched)", file=sys.stderr)
