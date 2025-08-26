#!/bin/bash

# FreeRADIUS Certificate Generation Script
# Based on official FreeRADIUS raddb/certs structure
# Generates proper CA + Server certificate chain for EAP-TLS/PEAP

set -e

CERT_DIR="/etc/ssl/radius"
DOMAIN="${RADIUS_SSL_DOMAIN:-radius.staging.unifi-portal.site}"

echo "Generating FreeRADIUS certificates for domain: $DOMAIN"

# Create certificate directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Create index and serial files for CA
touch index.txt
echo '01' > serial

# Create CA configuration
cat > ca.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ./
certs = \$dir
crl_dir = \$dir/crl
database = \$dir/index.txt
new_certs_dir = \$dir
certificate = \$dir/ca.pem
serial = \$dir/serial
crl = \$dir/crl.pem
private_key = \$dir/ca.key
RANDFILE = \$dir/.rand
name_opt = ca_default
cert_opt = ca_default
default_days = 365
default_crl_days = 30
default_md = sha256
preserve = no
policy = policy_match

[ policy_match ]
countryName = match
stateOrProvinceName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ req ]
prompt = no
distinguished_name = certificate_authority
default_bits = 2048
input_password = ""
output_password = ""
x509_extensions = v3_ca

[certificate_authority]
countryName = DK
stateOrProvinceName = Capital
localityName = Copenhagen
organizationName = Heimdall RADIUS
emailAddress = admin@staging.unifi-portal.site
commonName = "Heimdall RADIUS Certificate Authority"

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints = critical,CA:true
keyUsage = keyCertSign, cRLSign
EOF

# Create Server configuration
cat > server.cnf <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ./
certs = \$dir
crl_dir = \$dir/crl
database = \$dir/index.txt
new_certs_dir = \$dir
certificate = \$dir/server.pem
serial = \$dir/serial
crl = \$dir/crl.pem
private_key = \$dir/server.key
RANDFILE = \$dir/.rand
name_opt = ca_default
cert_opt = ca_default
default_days = 365
default_crl_days = 30
default_md = sha256
preserve = no
policy = policy_match
copy_extensions = copy

[ policy_match ]
countryName = match
stateOrProvinceName = match
organizationName = match
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ req ]
prompt = no
distinguished_name = server
default_bits = 2048
input_password = ""
output_password = ""
req_extensions = v3_req

[server]
countryName = DK
stateOrProvinceName = Capital
localityName = Copenhagen
organizationName = Heimdall RADIUS
emailAddress = admin@staging.unifi-portal.site
commonName = "$DOMAIN"

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
subjectKeyIdentifier = hash

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = radius.staging.unifi-portal.site
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

# Create X.509 extensions file for proper EAP usage
cat > xpextensions <<EOF
[ xpserver_ext ]
extendedKeyUsage = 1.3.6.1.5.5.7.3.1
keyUsage = digitalSignature, keyEncipherment
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
# Trust Override Disabled - TOFU policy for WPA3 compliance
certificatePolicies = 1.3.6.1.4.1.40808.1.3.2
EOF

echo "Step 1: Generating Certificate Authority (CA)..."

# Generate CA private key and certificate
openssl req -new -x509 -keyout ca.key -out ca.pem \
    -days 365 -config ./ca.cnf \
    -passin pass: -passout pass:

echo "Step 2: Generating Server private key and certificate request..."

# Generate server private key and certificate signing request
openssl req -new -out server.csr -keyout server.key -config ./server.cnf
chmod 640 server.key

echo "Step 3: Signing server certificate with CA..."

# Sign server certificate with CA
openssl ca -batch -keyfile ca.key -cert ca.pem -in server.csr \
    -key "" -out server.crt \
    -extensions xpserver_ext -extfile xpextensions \
    -config ./server.cnf

echo "Step 4: Creating PEM format files..."

# Create server certificate in PEM format (includes private key)
cat server.crt server.key > server.pem
chmod 640 server.pem

# Create certificate chain file
cat server.crt ca.pem > cert.pem
cp server.key privkey.pem
cp ca.pem chain.pem

echo "Step 5: Generating Diffie-Hellman parameters (1024-bit for speed)..."

# Generate DH parameters (1024-bit for faster startup in testing)
openssl dhparam -out dh2048.pem 1024

echo "Step 6: Setting proper permissions..."

# Set correct permissions
chmod 640 ca.key server.key privkey.pem server.pem
chmod 644 ca.pem server.crt cert.pem chain.pem dh2048.pem

# Clean up temporary files
rm -f server.csr

echo "Certificate generation complete!"
echo "Generated files:"
echo "  CA Certificate: ca.pem"
echo "  Server Certificate: server.crt"
echo "  Server Private Key: server.key"
echo "  Server PEM (cert+key): server.pem" 
echo "  Certificate Chain: cert.pem"
echo "  Private Key: privkey.pem"
echo "  CA Chain: chain.pem"
echo "  DH Parameters: dh2048.pem"

# Verify certificates
echo ""
echo "Verifying certificate chain..."
openssl verify -CAfile ca.pem server.crt
echo "Certificate verification successful!"

# Show certificate details
echo ""
echo "Server Certificate Details:"
openssl x509 -in server.crt -noout -subject -issuer -dates -purpose | head -10
