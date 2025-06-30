json.extract! admin_tenant, :id, :name, :url, :login, :password, :guest_max, :guest_rx, :guest_tx, :active, :created_at, :updated_at
json.url admin_tenant_url(admin_tenant, format: :json)
