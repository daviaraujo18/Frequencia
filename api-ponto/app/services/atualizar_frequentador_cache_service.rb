# Upsert do espelho local (FrequentadorCache) a partir de um payload de
# SticapiClient::Pessoas.get_by_cpf. Extraído de ImportarDadosPessoaJob para
# ser reaproveitado também por ImportarServidoresUnidadeJob (Sprint 10B).
#
# Formato de orgao/vinculo confirmado em 2026-08-28 contra um CPF real de
# teste (ver SPRINT-PLAN.md, Sprint 10, task 10.3):
#   lotacao_principal.unidade.descricao → nome do órgão/unidade
#   vinculos_ativos[0].tipo_vinculo.nome → tipo de vínculo (Efetivo,
#   Comissionado, etc.) — usa o primeiro vínculo ativo; uma pessoa pode ter
#   mais de um vínculo simultâneo, mas o cache guarda só o principal.
#
# Achado real na Sprint 10B (task 10B.10, validação em massa contra ~87
# servidores): quando a pessoa tem só 1 vínculo ativo, a Sticapi serializa
# `vinculos_ativos` como um Hash único (o próprio vínculo), não um Array de
# 1 item — inconsistência da API entre "1 vínculo" e "vários vínculos".
# `Array.wrap` normaliza os dois casos (Hash não responde a `to_ary`, então
# vira `[hash]`; Array já vem como está).
class AtualizarFrequentadorCacheService
  def self.call(cpf:, dados:)
    FrequentadorCache.find_or_initialize_by(cpf: cpf).tap do |cache|
      cache.update!(
        pessoa_id_pessoas: dados["id"],
        nome: dados["nome"],
        orgao: dados.dig("lotacao_principal", "unidade", "descricao"),
        vinculo: Array.wrap(dados["vinculos_ativos"]).first&.dig("tipo_vinculo", "nome"),
        sincronizado_em: Time.current
      )
    end
  end
end
