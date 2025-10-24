# GPLv2+

from __future__ import annotations
import typing as tp
import numpy as np
import h5py


def _save_array(grp: "h5py.Group", name: str, arr: np.ndarray, compression: bool) -> None:
    """Save ndarray or masked array into the HDF5 group."""
    if np.ma.isMaskedArray(arr):
        sub = grp.create_group(name)
        sub.attrs["__masked__"] = True
        sub.create_dataset("data", data=np.asarray(arr.data),
                           compression=("gzip" if compression else None))
        sub.create_dataset("mask", data=np.asarray(arr.mask, dtype=bool),
                           compression=("gzip" if compression else None))
    else:
        grp.create_dataset(name, data=np.asarray(arr),
                           compression=("gzip" if compression else None))


def _load_array(obj: "h5py.Group | h5py.Dataset") -> np.ndarray:
    """Load ndarray (or masked array if stored as a group)."""
    if isinstance(obj, h5py.Group) and obj.attrs.get("__masked__", False):
        data = np.array(obj["data"])
        mask = np.array(obj["mask"], dtype=bool)
        return np.ma.MaskedArray(data=data, mask=mask)
    elif isinstance(obj, h5py.Dataset):
        return np.array(obj)
    else:
        raise TypeError(f"Unsupported HDF5 object type: {type(obj)!r}")


def save_samples_dictionary_to_file(
    filename: str,
    samples: tp.Dict[str, np.ndarray],
    compression: bool = True,
) -> None:
    """Save a dict[str, ndarray] to HDF5."""
    with h5py.File(filename, mode="w") as h5:
        h5.attrs["__format__"] = "pyjags-jw:samples:1"
        for name, arr in samples.items():
            _save_array(h5, name, arr, compression=compression)


def load_samples_dictionary_from_file(filename: str) -> tp.Dict[str, np.ndarray]:
    """Load a dict[str, ndarray] from HDF5."""
    out: dict[str, np.ndarray] = {}
    with h5py.File(filename, mode="r") as h5:
        for name, obj in h5.items():
            out[name] = _load_array(obj)  # type: ignore[arg-type]
    return out
