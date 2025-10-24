import pytest

def _require_jags():
    import pyjags
    try:
        _ = pyjags.Model
    except Exception as e:
        pytest.skip(f"JAGS runtime not available: {e!r}")

def test_version_and_model_symbol():
    import pyjags
    assert isinstance(pyjags.__version__, str) and len(pyjags.__version__) > 0
    _require_jags()  # ensures Model is importable/linked
