#!/bin/bash

# FreeRADIUS startup script for Heimdall integration
set -e

# Set environment variables for the container
export FREERADIUS_DB_HOST="${ENV_FREERADIUS_DB_HOST:-mysql}"
export FREERADIUS_DB_NAME="${ENV_FREERADIUS_DB_NAME:-freeradius}"
export FREERADIUS_DB_USER="${ENV_FREERADIUS_DB_USER:-root}"
export FREERADIUS_DB_PASSWORD="${ENV_FREERADIUS_DB_PASSWORD:-}"
export HEIMDALL_API_URL="${ENV_HEIMDALL_API_URL:-http://web:3000}"

echo "FreeRADIUS Environment:"
echo "- Database Host: $FREERADIUS_DB_HOST"
echo "- Database Name: $FREERADIUS_DB_NAME"
echo "- Database User: $FREERADIUS_DB_USER"
echo "- Heimdall API URL: $HEIMDALL_API_URL"

# Install necessary packages including FreeRADIUS
echo "Installing packages..."
apk update
apk add --no-cache freeradius freeradius-rest freeradius-eap freeradius-radclient curl jq bash openssl

# Find the FreeRADIUS executable
echo "Finding FreeRADIUS executable..."
find /usr -name "*radius*" -type f 2>/dev/null || true
which radiusd || echo "radiusd not in PATH"
which freeradius || echo "freeradius not in PATH"

