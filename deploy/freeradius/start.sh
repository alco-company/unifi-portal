#!/bin/bash

set -e

: "${HEIMDALL_API_URL:?HEIMDALL_API_URL not set}"
: "${HEIMDALL_API_HOST:?HEIMDALL_API_HOST not set}"

CONFIG_FILE="/etc/raddb/mods-enabled/heimdall"

if [ -f "$CONFIG_FILE" ]; then
  echo "Substituting variables in $CONFIG_FILE"
  esc() { printf '%s' "$1" | sed 's/[&/\]/\\&/g'; }
  url_escaped=$(esc "$HEIMDALL_API_URL")
  host_escaped=$(esc "$HEIMDALL_API_HOST")
  sed -i "s|%{env:HEIMDALL_API_URL}|$url_escaped|g"  "$CONFIG_FILE"
  sed -i "s|%{env:HEIMDALL_API_HOST}|$host_escaped|g" "$CONFIG_FILE"
fi

# Start FreeRADIUS in foreground mode for Docker
echo "Starting FreeRADIUS..."
exec radiusd -f -X -d /etc/raddb 