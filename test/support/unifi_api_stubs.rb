
# test/support/unifi_api_stubs.rb
module UnifiApiStubs
  # {
  #   "offset": 0,
  #   "limit": 25,
  #   "count": 1,
  #   "totalCount": 1,
  #   "data": [
  #       {
  #           "id": "88f7af54-98f8-306a-a1c7-c9349722b1f6",
  #           "internalReference": "default",
  #           "name": "Default"
  #       }
  #   ]
  # }
  def stub_unifi_sites_api(unifi_id, base_url = "https://heimdall.test")
    stub_request(:get, %r{#{base_url}/proxy/network/integration/v1/sites\z})
      .to_return(status: 200, body: {
          "offset": 0,
          "limit": 25,
          "count": 1,
          "totalCount": 1,
          "data": [
              {
                  "id": unifi_id,
                  "internalReference": "default",
                  "name": "Default"
              }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_unifi_client_api(mac_address, site_id = "88f7af54-98f8-306a-a1c7-c9349722b1f6", base_url = "https://heimdall.test")
    regex = %r{#{base_url}/proxy/network/integration/v1/sites/#{site_id}/clients\?filter=macAddress\.eq\('#{mac_address}'\)}
    stub_request(:get, regex)
      .to_return(status: 200, body: {
        "offset": 0,
        "limit": 25,
        "count": 1,
        "totalCount": 421,
        "data": [
          {
            "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
            "name": "string",
            "connectedAt": "2019-08-24T14:15:22Z",
            "ipAddress": "string",
            "access": {
              "type": "DEFAULT"
            },
            "type": "string"
          }
        ]
      }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_guest_authorization_api(base_url = "https://heimdall.test", site_id: "88f7af54-98f8-306a-a1c7-c9349722b1f6", client_id: "497f6eca\-6276\-4993\-bfeb\-53cbbbba6f08", api_key: "test-api-key")
    stub_request(:post, %r{#{base_url}/proxy/network/integration/v1/sites/#{site_id}/clients/#{client_id}/actions})
      .to_return(status: 200, body: {
        "action": "AUTHORIZE_GUEST_ACCESS",
        "revokedAuthorization": {
          "authorizedAt": "2019-08-24T14:15:22Z",
          "authorizationMethod": "VOUCHER",
          "expiresAt": "2019-08-24T14:15:22Z",
          "dataUsageLimitMBytes": 1024,
          "rxRateLimitKbps": 1000,
          "txRateLimitKbps": 1000,
          "usage": {
            "durationSec": 0,
            "rxBytes": 0,
            "txBytes": 0,
            "bytes": 0
          }
        },
        "grantedAuthorization": {
          "authorizedAt": "2019-08-24T14:15:22Z",
          "authorizationMethod": "VOUCHER",
          "expiresAt": "2019-08-24T14:15:22Z",
          "dataUsageLimitMBytes": 1024,
          "rxRateLimitKbps": 1000,
          "txRateLimitKbps": 1000,
          "usage": {
            "durationSec": 0,
            "rxBytes": 0,
            "txBytes": 0,
            "bytes": 0
          }
        }
      }.to_json, headers: { "Content-Type" => "application/json" })
  end
end
