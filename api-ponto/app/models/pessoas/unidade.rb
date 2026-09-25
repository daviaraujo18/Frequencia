# Tabela `unidades`. Só usamos `descricao` (nome de exibição do órgão/lotação
# — mesmo campo lido no antigo `lotacao_principal.unidade.descricao` da
# Sticapi).
module Pessoas
  class Unidade < PessoasRecord
    self.table_name = "unidades"

    has_many :lotacoes, class_name: "Pessoas::Lotacao", foreign_key: :unidade_id, inverse_of: :unidade

    belongs_to :gestor, class_name: "Pessoas::Pessoa", optional: true
    belongs_to :gestor_substituto, class_name: "Pessoas::Pessoa", optional: true
    belongs_to :gestor_excepcional, class_name: "Pessoas::Pessoa", optional: true

    ServidorLotado = Struct.new(:matricula, :nome, keyword_init: true)

    def gestor?(pessoa)
      return false if pessoa.blank?

      gestor == pessoa || gestor_substituto == pessoa || gestor_excepcional == pessoa
    end

    # O Pessoas2 persiste a árvore no formato materialized path: a folha guarda
    # os IDs dos ancestrais da raiz até o pai, separados por `/`. Como este
    # espelho não usa a gem `ancestry`, a validação e a busca são mantidas
    # localmente; um caminho inválido falha fechado devolvendo apenas a própria
    # unidade, evitando liberar acesso com uma hierarquia corrompida.
    def cadeia_ascendente
      return [ self ] if ancestry.blank?

      ancestor_ids = ancestry.to_s.split("/", -1).reverse
      return [ self ] unless ancestor_ids.all? { |ancestor_id| ancestor_id.match?(/\A\d+\z/) }
      return [ self ] if id.present? && ancestor_ids.include?(id.to_s)

      ancestor_ids = ancestor_ids.map(&:to_i)
      ancestors_by_id = self.class.where(id: ancestor_ids).to_a.index_by { |ancestor| ancestor.id.to_s }

      [ self ] + ancestor_ids.filter_map { |ancestor_id| ancestors_by_id[ancestor_id.to_s] }
    end

    # Servidores com lotação principal e vigente nesta unidade — equivalente
    # ao antigo `unidade.dig("servidores")` da Sticapi (matrícula + nome,
    # sem CPF; ver ResolverCpfPorMatriculaService para resolver o CPF).
    # Isolado num método próprio (em vez de inline no job) para poder ser
    # stubado nos testes sem precisar de schema populado no banco `pessoas`
    # de teste.
    def servidores
      lotacoes.principais.merge(Pessoas::Lotacao.vigentes).includes(vinculo: :pessoa).filter_map do |lotacao|
        vinculo = lotacao.vinculo
        next if vinculo.blank?

        ServidorLotado.new(matricula: vinculo.matricula, nome: vinculo.pessoa&.nome)
      end
    end
  end
end
