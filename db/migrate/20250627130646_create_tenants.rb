class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :name
      t.string :url
      t.integer :guest_max, default: 0
      t.integer :guest_rx, default: 0
      t.integer :guest_tx, default: 0
      t.boolean :active, default: true
      t.text :note

      t.timestamps
    end
  end
end
