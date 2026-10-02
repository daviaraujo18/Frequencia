# Tarefa 29.7 (Sprint 29) — apoio à cascata de autorização nos controllers de
# frequência, atrás da flag `FREQUENCIA_AUTORIZACAO_CASCATA`
# (`FrequenciaAutorizacaoCascata`, Decisão D3). Concentra a leitura do usuário
# logado em "quais frequentadores ele vê", de modo que os 6 controllers
# afetados (frequencia, frequencia_por_orgao, frequentadores, parcial,
# time_records, relatorio_terceirizados) apliquem a MESMA regra, sem duplicar
# SQL.
#
# ⚠️ Contrato de fuso (leia antes de "otimizar"): as consultas ao banco do
# Pessoas (`Pessoas::Vinculo.cpfs_frequentadores_visiveis`) NÃO usam a conexão
# do Pessoas para ler `users` — a lista de CPFs é trazida para o banco primário
# e combinada com `User.where(cpf: ...)`, porque `users` e `pessoas` são bancos
# Postgres distintos (sem JOIN cross-database; ver 29.6).
#
# Modo `:off` (default): todos os helpers são no-op — o controller mantém o
# comportamento atual. Modo `:shadow`: nada é restringido; só se LOGA o que a
# cascata negaria. Modo `:on`: as listagens são filtradas.
module FrequenciaAuthorization
  private

  def frequencia_cascata_ligada?
    FrequenciaAutorizacaoCascata.ligada?
  end

  def frequencia_cascata_shadow?
    FrequenciaAutorizacaoCascata.shadow?
  end

  # CPFs dos frequentadores visíveis do usuário logado (via 29.6), memoizado
  # por request. Não é chamado no modo `:off`.
  def frequentadores_visiveis_cpfs
    @frequentadores_visiveis_cpfs ||=
      Pessoas::Vinculo.cpfs_frequentadores_visiveis(current_user)
  end

  # Ids de `User` locais correspondentes aos CPFs visíveis — o filtro que as
  # tabelas de frequência (`time_records`, `calculo_diarios`, ...) aceitam.
  def frequentadores_visiveis_user_ids
    @frequentadores_visiveis_user_ids ||=
      User.where(cpf: frequentadores_visiveis_cpfs).pluck(:id)
  end

  # Aplica a cascata a uma relação com `user_id` (TimeRecord/CalculoDiario/...).
  # No modo `:off`/`:shadow` devolve a relação intacta; com visão global
  # (admin/role geral) também — ver `frequencia_visao_global?`.
  def restringir_frequencia(relation)
    return relation unless frequencia_cascata_ligada?
    return relation if frequencia_visao_global?

    relation.where(user_id: frequentadores_visiveis_user_ids)
  end

  # Passo 2 da cascata (D1): `admin` (coluna OU role) e a role
  # `visualiza_frequentadores` veem TODOS os frequentadores. Curto-circuitar
  # aqui evita materializar a lista inteira de CPFs para então não filtrar nada
  # — o caso do admin é o mais comum e o mais caro (pluck de todos os vínculos).
  # É uma reprodução fiel do passo 2 (`role_geral?` do PORO), não uma regra
  # nova.
  def frequencia_visao_global?
    usuario = current_user
    return false unless usuario

    usuario.admin? || usuario.has_role?(:admin) || usuario.has_role?(:visualiza_frequentadores)
  end

  # Modo shadow: para cada alvo (User) que a cascata ocultaria, registra a
  # decisão que SERIA tomada (`usuario, alvo, motivo, decisão`), sem negar. O
  # motivo vem do PORO `AutorizacaoFrequencia` (29.4), a fonte da verdade — o
  # mesmo objeto que decide `pode_ver?`. Limitado a `LIMITE_SHADOW` alvos por
  # chamada: o shadow observa, não varre o universo.
  LIMITE_SHADOW = 200

  # Para uma relação com `user_id` (TimeRecord/CalculoDiario/...): os `user_id`
  # distintos que a cascata ocultaria.
  def observar_cascata_frequencia(relation)
    return unless frequencia_cascata_shadow?
    return if frequencia_visao_global?
    return if relation.nil?

    # `reorder(nil)` antes do `distinct`: no Postgres, `SELECT DISTINCT` exige
    # que as colunas do `ORDER BY` (aqui `punched_at`, herdado da listagem)
    # apareçam no SELECT. A ordem não importa para uma contagem de alvos.
    ocultos = relation.where.not(user_id: frequentadores_visiveis_user_ids)
                      .reorder(nil).distinct.limit(LIMITE_SHADOW).pluck(:user_id)
    registrar_shadow(ocultos)
  end

  # Para listagens de `Pessoas::Vinculo` (admin/frequentadores), onde o alvo é
  # um `User` local: amostra os Users que a cascata ocultaria. Bounded e no
  # banco primário (não varre os vínculos do Pessoas).
  def observar_cascata_frequentadores
    return unless frequencia_cascata_shadow?
    return if frequencia_visao_global?

    ocultos = User.where.not(id: frequentadores_visiveis_user_ids).limit(LIMITE_SHADOW).pluck(:id)
    registrar_shadow(ocultos)
  end

  def registrar_shadow(user_ids)
    return if user_ids.blank?

    poro = AutorizacaoFrequencia.new(current_user)
    User.where(id: user_ids).find_each do |alvo|
      FrequenciaAutorizacaoCascata.log_shadow(
        usuario: current_user,
        alvo: alvo,
        motivo: poro.motivo(alvo),
        decisao: :negaria
      )
    end
  end
end
