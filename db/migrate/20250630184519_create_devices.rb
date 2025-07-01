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

      t.timestamps
    end
  end
end
