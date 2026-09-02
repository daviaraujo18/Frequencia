# Tabela `vinculos`. Só as colunas/associações usadas pelo Frequencia:
# matrícula, estado do vínculo, lotações e tipo de vínculo (via
# configuração de cadastro). O model original do pessoas2 tem dezenas de
# `belongs_to`/`has_one` (esocial, cargo, conta bancária etc.) que não nos
# interessam aqui.
module Pessoas
  class Vinculo < PessoasRecord
    self.table_name = "vinculos"

    belongs_to :pessoa, class_name: "Pessoas::Pessoa", inverse_of: :vinculos
    belongs_to :vinculo_estado, class_name: "Pessoas::VinculoEstado", optional: true
    belongs_to :configuracao_cadastro, class_name: "Pessoas::ConfiguracaoCadastro", optional: true

    has_many :lotacoes, class_name: "Pessoas::Lotacao", foreign_key: :vinculo_id, inverse_of: :vinculo
    has_many :afastamentos, class_name: "Pessoas::Afastamento", foreign_key: :vinculo_id, inverse_of: :vinculo

    # Espelha o antigo filtro `vinculos_ativos` da Sticapi: estado
    # "em_exercicio" (nome confirmado em `vinculos_estados`, ver
    # investigação da task 8.13) e sem data de fim (ou fim ainda não
    # alcançado). Não existe mais a inconsistência Hash-vs-Array da API
    # antiga — é sempre uma relação ActiveRecord normal.
    scope :ativos, -> {
      joins(:vinculo_estado)
        .where(vinculos_estados: { nome: "em_exercicio" })
        .where("vinculos.fim IS NULL OR vinculos.fim >= ?", Date.current)
    }

    def lotacao_principal
      lotacoes.principais.merge(Pessoas::Lotacao.vigentes).order(inicio: :desc).first
    end

    def tipo_vinculo
      configuracao_cadastro&.tipo_vinculo
    end

    # Ponto de entrada único para a tela `admin/frequentadores` (SPRINT-PLAN
    # task 10.10) — concentra toda a query complexa (nome, órgão, filtros de
    # User local via cpf) num só método de classe, tanto pra manter o
    # controller enxuto quanto pra dar um único lugar pra stubar nos testes
    # (banco `pessoas_test` existe mas não tem schema carregado, ver task
    # 8.13 — não dá pra criar `Pessoas::Vinculo`/`Pessoas::Pessoa` reais em
    # teste).
    #
    # `incluir_cpfs`/`excluir_cpfs` resolvem os filtros que só existem no
    # User LOCAL do Frequencia (status, digital) — calculados no controller
    # a partir da tabela `users` (outro banco Postgres, sem JOIN
    # cross-database possível) e passados aqui como listas de CPF.
    #
    # Órgão vem da lotação principal vigente, que não é um `belongs_to`
    # direto em `Vinculo` (ver `#lotacao_principal` acima, resolvido em
    # Ruby). Filtrar via subquery de IDs evita duplicar linhas de vínculo
    # que um LEFT JOIN de has_one poderia causar (uma pessoa pode, em tese,
    # ter mais de uma lotação "principal" vigente simultânea) — importante
    # porque a lista é paginada e duplicação quebraria a contagem/paginação.
    def self.frequentadores_ativos(nome: nil, orgao: nil, categoria_trabalhador_id: nil, incluir_cpfs: nil, excluir_cpfs: nil)
      scope = ativos
        .joins(:pessoa)
        .includes(:pessoa, configuracao_cadastro: { tipo_vinculo: :categoria_trabalhador })
        .order("pessoas.nome")

      scope = scope.where("pessoas.nome ILIKE ?", "%#{nome}%") if nome.present?

      if orgao.present?
        vinculo_ids_no_orgao = Pessoas::Lotacao.principais.merge(Pessoas::Lotacao.vigentes)
          .joins(:unidade)
          .where("unidades.descricao ILIKE ?", "%#{orgao}%")
          .select(:vinculo_id)

        scope = scope.where(id: vinculo_ids_no_orgao)
      end

      if categoria_trabalhador_id.present?
        scope = scope.joins(configuracao_cadastro: :tipo_vinculo)
          .where(tipos_vinculo: { categoria_trabalhador_id: categoria_trabalhador_id })
      end

      scope = scope.where(pessoas: { cpf: incluir_cpfs }) if incluir_cpfs
      scope = scope.where.not(pessoas: { cpf: excluir_cpfs }) if excluir_cpfs.present?

      scope
    end

    # Lotação principal vigente pré-carregada em lote pros vínculos de uma
    # página (não é um `belongs_to` simples — ver `#lotacao_principal`).
    # Evita 1 query por linha na view; isolado como método de classe pra
    # poder ser stubado nos testes do controller (mesmo motivo do método
    # acima).
    def self.unidades_por_vinculo(vinculo_ids)
      return {} if vinculo_ids.blank?

      Pessoas::Lotacao.principais.merge(Pessoas::Lotacao.vigentes)
        .where(vinculo_id: vinculo_ids)
        .includes(:unidade)
        .order(inicio: :desc)
        .group_by(&:vinculo_id)
        .transform_values { |lotacoes| lotacoes.first&.unidade }
    end
  end
end
