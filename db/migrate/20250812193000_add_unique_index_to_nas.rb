class AddUniqueIndexToNas < ActiveRecord::Migration[8.1]
  def change
    add_index :nas, [ :site_id, :nasname ], unique: true
  end
end
