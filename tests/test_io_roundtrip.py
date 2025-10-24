import os
import tempfile
import numpy as np
import pytest

def _require_jags():
    import pyjags
    try:
        _ = pyjags.Model
    except Exception as e:
        pytest.skip(f"JAGS runtime not available: {e!r}")

def test_save_load_roundtrip_hdf5():
    _require_jags()
    import pyjags
    from pyjags.io import save_samples_dictionary_to_file, load_samples_dictionary_from_file

    model = """
    model {
      y ~ dbin(theta, n)
      theta ~ dbeta(1, 1)
    }
    """
    data = dict(y=5, n=8)
    m = pyjags.Model(code=model, data=data, chains=2, adapt=200)
    s = m.sample(500, vars=["theta"])

    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, "samples.h5")
        save_samples_dictionary_to_file(path, s, compression=True)
        s2 = load_samples_dictionary_from_file(path)

    assert set(s2.keys()) == {"theta"}
    assert s2["theta"].shape == s["theta"].shape
    # values shouldn’t be identical every element (different copy), but close
    assert np.allclose(s2["theta"], s["theta"])
