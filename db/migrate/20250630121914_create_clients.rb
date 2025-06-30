class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.string :phone
      t.integer :guest_max
      t.integer :guest_rx
      t.integer :guest_tx
      t.boolean :active

      t.timestamps
    end
  end
end
