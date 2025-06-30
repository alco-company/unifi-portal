json.extract! client, :id, :tenant_id, :name, :email, :phone, :guest_max, :guest_rx, :guest_tx, :active, :created_at, :updated_at
json.url client_url(client, format: :json)
