class AddControllerTypeToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :controller_type, :integer, default: 0, null: false
    add_column :sites, :username, :string
    add_column :sites, :password, :string
    add_column :sites, :unifi_id, :string
  end
end
