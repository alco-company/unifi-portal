#!/usr/bin/env python3
"""
Test RADIUS authentication against FreeRADIUS server
"""
import socket
import struct
import hashlib
import secrets
import sys

def radius_auth_packet(username, password, secret, nas_ip):
    """Create a RADIUS Access-Request packet"""
    # RADIUS packet structure
    code = 1  # Access-Request
    identifier = secrets.randbelow(256)  # Random identifier
    authenticator = secrets.token_bytes(16)  # Request Authenticator
    
    # Attributes
    attributes = b""
    
    # User-Name attribute (type 1)
    username_bytes = username.encode('utf-8')
    attributes += struct.pack('BB', 1, len(username_bytes) + 2) + username_bytes
    
    # User-Password attribute (type 2) - encrypted
    password_bytes = password.encode('utf-8')
    # Pad password to 16-byte boundary
    padded_password = password_bytes + b'\x00' * (16 - (len(password_bytes) % 16))
    
    # Encrypt password using MD5(shared_secret + Request_Authenticator)
    encrypted_password = b""
    for i in range(0, len(padded_password), 16):
        chunk = padded_password[i:i+16]
        if i == 0:
            hash_input = secret.encode('utf-8') + authenticator
        else:
            hash_input = secret.encode('utf-8') + encrypted_password[i-16:i]
        
        hash_result = hashlib.md5(hash_input).digest()
        encrypted_chunk = bytes(a ^ b for a, b in zip(chunk, hash_result))
        encrypted_password += encrypted_chunk
    
    attributes += struct.pack('BB', 2, len(encrypted_password) + 2) + encrypted_password
    
    # NAS-IP-Address attribute (type 4)
    nas_ip_bytes = socket.inet_aton(nas_ip)
    attributes += struct.pack('BB', 4, 6) + nas_ip_bytes
    
    # NAS-Port attribute (type 5) - must be network byte order
    attributes += struct.pack('!BBL', 5, 6, 1234)  # Port number
    
    # Service-Type attribute (type 6) - Framed-User
    attributes += struct.pack('!BBL', 6, 6, 2)
    
    # Calculate total length
    length = 20 + len(attributes)  # Header (20 bytes) + attributes
    
    # Create packet
    packet = struct.pack('!BBH16s', code, identifier, length, authenticator) + attributes
    
    return packet, identifier

def test_radius_auth(server_ip, server_port, username, password, nas_secret, nas_ip):
    """Test RADIUS authentication"""
    print(f"Testing RADIUS authentication:")
    print(f"  Server: {server_ip}:{server_port}")
    print(f"  Username: {username}")
    print(f"  NAS IP: {nas_ip}")
    print(f"  Secret: {'*' * len(nas_secret)}")
    print()
    
    try:
        # Create socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(10)  # 10 second timeout
        
        # Create RADIUS packet
        packet, identifier = radius_auth_packet(username, password, nas_secret, nas_ip)
        
        print(f"Sending RADIUS Access-Request packet ({len(packet)} bytes)...")
        
        # Send packet
        sock.sendto(packet, (server_ip, server_port))
        
        # Receive response
        response, addr = sock.recvfrom(4096)
        
        print(f"Received response from {addr} ({len(response)} bytes)")
        
        # Parse response
        code, resp_id, length = struct.unpack('!BBH', response[:4])
        
        print(f"Response code: {code}", end=" ")
        if code == 2:
            print("(Access-Accept) - Authentication SUCCESS! ✅")
            return True
        elif code == 3:
            print("(Access-Reject) - Authentication FAILED ❌")
            return False
        else:
            print(f"(Unknown code)")
            return False
            
    except socket.timeout:
        print("❌ TIMEOUT - No response from RADIUS server")
        return False
    except Exception as e:
        print(f"❌ ERROR: {e}")
        return False
    finally:
        sock.close()

if __name__ == "__main__":
    # Configuration
    RADIUS_SERVER = "135.181.202.106"  # FreeRADIUS server
    RADIUS_PORT = 1812
    NAS_SECRET = "ac9288da03e815ce98fb646c1ef2e40c"  # The shared secret for IP 188.228.2.218
    NAS_IP = "188.228.2.218"  # Your IP address
    
    # Test credentials
    USERNAME = "testuser"
    PASSWORD = "testpass123"
    
    print("🔧 RADIUS Authentication Test")
    print("=" * 50)
    
    success = test_radius_auth(RADIUS_SERVER, RADIUS_PORT, USERNAME, PASSWORD, NAS_SECRET, NAS_IP)
    
    print()
    if success:
        print("🎉 RADIUS authentication test PASSED!")
        print("   FreeRADIUS is working correctly with Heimdall API integration.")
    else:
        print("💔 RADIUS authentication test FAILED!")
        print("   Check server logs for more details.")
    
    sys.exit(0 if success else 1)
