# PyJAGS: The Python Interface to JAGS
[![Build wheels](https://github.com/scoutiii/pyjags_JW/actions/workflows/build-wheels.yml/badge.svg)](https://github.com/scoutiii/pyjags_JW/actions/workflows/build-wheels.yml)
[![PyPI](https://img.shields.io/pypi/v/pyjags-jw.svg)](https://pypi.org/project/pyjags-jw/)
PyJAGS provides a Python interface to JAGS, a program for analysis of Bayesian
hierarchical models using Markov Chain Monte Carlo (MCMC) simulation.

PyJAGS adds the following features on top of JAGS:

* Multicore support for parallel simulation of multiple Markov chains (See Jupyter Notebook [Advanced Functionality](notebooks/Advanced%20Functionality.ipynb)
* Saving sample MCMC chains to and restoring from HDF5 files
* Functionality to merge samples along iterations or across chains so that sampling can be resumed in consecutive chunks until convergence criteria are satisfied
* Connectivity to the Bayesian analysis and visualization package Arviz

License: GPLv2

## Supported Platforms
- Linux: prebuilt wheels for CPython 3.11–3.13 on x86_64 and aarch64 with JAGS + toolchain runtimes fully bundled. `pip install pyjags-jw` should “just work.”
- macOS: wheels targeted for CPython 3.11–3.13 (x86_64) with bundled JAGS; arm64 coming next. Source builds still require a system JAGS if no wheel is available.
- Windows: planned; source builds currently require a system JAGS.

## Installation
```
pip install pyjags-jw
```
No system JAGS needed on supported Linux wheels.

<pre>
    pip install pyjags
</pre>

## Useful Links
* Package on the Python Package Index <https://pypi.python.org/pypi/pyjags>
* Project page on github <https://github.com/michaelnowotny/pyjags>
* JAGS manual and examples <http://sourceforge.net/projects/mcmc-jags/files/>


## Acknowledgements


* JAGS was created by Martyn Plummer
* PyJAGS was originally created by Tomasz Miasko
* As of May 2020, PyJAGS is developed by Michael Nowotny