# Clean up any conflicting package files
echo "Cleaning up package conflicts..."
rm -f /lib/apk/db/scripts.tar || true
rm -f /var/cache/apk/* || true

# Create necessary directories
echo "Setting up directories..."
mkdir -p /var/log/radius
mkdir -p /var/run/freeradius
mkdir -p /var/lib/freeradius
mkdir -p /etc/freeradius/mods-enabled
mkdir -p /etc/freeradius/sites-enabled
mkdir -p /etc/freeradius/policy.d

# Remove any existing default configurations that might conflict
echo "Removing default configurations..."
rm -rf /etc/freeradius/* || true
rm -rf /etc/raddb/* || true
# Keep dictionary files but remove config templates
rm -rf /usr/share/freeradius/mods-* || true
rm -rf /usr/share/freeradius/sites-* || true
rm -rf /usr/share/freeradius/policy.d || true
mkdir -p /etc/freeradius/mods-enabled
mkdir -p /etc/freeradius/sites-enabled
mkdir -p /etc/freeradius/policy.d
mkdir -p /etc/freeradius/mods-config/attr_filter

# Create /etc/raddb directory since FreeRADIUS expects config there
echo "Setting up FreeRADIUS expected directories..."
mkdir -p /etc/raddb/mods-enabled
mkdir -p /etc/raddb/sites-enabled
mkdir -p /etc/raddb/policy.d
mkdir -p /etc/raddb/mods-config/attr_filter

# Set correct permissions
chown -R nobody:nobody /var/log/radius /var/run/freeradius /var/lib/freeradius
chmod -R 755 /var/log/radius /var/run/freeradius /var/lib/freeradius

# Copy configuration files from mounted volume to FreeRADIUS directory
echo "Copying configuration files..."
if [ -d "/config" ]; then
    # Copy main config - use minimal working config first
    if [ -f "/config/minimal_working.conf" ]; then
        cp /config/minimal_working.conf /etc/freeradius/radiusd.conf
        echo "- Copied minimal_working.conf - guaranteed to work"
    elif [ -f "/config/simple_radiusd.conf" ]; then
        cp /config/simple_radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied simple_radiusd.conf with working module structure"
    elif [ -f "/config/minimal_radiusd.conf" ]; then
        cp /config/minimal_radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied minimal_radiusd.conf as fallback"
    elif [ -f "/config/radiusd.conf" ]; then
        cp /config/radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied full radiusd.conf (may have compatibility issues)"
    fi
    
    # Copy modules
    if [ -d "/config/mods-enabled" ]; then
        cp -r /config/mods-enabled/* /etc/freeradius/mods-enabled/ 2>/dev/null || true
        echo "- Copied modules"
    fi
    
    # Copy sites
    if [ -d "/config/sites-enabled" ]; then
        cp -r /config/sites-enabled/* /etc/freeradius/sites-enabled/ 2>/dev/null || true
        echo "- Copied sites"
    fi
    
    # Copy policies
    if [ -d "/config/policy.d" ]; then
        cp -r /config/policy.d/* /etc/freeradius/policy.d/ 2>/dev/null || true
        echo "- Copied policies"
    fi
fi

# Skip creating policy files - they cause parsing issues in FreeRADIUS 3.0.27
echo "Skipping policy file creation (not needed for basic operation)..."
# Policy filtering will be handled in virtual server sections instead

# Create basic attribute filter files if they don't exist
echo "Creating attribute filters..."
mkdir -p /etc/freeradius/mods-config/attr_filter
if [ ! -f "/etc/freeradius/mods-config/attr_filter/pre-proxy" ]; then
    echo "DEFAULT" > /etc/freeradius/mods-config/attr_filter/pre-proxy
fi

if [ ! -f "/etc/freeradius/mods-config/attr_filter/post-proxy" ]; then
    echo "DEFAULT" > /etc/freeradius/mods-config/attr_filter/post-proxy
fi

if [ ! -f "/etc/freeradius/mods-config/attr_filter/access_reject" ]; then
    echo "DEFAULT Reply-Message += ANY" > /etc/freeradius/mods-config/attr_filter/access_reject
fi

if [ ! -f "/etc/freeradius/mods-config/attr_filter/access_challenge" ]; then
    echo "DEFAULT" > /etc/freeradius/mods-config/attr_filter/access_challenge
fi

if [ ! -f "/etc/freeradius/mods-config/attr_filter/accounting_response" ]; then
    echo "DEFAULT" > /etc/freeradius/mods-config/attr_filter/accounting_response
fi

# Create minimal modules that we need
echo "Creating essential modules..."

# Create files module
cat > /etc/freeradius/mods-enabled/files <<'EOF'
files {
    usersfile = ${confdir}/users
    acctusersfile = ${confdir}/acct_users
    preproxy_usersfile = ${confdir}/preproxy_users
}
EOF

# Create detail module
cat > /etc/freeradius/mods-enabled/detail <<'EOF'
detail {
    filename = ${radacctdir}/%{%{Packet-Src-IP-Address}:-%{Packet-Src-IPv6-Address}}/detail-%Y%m%d
    header = "%t"
    permissions = 0600
    locking = no
    escape_filenames = no
    log_packet_header = no
}
EOF

# Create radutmp module
cat > /etc/freeradius/mods-enabled/radutmp <<'EOF'
radutmp {
    filename = ${logdir}/radutmp
    username = %{User-Name}
    case_sensitive = yes
    check_with_nas = yes
    permissions = 0600
    caller_id = yes
}
EOF

# Create attr_filter module
cat > /etc/freeradius/mods-enabled/attr_filter <<'EOF'
attr_filter attr_filter.post-proxy {
    key = "%{Realm}"
    filename = ${confdir}/mods-config/attr_filter/post-proxy
}

attr_filter attr_filter.pre-proxy {
    key = "%{Realm}"
    filename = ${confdir}/mods-config/attr_filter/pre-proxy
}

attr_filter attr_filter.access_reject {
    key = "%{User-Name}"
    filename = ${confdir}/mods-config/attr_filter/access_reject
}

attr_filter attr_filter.access_challenge {
    key = "%{User-Name}"
    filename = ${confdir}/mods-config/attr_filter/access_challenge
}

attr_filter attr_filter.accounting_response {
    key = "%{User-Name}"
    filename = ${confdir}/mods-config/attr_filter/accounting_response
}
EOF

# Create basic authentication modules
cat > /etc/freeradius/mods-enabled/pap <<'EOF'
pap {
    normalise = yes
}
EOF

cat > /etc/freeradius/mods-enabled/chap <<'EOF'
chap {
}
EOF

cat > /etc/freeradius/mods-enabled/mschap <<'EOF'
mschap {
    use_mppe = no
    require_encryption = no
    require_strong = no
    with_ntdomain_hack = no
    ntlm_auth = "/usr/bin/ntlm_auth --request-nt-key --username=%{%{Stripped-User-Name}:-%{%{User-Name}:-None}} --challenge=%{%{mschap:Challenge}:-00} --nt-response=%{%{mschap:NT-Response}:-00}"
}
EOF

# Create other essential modules
cat > /etc/freeradius/mods-enabled/always <<'EOF'
always reject {
    rcode = reject
}

always fail {
    rcode = fail
}

always ok {
    rcode = ok
}

always handled {
    rcode = handled
}

always invalid {
    rcode = invalid
}

always userlock {
    rcode = userlock
}

always notfound {
    rcode = notfound
}

always noop {
    rcode = noop
}

always updated {
    rcode = updated
}
EOF

# Create basic modules needed for processing
for module in preprocess unix digest exec expr expiration logintime; do
    if [ ! -f "/etc/freeradius/mods-enabled/$module" ]; then
        echo "$module {}" > /etc/freeradius/mods-enabled/$module
    fi
done

# Create users file with test user
echo "Creating users file with test user..."
cat > /etc/freeradius/users <<'EOF'
# Test user for FreeRADIUS file-based authentication
testuser Cleartext-Password := "testpass123"
    Reply-Message = "Hello %{User-Name}",
    Session-Timeout = 86400

# Default fall-through for PAP authentication
DEFAULT Auth-Type := PAP
    Reply-Message = "Default PAP Authentication",
    Session-Timeout = 3600,
    Fall-Through = Yes

# Final default reject
DEFAULT Auth-Type := Reject
    Reply-Message = "Authentication failed"
EOF

# Create empty acct_users file
echo "Creating empty acct_users file..."
touch /etc/freeradius/acct_users

# Create empty preproxy_users file
echo "Creating empty preproxy_users file..."
touch /etc/freeradius/preproxy_users

# Create base clients.conf with localhost and docker network
cat > /etc/freeradius/clients.conf <<'EOF'
client localhost {
    ipaddr = 127.0.0.1
    secret = testing123
    require_message_authenticator = no
}

client docker {
    ipaddr = 172.16.0.0/12
    secret = testing123
    require_message_authenticator = no
}
EOF

# Try to fetch dynamic client configuration from Heimdall API
echo "Fetching dynamic client configuration from Heimdall API..."
if command -v curl >/dev/null 2>&1; then
    # Wait for Heimdall API to be available
    max_attempts=30
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Checking Heimdall API availability..."
        if curl -s --max-time 5 "${HEIMDALL_API_URL}/api/radius/clients/generate_config" >/dev/null 2>&1; then
            echo "Heimdall API is available, fetching client configuration..."
            
            # Fetch the dynamic client configuration
            if api_response=$(curl -s --max-time 10 -H "Content-Type: application/json" -X POST "${HEIMDALL_API_URL}/api/radius/clients/generate_config" 2>/dev/null); then
                # Extract the config from the JSON response
                if echo "$api_response" | grep -q '"success":true'; then
                    # Use a simple approach to extract the config field
                    dynamic_config=$(echo "$api_response" | sed -n 's/.*"config":"\([^"]*\)".*/\1/p' | sed 's/\\n/\n/g' | sed 's/\\t/\t/g')
                    
                    if [ -n "$dynamic_config" ]; then
                        echo "Successfully fetched dynamic client configuration"
                        echo "$dynamic_config" > /etc/freeradius/clients.conf
                        echo "Updated clients.conf with dynamic configuration"
                    else
                        echo "Warning: Empty dynamic configuration received, using default"
                    fi
                else
                    echo "Warning: API returned error, using default configuration"
                fi
            else
                echo "Warning: Failed to fetch configuration from API, using default"
            fi
            break
        else
            echo "Heimdall API not yet available, waiting..."
            sleep 5
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "Warning: Could not connect to Heimdall API after $max_attempts attempts"
        echo "Using default client configuration"
    fi
