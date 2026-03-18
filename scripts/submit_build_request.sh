#!/usr/bin/env bash
#
# Submits a build request to the Flask API with no auth.
#
# Expected arguments:
#   1. topology_type
#   2. requested_by
#   3. requested_by_email
#   4. booking_id
#   5. booking_start
#   6. booking_end
#   7. booking_duration_hours
#
# Required environment variables:
#   API_BASE_URL

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  submit_build_request.sh \
    <topology_type> \
    <requested_by> \
    <requested_by_email> \
    <booking_id> \
    <booking_start> \
    <booking_end> \
    <booking_duration_hours>

Required environment variables:
  API_BASE_URL
EOF
}

require_env() {
  local var_name="$1"

  if [[ -z "${!var_name:-}" ]]; then
    echo "ERROR: Required environment variable '$var_name' is not set." >&2
    exit 1
  fi
}

validate_args() {
  if [[ "$#" -ne 7 ]]; then
    echo "ERROR: Expected 7 arguments, got $#." >&2
    usage
    exit 1
  fi
}

build_request_payload() {
  local request_file="$1"
  local topology_type="$2"
  local requested_by="$3"
  local requested_by_email="$4"
  local booking_id="$5"
  local booking_start="$6"
  local booking_end="$7"
  local booking_duration_hours="$8"

  cat > "$request_file" <<EOF
{
  "topology_type": "$topology_type",
  "requested_by": "$requested_by",
  "requested_by_email": "$requested_by_email",
  "booking_id": "$booking_id",
  "booking_start": "$booking_start",
  "booking_end": "$booking_end",
  "booking_duration_hours": "$booking_duration_hours"
}
EOF
}

submit_request() {
  local request_file="$1"
  local response_file="$2"

  local http_code

  http_code="$(curl --silent --show-error \
    --write-out "%{http_code}" \
    --request POST "$API_BASE_URL"/build \
    --header "Content-Type: application/json" \
    --data @"$request_file" \
    --output "$response_file"
  )"

  echo "$http_code"
}

main() {
  validate_args "$@"
  require_env 'API_BASE_URL'

  local topology_type="$1"
  local requested_by="$2"
  local requested_by_email="$3"
  local booking_id="$4"
  local booking_start="$5"
  local booking_end="$6"
  local booking_duration_hours="$7"

  local workdir
  workdir="$(mktemp -d)"

  local request_file="$workdir"/request.json
  local response_file="$workdir"/response.json
  local http_code

  build_request_payload \
    "$request_file" \
    "$topology_type" \
    "$requested_by" \
    "$requested_by_email" \
    "$booking_id" \
    "$booking_start" \
    "$booking_end" \
    "$booking_duration_hours"

  echo "Submitting build request to $API_BASE_URL/build ..."
  http_code="$(submit_request "$request_file" "$response_file")"

  echo "HTTP status: $http_code"
  echo "API response body:"
  cat "$response_file"
  echo

  if [[ "$http_code" != '200' ]]; then
    echo "ERROR: API call failed." >&2
    exit 1
  fi

  echo "Build request submitted successfully."
}

main "$@"
