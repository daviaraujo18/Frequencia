class AddPunchTypeExplicitToTimeRecords < ActiveRecord::Migration[8.0]
  def change
    # Sprint R (R.5): flag de auditoria — indica se `punch_type` veio explícito
    # do payload da Estação (true) ou foi inferido pelo PunchTypeService (false).
    # default: false garante que os registros históricos (anteriores a esta
    # tarefa) fiquem implicitamente marcados como inferidos, sem quebrar dados existentes.
    add_column :time_records, :punch_type_explicit, :boolean, default: false, null: false
  end
end
