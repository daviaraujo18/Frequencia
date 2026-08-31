module Admin
  class FrequenciaPorOrgaoController < Admin::ApplicationController
    def index
      @registros = registros_por_orgao
    end

    private

    # Agregação simples (Fase A — sem motor de cálculo, isso é Sprint 16+):
    # - "Presenças": dias distintos com pelo menos 1 batida no período
    # - "Ausências": afastamentos (AfastamentoCache, Sprint 12) que começam
    #   no período
    # - "Trabalhado": não computado ainda — exigiria o motor de cálculo
    #   diário (horas entre entrada/saída), que é Fase B (Sprint 16). Fica
    #   "—" por enquanto, não inventado.
    def registros_por_orgao
      orgaos = FrequentadorCache.distinct.where.not(orgao: nil).pluck(:orgao).sort

      if params[:orgao].present?
        orgaos = orgaos.select { |orgao| orgao.downcase.include?(params[:orgao].downcase) }
      end

      orgaos.map { |orgao| linha_do_orgao(orgao) }
    end

    def linha_do_orgao(orgao)
      cpfs = FrequentadorCache.where(orgao: orgao).pluck(:cpf)
      user_ids = User.where(cpf: cpfs).pluck(:id)

      {
        orgao: orgao,
        trabalhado: nil,
        presencas: contar_dias_com_batida(user_ids),
        ausencias: contar_afastamentos(cpfs)
      }
    end

    def contar_dias_com_batida(user_ids)
      registros = TimeRecord.where(user_id: user_ids)
      registros = filtrar_por_periodo(registros, :punched_at)
      registros.pluck(:user_id, Arel.sql("DATE(punched_at)")).uniq.size
    end

    def contar_afastamentos(cpfs)
      afastamentos = AfastamentoCache.where(cpf: cpfs)
      afastamentos = filtrar_por_periodo(afastamentos, :momento_inicial)
      afastamentos.count
    end

    def filtrar_por_periodo(relation, coluna)
      relation = relation.where("EXTRACT(MONTH FROM #{coluna}) = ?", params[:mes]) if params[:mes].present?
      relation = relation.where("EXTRACT(YEAR FROM #{coluna}) = ?", params[:ano]) if params[:ano].present?
      relation
    end
  end
end
