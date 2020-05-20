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

import arviz as az
import numpy as np
import typing as tp


def convert_pyjags_samples_dict_to_arviz_inference_data(
        samples: tp.Dict[str, np.ndarray]) -> az.InferenceData:
    """
    This function takes a python dictionary of samples that has been generated
    by sample method of a model instance and returns an Arviz inference data
    object.
    Parameters
    ----------
    samples: a dictionary mapping variable names to Numpy arrays with shape
             (parameter_dimension, chain_length, number_of_chains)

    Returns
    -------
    An Arviz inference data object
    """
    # pyjags returns a dictionary of numpy arrays with shape
    #         (parameter_dimension, chain_length, number_of_chains)
    # but arviz expects samples with shape
    #         (number_of_chains, chain_length, parameter_dimension)

    parameter_name_to_samples_map = {}

    for parameter_name, chains in samples.items():
        parameter_dimension, chain_length, number_of_chains = chains.shape
        if parameter_dimension == 1:
            parameter_name_to_samples_map[parameter_name] = \
                chains[0, :, :].transpose()
        else:
            for i in range(parameter_dimension):
                parameter_name_to_samples_map[parameter_name] = \
                    np.swapaxes(chains, 0, 2)

    return az.convert_to_inference_data(parameter_name_to_samples_map)
