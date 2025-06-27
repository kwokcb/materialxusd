rm -rf dist/ build/ *.egg-info
py -m build
twine check dist/*
