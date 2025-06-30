class ChangeTenant < ActiveRecord::Migration[8.1]
  def change
    remove_column :tenants, :guest_max, :integer
    remove_column :tenants, :guest_rx, :integer
    remove_column :tenants, :guest_tx, :integer
    remove_column :tenants, :url, :string
  end
end
