#!/bin/bash

echo "...setting environment variables"
# Replace ${ENV_HEIMDALL_API_URL} with actual value in all config files
for config_file in /etc/raddb/mods-enabled/heimdall; do
    if [ -f "$config_file" ]; then
        pattern='%{env:HEIMDALL_API_URL}'
        replacement=$(printf '%s' "$HEIMDALL_API_URL" | sed -e 's/[&|\\/]/\\&/g')
        sed -i '' "s|$pattern|$replacement|g" "$config_file"
        pattern='%{env:HEIMDALL_API_HOST}'
        replacement=$(printf '%s' "$HEIMDALL_API_HOST" | sed -e 's/[&|\\/]/\\&/g')
        sed -i '' "s|$pattern|$replacement|g" "$config_file"
    fi
done

# Start FreeRADIUS in foreground mode for Docker
# echo "Starting FreeRADIUS..."
# exec radiusd -X
# 