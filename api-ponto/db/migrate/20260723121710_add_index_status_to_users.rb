class AddIndexStatusToUsers < ActiveRecord::Migration[8.0]
  def change
    add_index :users, :status
  end
end
