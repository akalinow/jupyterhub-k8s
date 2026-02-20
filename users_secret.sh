#!/usr/bin/env bash
set -euo pipefail

# Create/update allowed users secret for JupyterHub.
# Usage: bash allowed_users.sh path/to/users.json
USERS_FILE="${1:-users.json}"

if [[ ! -f "$USERS_FILE" ]]; then
  echo "Users file not found: $USERS_FILE" >&2
  exit 1
fi

ADMIN_USER="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(data.get("admin", ""))' "$USERS_FILE")"
USERS_JSON="$(python3 -c 'import json,sys; data=json.load(open(sys.argv[1])); print(json.dumps(data.get("users", [])))' "$USERS_FILE")"

if [[ -z "$ADMIN_USER" ]]; then
  echo "Admin user not found in $USERS_FILE" >&2
  exit 1
fi

USERS_TMP="$(mktemp)"
trap 'rm -f "$USERS_TMP"' EXIT
printf '%s' "$USERS_JSON" > "$USERS_TMP"

kubectl create secret generic allowed_users \
	--from-file=users="$USERS_TMP" \
	--from-literal=admin="$ADMIN_USER" \
	--dry-run=client -o yaml | kubectl apply -f -

