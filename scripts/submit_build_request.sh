#!/usr/bin/env bash
#
# Submits a build request to the Ansible Flask API using an SSO-issued token.
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
#   IDP_TOKEN_URL
#   CLIENT_ID
#   CLIENT_SECRET
#   API_SCOPE

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  submit_build_request_sso.sh \
    <topology_type> \
    <requested_by> \
    <requested_by_email> \
    <booking_id> \
    <booking_start> \
    <booking_end> \
    <booking_duration_hours>
Required environment variables:
  API_BASE_URL
  IDP_TOKEN_URL
  CLIENT_ID
  CLIENT_SECRET
  API_SCOPE
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

get_access_token() {
  local token_response_file="$1"

  local http_code
  http_code="$(
    curl \
      --silent \
      --show-error \
      --output         "$token_response_file" \
      --write-out      "%{http_code}" \
      --request POST   "$IDP_TOKEN_URL" \
      --header         "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=$CLIENT_ID" \
      --data-urlencode "client_secret=$CLIENT_SECRET" \
      --data-urlencode "scope=$API_SCOPE"
  )"

  if [[ "$http_code" != '200' ]]; then
    echo "ERROR: Failed to obtain access token. HTTP status: $http_code" >&2
    cat "$token_response_file" >&2
    echo >&2
    exit 1
  fi

  jq -r '.access_token' "$token_response_file"
}

submit_request() {
  local request_file="$1"
  local response_file="$2"
  local access_token="$3"

  local http_code

  http_code="$(curl --silent --show-error \
    --write-out "%{http_code}" \
    --request POST "$API_BASE_URL"/build \
    --header  "Content-Type: application/json" \
    --header  "Authorization: Bearer $access_token" \
    --data    @"$request_file" \
    --output  "$response_file"
  )"

  echo "$http_code"
}

main() {
  validate_args "$@"

  require_env 'API_BASE_URL'
  require_env 'IDP_TOKEN_URL'
  require_env 'CLIENT_ID'
  require_env 'CLIENT_SECRET'
  require_env 'API_SCOPE'

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
  local token_response_file="$workdir"/token_response.json
  local response_file="$workdir"/response.json
  local access_token
  local http_code

  trap 'rm -rf "$workdir"' EXIT

  build_request_payload \
    "$request_file" \
    "$topology_type" \
    "$requested_by" \
    "$requested_by_email" \
    "$booking_id" \
    "$booking_start" \
    "$booking_end" \
    "$booking_duration_hours"

  echo "Requesting SSO access token..."
  access_token="$(get_access_token "$token_response_file")"

  echo "Submitting build request to $API_BASE_URL/build ..."
  http_code="$(submit_request "$request_file" "$response_file" "$access_token")"

  echo "HTTP status: $http_code"

  echo "API response body:"
  cat "$response_file"

  if [[ "$http_code" != '200' ]]; then
    echo "ERROR: API call failed." >&2
    exit 1
  fi

  echo "Build request submitted successfully."
}

main "$@"
