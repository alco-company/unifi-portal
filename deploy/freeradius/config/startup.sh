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
apk add --no-cache freeradius freeradius-rest freeradius-radclient curl jq bash

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
rm -rf /usr/share/freeradius/* || true
mkdir -p /etc/freeradius/mods-enabled
mkdir -p /etc/freeradius/sites-enabled
mkdir -p /etc/freeradius/policy.d
mkdir -p /etc/freeradius/mods-config/attr_filter

# Set correct permissions
chown -R nobody:nobody /var/log/radius /var/run/freeradius /var/lib/freeradius
chmod -R 755 /var/log/radius /var/run/freeradius /var/lib/freeradius

# Copy configuration files from mounted volume to FreeRADIUS directory
echo "Copying configuration files..."
if [ -d "/config" ]; then
    # Copy main config - use minimal config first
    if [ -f "/config/minimal_radiusd.conf" ]; then
        cp /config/minimal_radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied minimal_radiusd.conf as radiusd.conf"
    elif [ -f "/config/simple_radiusd.conf" ]; then
        cp /config/simple_radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied simple_radiusd.conf as radiusd.conf"
    elif [ -f "/config/radiusd.conf" ]; then
        cp /config/radiusd.conf /etc/freeradius/radiusd.conf
        echo "- Copied radiusd.conf"
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

# Create basic policy files if they don't exist
echo "Creating basic policy files..."
if [ ! -f "/etc/freeradius/policy.d/filter" ]; then
    cat > /etc/freeradius/policy.d/filter <<'EOF'
# Basic filter policies
filter_username {
    if (&User-Name) {
        if (&User-Name =~ / /) {
            update request {
                &Module-Failure-Message += "Username contains invalid characters"
            }
            reject
        }
    }
}

filter_password {
    if (&User-Password) {
        # Basic password validation can go here
        noop
    }
}
EOF
fi

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
    echo "DEFAULT Reply-Message" > /etc/freeradius/mods-config/attr_filter/access_reject
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
    compat = no
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
    filename = ${modconfdir}/${.:name}/post-proxy
}

attr_filter attr_filter.pre-proxy {
    key = "%{Realm}"
    filename = ${modconfdir}/${.:name}/pre-proxy
}

attr_filter attr_filter.access_reject {
    key = "%{User-Name}"
    filename = ${modconfdir}/${.:name}/access_reject
}

attr_filter attr_filter.access_challenge {
    key = "%{User-Name}"
    filename = ${modconfdir}/${.:name}/access_challenge
}

attr_filter attr_filter.accounting_response {
    key = "%{User-Name}"
    filename = ${modconfdir}/${.:name}/accounting_response
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
# Test user for FreeRADIUS authentication
testuser Cleartext-Password := "testpass123"
    Reply-Message = "Hello %{User-Name}",
    Session-Timeout = 86400

# Default reject
DEFAULT Auth-Type := Reject
    Reply-Message = "Authentication failed"
EOF

# Create clients.conf if it doesn't exist
if [ ! -f "/etc/freeradius/clients.conf" ]; then
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
fi

# Debug - show what configuration files exist
echo "Debug: Configuration files present:"
ls -la /etc/freeradius/ || true
ls -la /etc/freeradius/mods-enabled/ || true
echo "Content of radiusd.conf:"
head -20 /etc/freeradius/radiusd.conf || true

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
