curl -sL https://raw.githubusercontent.com/kj-9/setup-spatialite-macos/main/scripts/setup.sh | \
  bash -s -- .venv


.venv/bin/python -m pip install sqlite-utils
