# Copyright (C) 2015-2016 Tomasz Miasko
#               2020 Michael Nowotny
#               2025 Scout Jarman and contributors
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

"""
pyjags: Python bindings for JAGS

This package re-exports convenience functions and classes at the top level.
To improve robustness, heavy / compiled bits are **lazily imported** so that
`import pyjags` succeeds even if optional system/runtime pieces are not present.
The compiled extension is only loaded when you access e.g. `pyjags.Model`.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

# --- Version ---------------------------------------------------------------

try:
    from ._version import get_versions  # type: ignore
    __version__ = get_versions()["version"]
    del get_versions
except Exception:  # pragma: no cover
    __version__ = "0+unknown"

# --- Eager, pure-Python re-exports (safe to import immediately) -----------

from .incremental_sampling import (  # noqa: F401
    EffectiveSampleSizeCriterion,
    RHatDeviationCriterion,
    EffectiveSampleSizeAndRHatCriterion,
    sample_until,
)

from .chain_utilities import (  # noqa: F401
    discard_burn_in_samples,
    extract_final_iteration_from_samples_for_initialization,
    merge_parallel_chains,
    merge_consecutive_chains,
)

from .dic import dic_samples  # noqa: F401

# io.py is safe to import even without deepdish; it raises only when used.
from .io import (  # noqa: F401
    load_samples_dictionary_from_file,
    save_samples_dictionary_to_file,
)

# --- Public API surface ----------------------------------------------------

__all__ = [
    # version
    "__version__",
    # incremental_sampling
    "EffectiveSampleSizeCriterion",
    "RHatDeviationCriterion",
    "EffectiveSampleSizeAndRHatCriterion",
    "sample_until",
    # chain utilities
    "discard_burn_in_samples",
    "extract_final_iteration_from_samples_for_initialization",
    "merge_parallel_chains",
    "merge_consecutive_chains",
    # DIC
    "dic_samples",
    # I/O helpers
    "load_samples_dictionary_from_file",
    "save_samples_dictionary_to_file",
    # model & modules (lazily provided)
    "Model",
    # anything else exported by modules.py will be handled lazily
]

# --- Lazy import machinery (PEP 562) --------------------------------------

def __getattr__(name: str):
    """
    Lazily import attributes from submodules to avoid importing the compiled
    extension (pyjags.console via pyjags.model) until actually needed.
    """
    # Try model first (provides Model, etc.)
    if name in {"Model"}:
        from . import model as _model  # local import
        try:
            return getattr(_model, name)
        except AttributeError:  # pragma: no cover
            raise

    # Fallback: check modules.py for any names users might grab from top-level
    try:
        from . import modules as _modules  # local import
        if hasattr(_modules, name):
            return getattr(_modules, name)
    except Exception:
        # If modules import fails, continue to final error below.
        pass

    # Last chance: load model/modules and see if name appeared in their __all__
    for modname in (".model", ".modules"):
        try:
            mod = __import__(__name__ + modname, fromlist=["*"])
            if hasattr(mod, name):
                return getattr(mod, name)
        except Exception:
            # Ignore and try the next candidate
            continue

    raise AttributeError(f"module '{__name__}' has no attribute '{name}'")


# --- Type checking friendliness -------------------------------------------

if TYPE_CHECKING:
    # During static analysis, make the symbols visible without executing imports.
    from .model import Model  # noqa: F401
    # If you have specific exports in modules.py you want visible to type checkers,
    # you can list them explicitly here as needed.
