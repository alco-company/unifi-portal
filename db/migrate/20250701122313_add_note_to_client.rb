class AddNoteToClient < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :note, :text
  end
end
