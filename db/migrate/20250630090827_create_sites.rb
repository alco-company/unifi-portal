class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name
      t.string :url
      t.string :ssid
      t.string :api_key
      t.string :controller_url
      t.integer :guest_max, default: 0, null: false
      t.integer :guest_rx, default: 0, null: false
      t.integer :guest_tx, default: 0, null: false
      t.boolean :active

      t.timestamps
    end
  end
end
