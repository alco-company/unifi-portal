class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.references :client, null: false, foreign_key: true
      t.string :last_ap
      t.string :mac_address
      t.references :site, null: true, foreign_key: true
      t.datetime :last_authenticated_at
      t.string :last_otp
      t.string :unifi_id
      t.datetime :authentication_expire_at
      t.integer :guest_max, default: 0
      t.integer :guest_rx, default: 0
      t.integer :guest_tx, default: 0
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
