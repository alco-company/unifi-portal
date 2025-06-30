json.extract! device, :id, :client_id, :last_ap, :mac_address, :site_id, :last_authenticated_at, :last_otp, :authentication_expire_at, :created_at, :updated_at
json.url device_url(device, format: :json)
