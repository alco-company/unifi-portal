#!/bin/sh

# Certificate generation script for FreeRADIUS
# First tries to use existing Let's Encrypt certificates, then falls back to self-signed

CERT_DIR="/etc/ssl/radius"
DOMAIN="${RADIUS_SSL_DOMAIN:-radius.staging.unifi-portal.site}"

# Create certificate directory
mkdir -p "$CERT_DIR"

# Check if Let's Encrypt certificates exist (from Kamal proxy setup)
# First try the specific RADIUS domain
LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"

# If RADIUS-specific cert doesn't exist, try to use the main domain cert
if [ ! -d "$LETSENCRYPT_DIR" ]; then
    MAIN_DOMAIN="staging.unifi-portal.site"
    LETSENCRYPT_DIR="/etc/letsencrypt/live/$MAIN_DOMAIN"
    echo "RADIUS-specific certificate not found, trying main domain: $MAIN_DOMAIN"
fi

if [ -d "$LETSENCRYPT_DIR" ]; then
    echo "Using Let's Encrypt certificates for $DOMAIN"
    
    # Copy Let's Encrypt certificates
    cp "$LETSENCRYPT_DIR/privkey.pem" "$CERT_DIR/privkey.pem"
    cp "$LETSENCRYPT_DIR/cert.pem" "$CERT_DIR/cert.pem" 
    cp "$LETSENCRYPT_DIR/chain.pem" "$CERT_DIR/chain.pem"
    cp "$LETSENCRYPT_DIR/fullchain.pem" "$CERT_DIR/fullchain.pem"
    
    # Set permissions
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/chain.pem" "$CERT_DIR/fullchain.pem"
    
    echo "Let's Encrypt certificates installed successfully"
else
    echo "Let's Encrypt certificates not found, generating self-signed certificates"
    
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
    
    # Set permissions
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/cert.pem" "$CERT_DIR/chain.pem" "$CERT_DIR/fullchain.pem"
    
    echo "Self-signed certificates generated for $DOMAIN"
fi

# Generate DH parameters if they don't exist
if [ ! -f "$CERT_DIR/dh2048.pem" ]; then
    echo "Generating DH parameters (this may take a while)..."
    openssl dhparam -out "$CERT_DIR/dh2048.pem" 2048
    chmod 644 "$CERT_DIR/dh2048.pem"
    echo "DH parameters generated"
fi

echo "Certificate setup completed"
ls -la "$CERT_DIR/"
