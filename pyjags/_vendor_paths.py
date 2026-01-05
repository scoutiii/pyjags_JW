import os
from pathlib import Path


def ensure_windows_dll_search_path(path):
    if os.name != "nt":
        return
    if not path:
        return
    path = str(path)
    if not os.path.isdir(path):
        return
    if hasattr(os, "add_dll_directory"):
        os.add_dll_directory(path)
    else:
        current = os.environ.get("PATH", "")
        parts = current.split(os.pathsep) if current else []
        if path not in parts:
            os.environ["PATH"] = os.pathsep.join([path] + parts) if parts else path


def prefill_vendor_lib_dir():
    root = Path(__file__).resolve().parent

    candidates = [
        root / "_vendor" / "jags" / "lib",
        root.parent / "pyjags_jw.libs",
        root.parent / "pyjags.libs",
    ]

    env_root = os.getenv("PYJAGS_VENDOR_JAGS_ROOT")
    if env_root:
        candidates.insert(0, Path(env_root) / "x64" / "bin")
        candidates.insert(0, Path(env_root) / "bin")
        candidates.insert(0, Path(env_root) / "lib")

    for candidate in candidates:
        if candidate.is_dir():
            ensure_windows_dll_search_path(candidate)
