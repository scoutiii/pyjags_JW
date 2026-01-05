# PyJAGS_JW: The Python Interface to JAGS That "Just Works"
[![Build wheels](https://github.com/scoutiii/pyjags_JW/actions/workflows/build-wheels.yml/badge.svg)](https://github.com/scoutiii/pyjags_JW/actions/workflows/build-wheels.yml)
[![PyPI](https://img.shields.io/pypi/v/pyjags-jw.svg)](https://pypi.org/project/pyjags-jw/)  
--

PyJAGS_JW provides a Python interface to JAGS, a program for analysis of Bayesian
hierarchical models using Markov Chain Monte Carlo (MCMC) simulation.

PyJAGS adds the following features on top of JAGS:

* Multicore support for parallel simulation of multiple Markov chains (See Jupyter Notebook [Advanced Functionality](notebooks/Advanced%20Functionality.ipynb))
* Saving sample MCMC chains to and restoring from HDF5 files
* Functionality to merge samples along iterations or across chains so that sampling can be resumed in consecutive chunks until convergence criteria are satisfied
* Connectivity to the Bayesian analysis and visualization package Arviz

PyJAGS_JW ("JW" = Just Works) adds the following features ontop of PyJAGS:

* Modern build system to comply with current pip requirements
* Vendored JAGS and other packages so that the user doesn't need to install of compile anything else
* Install support for Linux and Unix (and soon Windows)


Prebuilt wheels of `pyjags-jw` for supported platforms include a bundled build of
JAGS (Just Another Gibbs Sampler). This is done so that `pip install pyjags-jw`
works without requiring users to separately install or compile JAGS.

The JAGS binary included in each wheel is built automatically during continuous
integration. The exact steps used to download, configure, build, and vendor JAGS
are fully documented in this repository, and are found in the files:

- `ci/`
- `pyproject.toml`
- `.github/workflows/build-wheels.yml`

## Supported Platforms
- Linux: prebuilt wheels for CPython 3.11–3.13 on x86_64 and aarch64 with JAGS + toolchain runtimes fully bundled. `pip install pyjags-jw` should “just work.”
- macOS: wheels targeted for CPython 3.11–3.13 (x86_64) with bundled JAGS; arm64 coming next. Source builds still require a system JAGS if no wheel is available.
- Windows: planned; source builds currently require a system JAGS, and is untested!

## Installation
```
pip install pyjags-jw
```
No system JAGS needed on supported Linux and MacOS wheels.



## Useful Links
* Package on the Python Package Index <https://pypi.org/project/pyjags-jw/>
* Project page on github <https://github.com/scoutiii/pyjags_JW>
* JAGS manual and examples <https://sourceforge.net/projects/mcmc-jags/files/Manuals/4.x/>


## Acknowledgements


* JAGS was created by Martyn Plummer
* PyJAGS was originally created by Tomasz Miasko
* As of May 2020, PyJAGS is developed by Michael Nowotny
* This package is a fork and update of Michael Nowotny's PyJAGS package, developed by Scout Jarman with the help of ChatGPT

## License and GPLv2 Compliance

This package is licensed under the GNU General Public License version 2 (GPLv2).

`pyjags-jw` is a fork of PyJAGS and distributes binaries of JAGS (Just Another Gibbs
Sampler), both of which are licensed under GPLv2. As a result, all wheels and source
distributions of this package are provided under GPLv2.

Prebuilt wheels of `pyjags-jw` include a bundled, unmodified build of JAGS.
In accordance with GPLv2 section 3(b), the complete corresponding source code for
the version of JAGS included in these binaries is available from:

https://sourceforge.net/projects/mcmc-jags/

The exact version of JAGS used, along with the full build and vendoring process,
can be determined from the CI configuration and build scripts included in this
repository.

This offer to provide the corresponding source code is valid for at least three
years from the date of distribution.

