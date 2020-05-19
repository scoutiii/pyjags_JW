# Copyright (C) 2015-2016 Tomasz Miasko
#               2020 Michael Nowotny
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

import deepdish as dd
import numpy as np
import typing as tp


def save_samples_dictionary_to_file(
        filename: str,
        samples_dictionary: tp.Dict[str, np.ndarray],
        compression: bool = True):
    if compression:
        dd.io.save(filename, samples_dictionary, compression='blosc')
    else:
        dd.io.save(filename, samples_dictionary, compression=None)


def load_samples_dictionary_from_file(filename: str) -> tp.Dict[str, np.ndarray]:
    return dd.io.load(filename)
