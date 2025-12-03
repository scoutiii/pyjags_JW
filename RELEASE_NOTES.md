# Release checklist (PyPI / TestPyPI)

## 1. Prep environment
- Ensure you have `gh`, `python -m pip install --upgrade build twine`.
- Clean old artifacts: `rm -rf dist wheelhouse/all`.

## 2. Download wheels from CI (latest run)
```bash
# set repo once
# gh repo set-default scoutiii/pyjags_JW

# list recent runs
gh run list --limit 5 --repo scoutiii/pyjags_JW
# download artifacts from the desired run id
gh run download <run-id> -n wheels-linux -D wheelhouse --repo scoutiii/pyjags_JW
gh run download <run-id> -n wheels-macos -D wheelhouse --repo scoutiii/pyjags_JW

# after download you should have:
# wheelhouse/wheels-linux/*.whl
# wheelhouse/wheels-macos/*.whl
```

## 3. Gather artifacts locally
```bash
# mkdir -p wheelhouse/all
# cp wheelhouse/wheels-linux/*.whl wheelhouse/wheels-macos/*.whl wheelhouse/all/
# optional: add sdist
python -m build --sdist --outdir wheelhouse
```

## 4. Sanity check
```bash
python -m pip install --upgrade twine
twine check wheelhouse/*
```

## 5. Upload to TestPyPI (dry run)
```bash
export TWINE_USERNAME="__token__"
export TWINE_PASSWORD="pypi-<your-testpypi-token>"
twine upload --repository testpypi wheelhouse/*
```

## 6. Verify from a clean env
```bash
python -m venv /tmp/pjtest && source /tmp/pjtest/bin/activate
python -m pip install --upgrade pip
pip install --index-url https://test.pypi.org/simple --extra-index-url https://pypi.org/simple pyjags-jw
python - <<'PY'
import pyjags, pathlib, os, subprocess
so = next(pathlib.Path(pyjags.__file__).parent.glob("console*.so"))
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = str(pathlib.Path(pyjags.__file__).parent / "_vendor" / "jags" / "lib")
subprocess.run(["ldd", str(so)], env=env)
print("pyjags version:", pyjags.__version__)
PY
deactivate
```

## 7. Upload to PyPI (production)
```bash
export TWINE_USERNAME="__token__"
export TWINE_PASSWORD="pypi-<your-prod-token>"
twine upload wheelhouse/all/*
```

## 8. Post-release
- Tag the release in git (`git tag vX.Y.Z && git push origin vX.Y.Z`).
- Update README/badges if needed.

Notes:
- `pyproject.toml` already declares runtime deps (`numpy`, `arviz`, etc.), so pip will pull them automatically from PyPI. When testing against TestPyPI, use `--extra-index-url https://pypi.org/simple` so pip can find deps.
- macOS wheels must be built on macOS runners; Linux wheels on Linux runners. Use the GitHub Actions artifacts above to avoid rebuilding locally.***
