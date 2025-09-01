json.extract! device, :id, :client_id, :last_ap, :mac_address, :site_id, :last_authenticated_at, :last_otp, :authentication_expire_at, :device_name, :radius_enabled, :active, :created_at, :updated_at
json.url admin_client_device_url(device.client, device, format: :json)
