#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

HOST="${1:?usage: test_health.sh <host-or-ip>}"

curl "http://${HOST}:5000/health"