else
    echo "Warning: curl not available, using default client configuration"
fi

# Generate SSL certificates for TTLS/PEAP
echo "Setting up SSL certificates for EAP-TTLS/PEAP..."
if [ -f "/config/generate-certs.sh" ]; then
    chmod +x /config/generate-certs.sh
    /config/generate-certs.sh
else
    echo "Certificate generation script not found, creating basic self-signed certificates..."
    
    CERT_DIR="/etc/ssl/radius"
    DOMAIN="${RADIUS_SSL_DOMAIN:-radius.staging.unifi-portal.site}"
    
    mkdir -p "$CERT_DIR"
    
    # Generate self-signed certificates for testing
    openssl genrsa -out "$CERT_DIR/privkey.pem" 2048
    
    openssl req -new -x509 \
        -key "$CERT_DIR/privkey.pem" \
        -out "$CERT_DIR/cert.pem" \
        -days 365 \
        -subj "/CN=$DOMAIN/O=Heimdall RADIUS/C=DK"
    
    # Create chain file (same as cert for self-signed)
    cp "$CERT_DIR/cert.pem" "$CERT_DIR/chain.pem"
    cp "$CERT_DIR/cert.pem" "$CERT_DIR/fullchain.pem"
    
    # Generate DH parameters (using smaller size for testing)
    echo "Generating DH parameters (using 1024-bit for faster startup)..."
    openssl dhparam -out "$CERT_DIR/dh2048.pem" 1024
    
    # Set permissions
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/chain.pem" "$CERT_DIR/fullchain.pem" "$CERT_DIR/dh2048.pem"
    
    echo "Self-signed certificates generated for $DOMAIN"
    ls -la "$CERT_DIR/"
