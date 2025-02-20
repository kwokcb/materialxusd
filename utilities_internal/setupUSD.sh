#!/bin/bash

# Define the paths
USD_PYTHON_PATH="/d/Work/OpenUSD_25_02/lib/python"
USD_BIN_PATH="/d/Work/OpenUSD_25_02/bin"
USD_LIB_PATH="/d/Work/OpenUSD_25_02/lib"

# Update PYTHONPATH
export PYTHONPATH="$USD_PYTHON_PATH:$PYTHONPATH"

echo "PYTHONPATH set to: $PYTHONPATH"

# Update PATH
export PATH="$USD_BIN_PATH:$USD_LIB_PATH:$PATH"

echo "PATH set to: $PATH"
