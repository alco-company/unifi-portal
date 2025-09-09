class AddQrCodeToSites < ActiveRecord::Migration[8.1]
  def change
    add_column :sites, :slug, :string
    add_column :sites, :qr_code_data, :text
  end
end
