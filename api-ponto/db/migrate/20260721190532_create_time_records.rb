class CreateTimeRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :time_records do |t|
      t.references :user, null: false, foreign_key: true
      t.string :raw_data
      t.datetime :punched_at
      t.string :authentication_mode

      t.timestamps
    end
    add_index :time_records, :punched_at
  end
end
