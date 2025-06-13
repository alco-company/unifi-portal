class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :url
      t.string :ssid
      t.string :api_key
      t.string :controller_id
      t.string :controller_url

      t.timestamps
    end
  end
end
