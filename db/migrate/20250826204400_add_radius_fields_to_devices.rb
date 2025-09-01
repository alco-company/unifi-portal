class AddRadiusFieldsToDevices < ActiveRecord::Migration[8.1]
  def change
    add_column :devices, :radius_enabled, :boolean, default: false
    add_column :devices, :radius_username, :string
    add_column :devices, :radius_password_hash, :string
    add_column :devices, :radius_last_auth_at, :datetime
    add_column :devices, :radius_auth_failures, :integer, default: 0
    add_column :devices, :radius_locked_until, :datetime
    add_column :devices, :otp_expires_at, :datetime
    add_column :devices, :device_name, :string # User-friendly device name
    
    add_index :devices, :radius_username, unique: true
    add_index :devices, :radius_enabled
  end
end
