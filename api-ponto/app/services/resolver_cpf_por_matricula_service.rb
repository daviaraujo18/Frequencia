# Resolve matrícula(s) em CPF a partir da folha de uma competência do
# GestoRH (via sticapi_client) — necessário porque a listagem de servidores
# de uma unidade (SticapiClient::Pessoas.unidade) não traz CPF, só matrícula.
# Ver SPRINT-PLAN.md, Sprint 10B, e docs/integracao-pessoas-sticapi.md.
#
# Não persiste a competência inteira (~4700 registros) no banco — o mapa
# matricula => cpf vive só na memória da instância (escopo de um job).
class ResolverCpfPorMatriculaService
  def self.call(matriculas, mes:, ano:)
    new(mes: mes, ano: ano).call(matriculas)
  end

  # "Competência mais recente" sem hardcode de mês/ano: tenta o mês atual e
  # o mês anterior, mesclando os dois (mês atual tem prioridade quando a
  # matrícula aparece nos dois). Não usa "mês atual vazio? cai pro
  # anterior" simples porque uma competência existir não garante que ela
  # contenha TODAS as matrículas pedidas (ex.: servidor recém-lotado que
  # ainda não caiu na folha do mês atual, mas está na do mês anterior) —
  # ver achado registrado no SPRINT-PLAN.md, Sprint 10B (matrícula do
  # próprio usuário não apareceu na competência de jul/2026).
  def self.mais_recente(matriculas)
    hoje = Time.zone.today
    mes_anterior = hoje.prev_month

    resultado_anterior = call(matriculas, mes: mes_anterior.month, ano: mes_anterior.year)
    resultado_atual = call(matriculas, mes: hoje.month, ano: hoje.year)

    resultado_anterior.merge(resultado_atual)
  end

  def initialize(mes:, ano:)
    @mes = mes
    @ano = ano
  end

  # Retorna um Hash { "matricula" => "cpf" } só com as matrículas pedidas
  # que foram encontradas na competência. Matrícula não encontrada
  # simplesmente não aparece no retorno (chamador decide o que fazer).
  def call(matriculas)
    matriculas_normalizadas = matriculas.map(&:to_s)
    mapa_completo.slice(*matriculas_normalizadas)
  end

  private

  def mapa_completo
    @mapa_completo ||= begin
      folha = SticapiClient::Gestorh.competencia(mes: @mes, ano: @ano)
      Array(folha).each_with_object({}) do |pessoa, memo|
        matricula = pessoa["matricula"]
        cpf = pessoa["cpf"]
        memo[matricula.to_s] = cpf if matricula.present? && cpf.present?
      end
    end
  end
end
