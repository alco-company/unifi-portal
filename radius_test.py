#!/usr/bin/env python3

import pyrad.packet
from pyrad.client import Client
from pyrad.dictionary import Dictionary
import pyrad.packet
import sys

def test_radius_auth(server_ip, port, secret, username, password):
    """Test RADIUS authentication against a server."""
    
    # Create a simple dictionary in memory
    dict_data = """
ATTRIBUTE	User-Name				1	string
ATTRIBUTE	User-Password				2	string
ATTRIBUTE	Reply-Message				18	string
ATTRIBUTE	Session-Timeout				27	integer
ATTRIBUTE	NAS-IP-Address				4	ipaddr
ATTRIBUTE	Service-Type				6	integer

VALUE	Service-Type	Login-User		1
VALUE	Service-Type	Framed-User		2
"""
    
    # Create dictionary file temporarily
    with open('/tmp/radius_dict', 'w') as f:
        f.write(dict_data)
    
    try:
        # Load the dictionary
        dictionary = Dictionary('/tmp/radius_dict')
        
        # Create RADIUS client
        client = Client(server=server_ip, 
                       secret=secret.encode(), 
                       dict=dictionary,
                       authport=port,
                       timeout=5)  # 5 second timeout
        
        # Create access request
        request = client.CreateAuthPacket(code=pyrad.packet.AccessRequest)
        request["User-Name"] = username
        request["User-Password"] = request.PwCrypt(password)
        request["NAS-IP-Address"] = "127.0.0.1"
        
        print(f"Sending RADIUS Access-Request to {server_ip}:{port}")
        print(f"Username: {username}")
        print(f"Password: {'*' * len(password)}")
        print("Waiting for response...")
        print()
        
        # Send the request
        try:
            response = client.SendPacket(request)
        except Exception as send_error:
            print(f"Network error sending packet: {send_error}")
            raise
        
        # Process the response
        if response.code == pyrad.packet.AccessAccept:
            print("✅ Authentication SUCCESS - Access-Accept received")
            if "Reply-Message" in response:
                print(f"   Reply-Message: {response['Reply-Message'][0]}")
            if "Session-Timeout" in response:
                print(f"   Session-Timeout: {response['Session-Timeout'][0]} seconds")
            return True
        elif response.code == pyrad.packet.AccessReject:
            print("❌ Authentication FAILED - Access-Reject received")
            if "Reply-Message" in response:
                print(f"   Reply-Message: {response['Reply-Message'][0]}")
            return False
        else:
            print(f"⚠️  Unexpected response code: {response.code}")
            return False
            
    except Exception as e:
        print(f"❌ Error testing RADIUS: {e}")
        return False
    finally:
        # Clean up temporary dictionary file
        import os
        if os.path.exists('/tmp/radius_dict'):
            os.remove('/tmp/radius_dict')

if __name__ == "__main__":
    # Test configuration - using proper secret for external IP 188.228.2.218
    SERVER_IP = "135.181.202.106"
    PORT = 1812
    SECRET = "ac9288da03e815ce98fb646c1ef2e40c"
    
    print("🔄 Testing RADIUS Authentication on 135.181.202.106:1812")
    print("=" * 60)
    
    # Test 1: Valid credentials
    print("Test 1: Valid credentials (should succeed)")
    success1 = test_radius_auth(SERVER_IP, PORT, SECRET, "testuser", "testpass123")
    
    print()
    print("-" * 60)
    print()
    
    # Test 2: Invalid credentials  
    print("Test 2: Invalid credentials (should fail)")
    success2 = test_radius_auth(SERVER_IP, PORT, SECRET, "testuser", "wrongpassword")
    
    print()
    print("=" * 60)
    print("Summary:")
    print(f"✅ Valid auth test:   {'PASSED' if success1 else 'FAILED'}")
    print(f"❌ Invalid auth test: {'PASSED' if not success2 else 'FAILED'}")
    
    if success1 and not success2:
        print("\n🎉 RADIUS server is working correctly!")
        print("   - Accepts valid credentials")
        print("   - Rejects invalid credentials")
        print("   - Port 1812 is accessible externally")
    else:
        print("\n⚠️  RADIUS server may have issues")
