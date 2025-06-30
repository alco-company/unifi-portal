class CreateAdminTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name
      t.string :url
      t.string :login
      t.string :password
      t.string :guest_max
      t.string :guest_rx
      t.string :guest_tx
      t.boolean :active

      t.timestamps
    end
  end
end
