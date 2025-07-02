class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name
      t.string :email
      t.string :phone
      t.string :password_digest
      t.boolean :superuser
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