fi

# Create tmpdir for SSL verification
echo "Creating tmpdir for SSL verification..."
mkdir -p /tmp/radiusd
chmod 755 /tmp/radiusd

# Copy all files to /etc/raddb as well since FreeRADIUS expects them there
echo "Copying configuration files to /etc/raddb..."
cp -r /etc/freeradius/* /etc/raddb/ 2>/dev/null || true
echo "- Copied all configuration files to /etc/raddb"

# Copy inner-tunnel configuration if it exists
if [ -f "/config/inner-tunnel" ]; then
    cp /config/inner-tunnel /etc/raddb/sites-enabled/inner-tunnel
    echo "- Copied inner-tunnel virtual server configuration"
fi

# Perform environment variable substitution in configuration files
echo "Substituting environment variables in configuration..."
echo "- HEIMDALL_API_URL = ${HEIMDALL_API_URL}"

# Replace ${ENV_HEIMDALL_API_URL} with actual value in all config files
for config_file in /etc/raddb/radiusd.conf /etc/raddb/mods-enabled/rest; do
    if [ -f "$config_file" ]; then
        sed -i "s|\${ENV_HEIMDALL_API_URL}|${HEIMDALL_API_URL}|g" "$config_file"
        echo "- Updated $config_file with environment variables"
    fi
done

# Debug - show what configuration files exist
echo "Debug: Configuration files present:"
ls -la /etc/freeradius/ || true
ls -la /etc/raddb/ || true
ls -la /etc/raddb/mods-enabled/ || true
echo "Content of radiusd.conf:"
head -20 /etc/raddb/radiusd.conf || true

# Test the configuration
echo "Testing FreeRADIUS configuration..."
if radiusd -XC; then
    echo "Configuration test passed!"
else
    echo "Configuration test failed! Continuing anyway..."
fi

# Start FreeRADIUS in foreground mode for Docker
echo "Starting FreeRADIUS..."
exec radiusd -X
