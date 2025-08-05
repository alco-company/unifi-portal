
# test/support/unifi_api_stubs.rb
module UnifiApiStubs
  #
  def stub_unifi_sites_login(unifi_id, base_url = "https://heimdall.test")
    body = {
      "meta": {
          "rc": "ok"
      },
      "data": [
        {
            "anonymous_id": "b77568ac-02ea-44ac-9939-a16619fd7d88",
            "name": "default",
            "external_id": "88f7af54-98f8-306a-a1c7-c9349722b1f6",
            "_id": "67f8dc74d97ad01d7c2fb5f4",
            "attr_no_delete": true,
            "attr_hidden_id": "default",
            "desc": "Default",
            "role": "admin",
            "device_count": 0
        },
        {
            "anonymous_id": "3ef9f818-4789-455b-a6dd-6a69bf5d4316",
            "name": "8xff0x6m",
            "external_id": "19d9aa6d-5b43-3ee7-ae18-d92d0f9360f3",
            "_id": "6803b1a107ae330ef4d6f5b8",
            "desc": "Thisted-Gymnasium_Linux",
            "role": "admin",
            "device_count": 68
        }
      ]
    }

    stub_request(:get, "https://heimdall.test/api/self/sites")
      .with(
        headers: {
          "Accept"=>"application/json",
          "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Content-Type"=>"application/json",
          "Cookie"=>"test_cookie",
          "User-Agent"=>"Ruby"
        })
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_unifi_client_login(mac_address, site_id = "88f7af54-98f8-306a-a1c7-c9349722b1f6", base_url = "https://heimdall.test")
    body = {
      "meta": {
          "rc": "ok"
      },
      "data": [
        {
          "site_id": "6803b1a107ae330ef4d6f5b8",
          "ap_mac": "ac:8b:a9:21:64:0d",
          "assoc_time": 1751760044,
          "latest_assoc_time": 1751760044,
          "oui": "Hui Zhou Gaoshengda Technology Co.,LTD",
          "user_id": "6821a79e0d906a5a0c7c2537",
          "last_ip": "10.20.2.103",
          "last_uplink_name": "57",
          "first_seen": 1747036062,
          "last_seen": 1752221165,
          "is_guest": false,
          "disconnect_timestamp": 1751760043,
          "last_radio": "na",
          "is_wired": false,
          "usergroup_id": "",
          "last_uplink_mac": "ac:8b:a9:21:64:0d",
          "last_connection_network_name": "Default",
          "mac": "4c:50:dd:da:e3:dd",
          "last_connection_network_id": "6803b1a107ae330ef4d71283",
          "hostname": "It",
          "_id": "6821a79e0d906a5a0c7c2537",
          "wlanconf_id": "6803b1a107ae330ef4d7127a",
          "_uptime_by_uap": 461121,
          "_last_seen_by_uap": 1752221165,
          "_is_guest_by_uap": false,
          "channel": 60,
          "channelWidth": 40,
          "radio": "na",
          "radio_name": "rai0",
          "essid": "ATV",
          "bssid": "ae:8b:a9:11:64:0f",
          "powersave_enabled": true,
          "is_11r": false,
          "user_group_id_computed": "6803b1a107ae330ef4d712b2",
          "anomalies": 0,
          "anon_client_id": "b4e9e72104e32e3d0a5f60e942faa6",
          "ccq": 0,
          "dhcpend_time": 185475794,
          "idletime": 3,
          "noise": -96,
          "nss": 2,
          "rx_rate": 6000,
          "rssi": 33,
          "satisfaction_now": 100,
          "satisfaction_real": 100,
          "satisfaction_reason": 0,
          "signal": -63,
          "tx_mcs": 7,
          "tx_power": 0,
          "tx_rate": 270000,
          "tx_retry_burst_count": 387,
          "satisfaction": 100,
          "hostname_source": "uap",
          "is_mlo": false,
          "radio_proto": "ac",
          "channel_width": 40,
          "satisfaction_avg": {
              "total": 1848427,
              "count": 18515
          },
          "uptime": 461121,
          "tx_bytes": 8823820,
          "rx_bytes": 21730459,
          "tx_packets": 54113,
          "rx_packets": 107079,
          "tx_retries": 952,
          "wifi_tx_attempts": 48408,
          "wifi_tx_dropped": 0,
          "wifi_tx_retries_percentage": 0.0,
          "qos_policy_applied": true,
          "_uptime_by_ugw": 3135689,
          "_last_seen_by_ugw": 1752221162,
          "_is_guest_by_ugw": false,
          "ip": "10.20.2.103",
          "gw_mac": "e4:38:83:62:74:f0",
          "gw_vlan": 1,
          "network": "Default",
          "network_id": "6803b1a107ae330ef4d71283",
          "_last_reachable_by_gw": 1752221155,
          "bytes-r": 27.41648461349267,
          "tx_bytes-r": 2.879092579464402,
          "rx_bytes-r": 24.53739203402827,
          "_uptime_by_usw": 3135689,
          "_last_seen_by_usw": 1752221162,
          "_is_guest_by_usw": false
        }
      ]
    }
    stub_request(:get, "https://heimdall.test/api/s/default/stat/sta/1c:71:25:63:e4:24")
      .with(
        headers: {
          "Accept"=>"application/json",
          "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Content-Type"=>"application/json",
          "Cookie"=>"test_cookie",
          "User-Agent"=>"Ruby"
        })
      .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_unifi_authorize_login(unifi_id, base_url = "https://heimdall.test")
    stub_request(:post, "https://heimdall.test/api/s/default/cmd/stamgr").
      with(
        body: "{\"cmd\":\"authorize-guest\",\"mac\":\"1c:71:25:63:e4:24\",\"minutes\":1440,\"up\":1,\"down\":1,\"bytes\":1048576}",
        headers: {
          "Accept"=>"application/json",
          "Accept-Encoding"=>"gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Content-Type"=>"application/json",
          "Cookie"=>"test_cookie",
          "User-Agent"=>"Ruby"
        }).
      to_return(status: 200, body: "", headers: { "Content-Type" => "application/json" })
  end
end
