
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
  def stub_unifi_sites_api(base_url = "https://localhost:3000")
    stub_request(:get, %r{#{base_url}/proxy/network/integration/v1/sites})
      .to_return(status: 200, body: { 
          "offset": 0,
          "limit": 25,
          "count": 1,
          "totalCount": 1,
          "data": [
              {
                  "id": "test-site-id",
                  "internalReference": "default",
                  "name": "Default"
              }
          ]
        }.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_unifi_client_api(mac_address, base_url = "https://localhost:3000")
    stub_request(:get, %r{#{base_url}/proxy/network/integration/v1/clients\?filter=macAddress\.eq\('#{Regexp.escape(mac_address)}'\)})
      .to_return(status: 200, body: [{ id: "test-client-id", mac: mac_address }].to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_guest_authorization_api(base_url = "https://localhost:3000")
    stub_request(:post, %r{#{base_url}/proxy/network/integration/v1/actions})
      .to_return(status: 200, body: { result: "ok" }.to_json, headers: { "Content-Type" => "application/json" })
  end
end
