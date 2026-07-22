class AddPunchTypeToTimeRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :time_records, :punch_type, :string
  end
end
