import numpy as np
import pytest

pytestmark = pytest.mark.filterwarnings("ignore::UserWarning")

def _require_jags():
    import pyjags
    try:
        # Touch the extension; if the shared lib can’t load, this raises
        _ = pyjags.Model
    except Exception as e:  # OSError/ImportError/etc.
        pytest.skip(f"JAGS runtime not available: {e!r}")

def test_binomial_beta_runs_and_shape():
    _require_jags()
    import pyjags
    model = """
    model {
      y ~ dbin(theta, n)
      theta ~ dbeta(1, 1)
    }
    """
    data = dict(y=7, n=10)
    m = pyjags.Model(code=model, data=data, chains=2, adapt=500)
    s = m.sample(1000, vars=["theta"])  # shape: (param_dim, iters, chains)
    assert "theta" in s
    arr = s["theta"]
    assert arr.ndim == 3
    assert arr.shape[0] == 1              # scalar parameter
    assert arr.shape[2] == 2              # two chains
    # mean should be close to posterior mean of Beta(8,4) ≈ 0.6667
    mean_est = float(np.mean(arr))
    assert 0.60 < mean_est < 0.73
