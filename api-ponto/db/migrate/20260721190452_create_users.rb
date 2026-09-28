class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :nome_completo, null: false
      t.string :username, null: false
      t.string :password_digest, null: false
      t.integer :status, null: false, default: 1
      t.text :digitais_hash

      t.timestamps
    end
    add_index :users, :username, unique: true
  end
end
