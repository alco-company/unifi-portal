class CreateNas < ActiveRecord::Migration[8.1]
  def change
    create_table :nas do |t|
      t.references :site, null: false, foreign_key: true
      t.string :nasname
      t.string :shortname
      t.string :type
      t.string :ports
      t.string :secret
      t.string :server
      t.string :community
      t.string :description

      t.timestamps
    end
  end
end
