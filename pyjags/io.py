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
I/O utilities for saving and loading JAGS sample dictionaries.

This module uses `deepdish` (a thin HDF5 wrapper around PyTables)
to persist model sample dictionaries.  If `deepdish` is not installed,
an ImportError will be raised with instructions to install it via:

    pip install pyjags-next[io]

or manually:

    pip install deepdish
"""

from __future__ import annotations

import typing as tp
import numpy as np

# Attempt to import deepdish only when available.
try:
    import deepdish as dd
    _HAS_DEEPDISH = True
except Exception as _err:
    dd = None
    _HAS_DEEPDISH = False
    _DEEPDISH_IMPORT_ERROR = _err


def _require_deepdish() -> None:
    """Raise a friendly ImportError if deepdish is missing."""
    if not _HAS_DEEPDISH:
        raise ImportError(
            "The optional dependency 'deepdish' is not installed.\n"
            "Install it with one of the following commands:\n"
            "    pip install pyjags-next[io]\n"
            "or: pip install deepdish\n\n"
            f"Original import error: {_DEEPDISH_IMPORT_ERROR}"
        )


def save_samples_dictionary_to_file(
    filename: str,
    samples: tp.Dict[str, np.ndarray],
    compression: bool = True,
) -> None:
    """
    Save a dictionary of samples to an HDF5 file.

    Parameters
    ----------
    filename : str
        Path where the HDF5 file should be saved.
    samples : dict[str, np.ndarray]
        Mapping variable names -> Numpy arrays with shape
        (parameter_dimension, chain_length, number_of_chains).
    compression : bool, default=True
        Whether to use data compression (Blosc).
    """
    _require_deepdish()

    # Deepdish will handle ndarray dtypes automatically.
    if compression:
        dd.io.save(filename, samples, compression="blosc")
    else:
        dd.io.save(filename, samples, compression=None)


def load_samples_dictionary_from_file(filename: str) -> tp.Dict[str, np.ndarray]:
    """
    Load a dictionary of samples from an HDF5 file.

    Parameters
    ----------
    filename : str
        Path to the HDF5 file.

    Returns
    -------
    dict[str, np.ndarray]
        Mapping variable names -> Numpy arrays with shape
        (parameter_dimension, chain_length, number_of_chains).
    """
    _require_deepdish()
    return dd.io.load(filename)
