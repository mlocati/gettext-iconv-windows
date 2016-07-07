#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

autoreconf --force --install -I "$PWD/srcm4" -I "$PWD/m4" --warnings=none
