# pyjags/__init__.py

# Lightweight, predictable top-level API that mirrors classic pyjags

from importlib.metadata import PackageNotFoundError, version as _dist_version

# Public API
from .model import Model
from .incremental_sampling import (
    EffectiveSampleSizeCriterion,
    RHatDeviationCriterion,
    EffectiveSampleSizeAndRHatCriterion,
    sample_until,
)
from .chain_utilities import (
    discard_burn_in_samples,
    extract_final_iteration_from_samples_for_initialization,
    merge_parallel_chains,
    merge_consecutive_chains,
)
from .dic import dic_samples
from .io import (
    load_samples_dictionary_from_file,
    save_samples_dictionary_to_file,
)
from .modules import *  # historically exported

# Version (dist name is "pyjags-jw")
try:
    __version__ = _dist_version("pyjags-jw")
except PackageNotFoundError:  # editable dev fallback
    __version__ = "0.0.0"

__all__ = [
    "Model",
    "EffectiveSampleSizeCriterion",
    "RHatDeviationCriterion",
    "EffectiveSampleSizeAndRHatCriterion",
    "sample_until",
    "discard_burn_in_samples",
    "extract_final_iteration_from_samples_for_initialization",
    "merge_parallel_chains",
    "merge_consecutive_chains",
    "dic_samples",
    "load_samples_dictionary_from_file",
    "save_samples_dictionary_to_file",
]  # plus everything from modules.py
