# Tarefa 29.6 (Sprint 29) — lista de frequentadores VISÍVEIS por um usuário
# (PRD §3; §9 item 1). É o IRMÃO SQL do PORO `AutorizacaoFrequencia`
# (task 29.4): o PORO responde por UM alvo (`pode_ver?`), e este object
# responde pela LISTA inteira (scope SQL), para alimentar
# `accessible_by`/listagens/relatórios sem vazar registros por paginação.
#
# ⚠️ Contrato de equivalência (critério da 29.6): para TODO par
# (usuário, frequentador) a lista devolvida aqui contém o frequentador sse
# `AutorizacaoFrequencia.new(usuario).pode_ver?(frequentador)` é `true`. A
# prova é o teste de propriedade em `test/models/frequentadores_visiveis_test.rb`.
# A FONTE DA VERDADE da regra é o PORO da 29.4 — este arquivo NÃO inventa
# semântica: ele REPLICA a cascata de 5 passos em SQL.
#
# ── Limite estrutural (leia antes de "melhorar") ────────────────────────────
# `users` (banco primário) e `pessoas`/`vinculos` (banco espelho do Pessoas)
# são bancos Postgres DISTINTOS (ver `config/database.yml`): não há JOIN
# cross-database. Por isso os passos que dependem de `users` (1 próprio e 4
# gestor individual) são resolvidos NESTE ARQUIVO, em Ruby, contra o banco
# primário, e o resultado (a lista de CPFs dos alvos) entra no SQL como um
# `IN (...)` literal. Os passos que vivem no Pessoas (3 terceirizado e 5
# hierarquia) viram SQL puro sobre `vinculos`. A regra de negócio permanece
# em UM só lugar (`condicoes_liberacao`); os mini-fragmentos de leitura de
# `users` são análogos aos do PORO (passos 1 e 4), não uma segunda regra.
#
# ── Fail-closed (espelha o PORO) ────────────────────────────────────────────
# Usuário nulo → lista vazia. Alvo/pessoa ausente, path corrompido ou
# Pessoas indisponível → a condição daquele passo não casa (nenhum acesso).
#
# ── D6 replicada (unidade inelegível não libera; ausente não interrompe) ────
# A cadeia do alvo é lida do `ancestry` persistido (o path é a fonte da
# estrutura). Unidade INELEGÍVEL (`active` falso ou extinta) não libera pelos
# seus gestores — inclusive a própria unidade de lotação do alvo. Ancestral
# AUSENTE (id no path sem registro) é pulado e a subida CONTINUA (o JOIN
# simplesmente não acha a unidade). Path CORROMPIDO (formato inválido,
# auto-referência, id repetido) fecha em fail-closed: só a própria unidade
# conta — idêntico a `Pessoas::Unidade#cadeia_ascendente`.
class FrequentadoresVisiveis
  # Decisão D4 do CTO (2026-09-29): TERCEIRIZADO é o TIPO de vínculo
  # (`tipos_vinculo.nome`), nunca a categoria eSocial. Idêntico a
  # `Pessoas::Vinculo#terceirizado?`.
  TIPO_TERCEIRIZADO = "Terceirizado".freeze

  # Estado de vínculo "ativo" (espelha `Pessoas::Vinculo.ativos`).
  ESTADO_ATIVO = "em_exercicio".freeze

  # Ponto de entrada — devolve uma `ActiveRecord::Relation` de
  # `Pessoas::Vinculo` (o frequentador é um vínculo ativo com pessoa).
  def self.para(usuario)
    new(usuario).escopo
  end

  def initialize(usuario)
    @usuario = usuario
  end

  # Passo 2 do PORO: admin OU role `visualiza_frequentadores` → TODOS os
  # frequentadores (a role de terceirizados tem precedência menor e é
  # absorvida aqui, como no `return` do primeiro match do legado).
  def escopo
    return base.none if usuario.blank?
    # `.distinct` no resultado (critério da 29.6): a condição de hierarquia é
    # um EXISTS (não multiplica linhas), mas o filtro por CPF pode casar o
    # mesmo vínculo por mais de uma via (ex.: próprio ∪ gerido) e um LEFT
    # futuro não deve duplicar frequentadores na paginação.
    return base.distinct if role_geral?

    base.where(condicoes_liberacao).distinct
  end

  private

  attr_reader :usuario

  def base
    Pessoas::Vinculo.ativos.joins(:pessoa)
  end

  # --- passos 1 e 4 (banco primário: users/gestores_individuais) -------------

  # Passo 2 — `admin` é o único curto-circuito (idêntico ao `admin?` do PORO e
  # da `Ability`: coluna booleana OU role Rolify).
  def role_geral?
    admin? || usuario.has_role?(:visualiza_frequentadores)
  end

  def admin?
    usuario.admin? || usuario.has_role?(:admin)
  end

  # Passo 3 — a role sozinha só é significativa combinada com o tipo do alvo.
  def role_terceirizados?
    usuario.has_role?(:visualiza_terceirizados)
  end

  # Passo 1 (próprio) e passo 4 (gestor individual) reduzem-se a "quais CPFs
  # de alvo o usuário pode ver independentemente da hierarquia". O CPF é a
  # ponte entre o `User` local e o `Pessoas::Vinculo` (o frequentador).
  def cpfs_alvos
    @cpfs_alvos ||= ([ cpf_do_usuario ] + cpfs_dos_geridos).compact.uniq
  end

  def cpf_do_usuario
    @cpf_do_usuario ||= normalizar_cpf(usuario&.cpf)
  end

  # Passo 4 — geridos por `GestorIndividual` ATIVO (Bug 16/ADR-0008: sempre
  # via `GestorIndividualGerenciado.ativos`, que aciona o índice UNIQUE
  # parcial). Identidade do gestor: login local (`gestor_user_id`) quando
  # houver e a ponte `gestor_cpf` como fallback (29.3).
  def geridos_user_ids
    escopo = GestorIndividualGerenciado.ativos.joins(:gestor_individual)
    ids = []

    if usuario.id.present?
      ids |= escopo.where(gestores_individuais: { gestor_user_id: usuario.id }).pluck(:user_id)
    end
    if cpf_do_usuario.present?
      ids |= escopo.where(gestores_individuais: { gestor_cpf: cpf_do_usuario }).pluck(:user_id)
    end

    ids
  end

  # CPFs dos geridos. Só quem tem CPF existe como frequentador no Pessoas; um
  # `User` local sem CPF não tem pessoa/vínculo e não aparece na lista (é o
  # único ponto em que o conjunto de resultados do scope é menor que o do
  # PORO — documentado no teste de propriedade).
  def cpfs_dos_geridos
    ids = geridos_user_ids
    return [] if ids.empty?

    User.where(id: ids).where.not(cpf: nil).pluck(:cpf).map { |cpf| normalizar_cpf(cpf) }.compact
  end

  # --- montagem das condições de liberação -----------------------------------

  def condicoes_liberacao
    partes = []
    partes << "pessoas.cpf IN (#{lista_quoted(cpfs_alvos)})" if cpfs_alvos.any?
    if role_terceirizados?
      partes << "vinculos.configuracao_cadastro_id IN (#{subquery_tipos_terceirizado})"
    end
    partes << condicao_hierarquia if pessoa_do_usuario.present?

    return "1 = 0" if partes.empty?

    "(#{partes.join(' OR ')})"
  end

  # --- passo 5 (hierarquia) --------------------------------------------------

  # `pessoa` do usuário logado no Pessoas (identidade de gestor). `nil` quando
  # o usuário não tem CPF / não existe no Pessoas → passo 5 inaplicável,
  # idêntico ao PORO.
  def pessoa_do_usuario
    return @pessoa_do_usuario if defined?(@pessoa_do_usuario)

    @pessoa_do_usuario = Pessoas::Pessoa.por_user(usuario)
  rescue ActiveRecord::ActiveRecordError, PG::Error
    @pessoa_do_usuario = nil
  end

  # A condição de hierarquia: existe UMA lotação principal vigente da pessoa
  # do alvo (a mais recente, como no PORO) cuja UNIDADE cai na cadeia de
  # liberação. A subquery da lotação usa `vinculos.pessoa_id` para amarrar ao
  # alvo (correlação). Não usa CTE nem query por linha: é UMA condição SQL.
  def condicao_hierarquia
    ids = pessoa_ids_gestor
    return "1 = 0" if ids.empty?

    gerente = "un.gestor_id IN (#{lista_quoted(ids)}) OR " \
              "un.gestor_substituto_id IN (#{lista_quoted(ids)}) OR " \
              "un.gestor_excepcional_id IN (#{lista_quoted(ids)})"

    # Self: a própria unidade de lotação do alvo pode liberar — desde que
    # ELEGÍVEL (D6: vale também para a própria unidade de lotação).
    self_liberado = "(#{unidade_elegivel('un')} AND (#{gerente}))"

    # Ancestrais: pulados quando ausentes (o JOIN não acha a unidade), a
    # subida continua; a elegibilidade de cada ancestral é exigida (D6).
    ancestrais_liberados =
      "EXISTS (" \
        "SELECT 1 FROM unnest(string_to_array(un.ancestry, '/')::bigint[]) AS aid " \
        "JOIN unidades au ON au.id = aid " \
        "WHERE #{unidade_elegivel('au')} " \
        "AND (au.gestor_id IN (#{lista_quoted(ids)}) OR " \
        "au.gestor_substituto_id IN (#{lista_quoted(ids)}) OR " \
        "au.gestor_excepcional_id IN (#{lista_quoted(ids)})))"

    # Path corrompido → fail-closed: só o self conta.
    cadeia_liberada = "(#{self_liberado} OR (#{path_valido('un')} AND #{ancestrais_liberados}))"

    <<~SQL.squish
      EXISTS (
        SELECT 1
        FROM lotacoes lot
        JOIN vinculos vinc ON vinc.id = lot.vinculo_id
        JOIN vinculos_estados ve ON ve.id = vinc.vinculo_estado_id
        JOIN unidades un ON un.id = lot.unidade_id
        WHERE lot.principal IS TRUE
          AND (lot.fim IS NULL OR lot.fim >= CURRENT_DATE)
          AND vinc.pessoa_id = vinculos.pessoa_id
          AND ve.nome = '#{ESTADO_ATIVO}'
          AND (vinc.fim IS NULL OR vinc.fim >= CURRENT_DATE)
          AND lot.inicio = (
            SELECT MAX(lot2.inicio)
            FROM lotacoes lot2
            JOIN vinculos v2 ON v2.id = lot2.vinculo_id
            JOIN vinculos_estados ve2 ON ve2.id = v2.vinculo_estado_id
            WHERE lot2.principal IS TRUE
              AND (lot2.fim IS NULL OR lot2.fim >= CURRENT_DATE)
              AND v2.pessoa_id = vinculos.pessoa_id
              AND ve2.nome = '#{ESTADO_ATIVO}'
              AND (v2.fim IS NULL OR v2.fim >= CURRENT_DATE)
          )
          AND #{cadeia_liberada}
      )
    SQL
  end

  # Ids de `pessoas` que representam o usuário logado (identidade do gestor).
  def pessoa_ids_gestor
    @pessoa_ids_gestor ||= pessoa_do_usuario ? [ pessoa_do_usuario.id ] : []
  end

  # Passo 3 — ids de `configuracoes_cadastro` cujo tipo de vínculo é
  # Terceirizado (D4).
  def subquery_tipos_terceirizado
    "SELECT cc.id FROM configuracoes_cadastro cc " \
      "JOIN tipos_vinculo tv ON tv.id = cc.tipo_vinculo_id " \
      "WHERE tv.nome = '#{TIPO_TERCEIRIZADO}'"
  end

  # --- fragmentos SQL reutilizáveis (espelham os métodos Ruby do PORO) -------

  # `Pessoas::Unidade#elegivel?` em SQL: ativa E sem extinção consumada.
  def unidade_elegivel(alias_unidade)
    "#{alias_unidade}.active IS TRUE AND " \
      "(#{alias_unidade}.data_extincao_serventia IS NULL " \
      "OR #{alias_unidade}.data_extincao_serventia > CURRENT_DATE)"
  end

  # `Pessoas::Unidade#cadeia_ascendente` — fail-closed do path: formato
  # (dígitos separados por "/"), sem auto-referência (comparação numérica,
  # Bug 1) e sem ids repetidos (Bug 2). Só quando isto é VÁLIDO os ancestrais
  # são considerados.
  def path_valido(alias_unidade)
    a = "#{alias_unidade}.ancestry"
    "(" \
      "#{a} IS NOT NULL " \
      "AND #{a} ~ '^\\d+(/\\d+)*$' " \
      "AND NOT (#{alias_unidade}.id = ANY(string_to_array(#{a}, '/')::bigint[])) " \
      "AND cardinality(string_to_array(#{a}, '/')::bigint[]) = " \
      "(SELECT count(DISTINCT x) FROM unnest(string_to_array(#{a}, '/')::bigint[]) AS x)" \
      ")"
  end

  # --- utilidades ------------------------------------------------------------

  def normalizar_cpf(valor)
    valor.to_s.gsub(/\D/, "").presence
  end

  # Quoting defensivo (os valores são cpfs/ids, mas nunca concatenamos cru).
  def lista_quoted(valores)
    valores.map { |valor| Pessoas::Vinculo.connection.quote(valor) }.join(", ")
  end
end
