json.extract! site, :id, :tenant_id, :name, :url, :ssid, :api_key, :controller_url, :active, :created_at, :updated_at
json.url site_url(site, format: :json)
