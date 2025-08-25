#!/bin/sh

# Install required packages
apk add --no-cache freeradius freeradius-mysql freeradius-radclient mysql-client

# Remove default configuration files that conflict with our mounted configuration
rm -f /etc/raddb/mods-enabled/sql.apk-new
rm -f /etc/raddb/mods-config/sql/main/sqlite/queries.conf

# Remove conflicting sites-enabled and policy.d directories
if [ -d "/etc/raddb/sites-enabled" ]; then
  rm -rf /etc/raddb/sites-enabled/*
fi

if [ -d "/etc/raddb/policy.d" ]; then
  rm -rf /etc/raddb/policy.d
fi

# Create log directory and set permissions
mkdir -p /var/log/freeradius
chown nobody:nobody /var/log/freeradius

# Copy our configuration files to the correct locations
cp /tmp/radiusd.conf /etc/raddb/radiusd.conf
cp /tmp/default /etc/raddb/sites-enabled/default

# Process SQL config and substitute environment variables
sed "s/\${MYSQL_PASSWORD}/$MYSQL_PASSWORD/g" /tmp/sql > /etc/raddb/mods-enabled/sql

# Enable the PAP module that's needed for authentication
cp /etc/raddb/mods-available/pap /etc/raddb/mods-enabled/pap

# Start FreeRADIUS in debug mode
exec radiusd -X -f
