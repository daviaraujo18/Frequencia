# Tarefa 30.9b (Sprint 30) — migração 1:1 das 2 roles que a cascata de
# autorização de frequência consome, a partir do Intranet legado.
#
# Ruling D-6 = (i) (dev, 2026-10-06): as roles são migradas 1:1 do Intranet
# legado pela conexão direta `intranet_development` já configurada — NÃO por
# atribuição administrativa provisória (a opção (ii) foi descartada).
#
# ── Por que só 2 roles (ruling 30.3 = A) ───────────────────────────────────
# A cascata lê EXATAMENTE 2 roles do Rolify local: `visualiza_frequentadores`
# (passo 2 — `AutorizacaoFrequencia#role_geral?`) e `visualiza_terceirizados`
# (passo 3 — `#terceirizado?`). As outras 11 roles `presenca*` do legado gateiam
# seções fora do domínio de frequência e NÃO são migradas (seriam decorativas).
# Logo o conjunto de roles legadas consideradas é FECHADO e explícito
# (`MAPEAMENTO`): qualquer outro `roleId` que porventura chegue aqui é tratado
# como NÃO resolvido — nunca vira role local por engano.
#
# ── Fonte (SOMENTE LEITURA) ────────────────────────────────────────────────
# O legado modela acesso por PERFIL, não por role direta do usuário. A cadeia
# é resolvida numa única query (string-based, sem FK numérica):
#
#   admin_user.profile_profileId = admin_profile.profileId
#   admin_profile_role.profileId  = admin_profile.profileId
#   admin_profile_role.roleId     = admin_role.roleId
#
# A api-ponto NUNCA escreve nesse banco — só executa SELECT (o mesmo contrato
# de `Intranet::SyncDigitaisService`, cujo padrão de conexão/erro/log é
# reaproveitado aqui).
#
# ── Casamento login → User local (decisão, com evidência) ──────────────────
# A única chave do legado disponível é `admin_user.login` (varchar). Evidência
# de que ela casa com o `username` local:
#   - `admin_user.login` é o LOGIN (AD) do usuário no Intranet: em
#     `intranet/src/modules/tjpi/actions/CriarUsuarioDeferido.java` o login é
#     criado/sincronizado no AD (`AD.sync(usuario)`);
#   - o `User.username` local é populado a partir do `username` real da tabela
#     `pessoas` (`app/jobs/importar_servidores_unidade_job.rb:84,99`), e a doc
#     do Pessoas define `username` como "CPF ou matrícula AD"
#     (`pessoas2/docs/analysis/models/user.md:13`);
#   - logo o eixo comum é o login AD/matrícula — o MESMO eixo que o
#     `SyncDigitaisService#encontrar_user` usa (`User.find_by(username:
#     matricula)`).
# Decisão: casa por `User.username == login` (primário). Como o `username` do
# Pessoas pode ser o próprio CPF, há um fallback para `User.cpf == login`
# quando o login é um CPF (11 dígitos) — mesma ponte CPF documentada no
# `SyncDigitaisService`. Se NENHUMA das duas casar, o registro vai para o
# relatório de NÃO resolvidos (nada é inventado nem silenciado).
#
# ── Idempotência ───────────────────────────────────────────────────────────
# O casamento é por chave estável (login→User) e a checagem `has_role?` antes
# do `add_role` (que já é idempotente por si) garante "2ª execução = 0
# criações / 0 alterações líquidas". `DRY_RUN` percorre exatamente o mesmo
# caminho sem escrever.
#
# ⚠️ DÉBITO CONHECIDO (S3 do review da 30.9b — não corrigido aqui): a tabela
# `users_roles` do Rolify NÃO tem índice único e o par `has_role?` + `add_role`
# é um check-then-insert NÃO atômico. Logo a idempotência é sólida para
# execuções SEQUENCIAIS (é o caso de uma rake one-off de migração), mas NÃO é
# protegida contra duas execuções CONCORRENTES do mesmo login (poderiam inserir
# a linha `users_roles` em duplicidade). Probabilidade baixa para o uso
# pretendido (one-off, operador único). Se um dia virar job recorrente/
# concorrente, exige índice único em `users_roles` (migration — fora do
# escopo/ruling A) ou lock/lógica de upsert atômica.
#
# Uso:
#   Intranet::MigrarRolesCascataService.call                  # migra de verdade
#   Intranet::MigrarRolesCascataService.call(dry_run: true)    # só relatório
class Intranet::MigrarRolesCascataService
  LOG_PATH = Rails.root.join("log", "roles_cascata_migracao.log")

  # role legado (`admin_role.roleId`) → role Rolify local. Fechado de propósito
  # (ruling A): só as 2 roles que a cascata consome.
  MAPEAMENTO = {
    "presencaVisualizaFrequentadores" => :visualiza_frequentadores,
    "presencaVisualizaFrequentadoresTerceirizados" => :visualiza_terceirizados
  }.freeze

  # Relatório final. `nao_resolvidos` é enumerável (nada é silenciosamente
  # ignorado). O `login` é mantido no item para uso programático/operacional,
  # mas NÃO é impresso no `resumo` (PII — ver `resumo`).
  Resultado = Struct.new(:processados, :atribuidos, :sem_alteracao, :nao_resolvidos, :erros, :dry_run, :falha_leitura, keyword_init: true) do
    # Q11 (dev, 2026-10-06): limiar de aborto sobre a proporção de NÃO
    # resolvidos na execução real. Acima de 10% é sinal de que o eixo de
    # casamento `login → username` está errado — a rake aborta e NÃO aplica.
    # Estritamente MAIOR que 10% (o ruling diz "passar de 10%"): exatamente 10%
    # não aborta.
    LIMIAR_NAO_RESOLVIDOS = 0.10

    # Contabilidade fechada: toda atribuição lida vira um dos quatro destinos.
    def total_contabilizado
      atribuidos + sem_alteracao + nao_resolvidos.size + erros
    end

    # Fração de não-resolvidos sobre as atribuições LIDAS. Denominador zero
    # (legado vazio, sem falha de leitura) ⇒ 0.0, nunca divisão por zero.
    def proporcao_nao_resolvidos
      return 0.0 if processados.to_i.zero?

      nao_resolvidos.size.to_f / processados
    end

    def abortar_por_nao_resolvidos?
      proporcao_nao_resolvidos > LIMIAR_NAO_RESOLVIDOS
    end

    # String para o log da task/inspeção manual. Agrupa os não resolvidos por
    # MOTIVO (contagem) — nunca imprime login/CPF.
    def resumo
      modo = dry_run ? "DRY-RUN (nenhuma escrita)" : "execução real"
      linhas = [
        "Migração 1:1 das roles da cascata (Intranet -> Frequencia) — #{modo}"
      ]
      # S2 do review: FALHA DE LEITURA != leitura vazia. Se o legado não pôde
      # ser lido (MySQL fora, mysql2 ausente, conexão não configurada), o
      # relatório diz isso EXPLICITAMENTE — "0 lidas" sem este aviso faria o
      # operador confundir "nada a migrar" com "a leitura falhou".
      linhas << "  ⚠️ FALHA DE LEITURA DO LEGADO — nenhuma atribuição lida; a migração NÃO foi executada" if falha_leitura
      linhas += [
        "  atribuições lidas: #{processados}",
        "  atribuídas:        #{atribuidos}",
        "  sem alteração:     #{sem_alteracao}",
        "  não resolvidas:    #{nao_resolvidos.size}",
        "  erros:             #{erros}",
        format("  proporção não resolvidas: %.1f%% (limiar de aborto: %.0f%%)",
               proporcao_nao_resolvidos * 100, LIMIAR_NAO_RESOLVIDOS * 100)
      ]
      nao_resolvidos.group_by(&:motivo).each do |motivo, itens|
        linhas << "    - #{itens.size}x #{motivo}"
      end
      linhas.join("\n")
    end
  end

  NaoResolvido = Struct.new(:login, :motivo, keyword_init: true)

  # `atribuicoes:` permite injetar as linhas (testes, reexecução a partir de
  # dump) sem tocar a rede/banco do legado.
  def self.call(atribuicoes: nil, dry_run: false)
    new(dry_run: dry_run).call(atribuicoes)
  end

  def initialize(dry_run: false)
    @dry_run = dry_run
    @log_path = LOG_PATH
    @atribuidos = 0
    @sem_alteracao = 0
    @nao_resolvidos = []
    @erros = 0
    # S2: distingue "a leitura do legado FALHOU" de "o legado não devolveu
    # nenhuma atribuição". Só é setado no caminho de leitura (não quando as
    # linhas são injetadas).
    @falha_leitura = false
  end

  def call(atribuicoes = nil)
    FileUtils.mkdir_p(File.dirname(@log_path))

    linhas = Array(atribuicoes || ler_atribuicoes_legado)
             .map { |linha| normalizar_linha(linha) }
             .uniq { |linha| [ linha[:login].to_s, linha[:role_legado].to_s ] }

    linhas.each { |linha| processar(linha) }

    resultado = Resultado.new(
      processados: linhas.size,
      atribuidos: @atribuidos,
      sem_alteracao: @sem_alteracao,
      nao_resolvidos: @nao_resolvidos,
      erros: @erros,
      dry_run: @dry_run,
      falha_leitura: @falha_leitura
    )

    if @falha_leitura
      log("FALHA DE LEITURA DO LEGADO — nenhuma atribuição lida; a migração NÃO foi executada")
    else
      log("MIGRAÇÃO CONCLUÍDA — #{resultado.atribuidos} atribuídas, " \
          "#{resultado.sem_alteracao} sem alteração, #{resultado.nao_resolvidos.size} não resolvidas, " \
          "#{resultado.erros} erros (de #{resultado.processados} lidas)")
    end
    resultado
  end

  private

  # --- leitura read-only do legado (mesmo desenho do SyncDigitaisService) ----

  def ler_atribuicoes_legado
    return [] unless carregar_mysql2!

    client = client_intranet
    return [] if client.nil?

    rows = client.query(<<~SQL, symbolize_keys: true, cast: true)
      SELECT
        u.`login`   AS login,
        r.`roleId`  AS role_legado
      FROM admin_user u
        INNER JOIN admin_profile p       ON p.`profileId`  = u.`profile_profileId`
        INNER JOIN admin_profile_role pr ON pr.`profileId` = p.`profileId`
        INNER JOIN admin_role r          ON r.`roleId`     = pr.`roleId`
      WHERE r.`roleId` IN ('presencaVisualizaFrequentadores', 'presencaVisualizaFrequentadoresTerceirizados')
      ORDER BY u.`login` ASC, r.`roleId` ASC
    SQL
    client.close
    rows.map { |row| converter_charset(row) }
  rescue Mysql2::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    @falha_leitura = true
    log("ERRO ao conectar na Intranet: #{e.message}")
    []
  end

  def carregar_mysql2!
    require "mysql2"
    true
  rescue LoadError => e
    @falha_leitura = true
    log("ERRO: gem mysql2 indisponível — #{e.message}")
    false
  end

  def client_intranet
    config = conexao_intranet_config
    if config.nil?
      @falha_leitura = true
      log("ERRO: conexão intranet não configurada (seção 'intranet_#{Rails.env}' ausente no config/database.yml)")
      return nil
    end

    Mysql2::Client.new(config)
  rescue Mysql2::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    # Mesma trilha do `ler_atribuicoes_legado`: falha de conexão é FALHA DE
    # LEITURA (não "leitura vazia").
    @falha_leitura = true
    log("ERRO ao abrir conexão com a Intranet: #{e.class} - #{e.message}")
    nil
  end

  def conexao_intranet_config
    config = Rails.application.config.database_configuration["intranet_#{Rails.env}"]
    return nil if config.blank?

    if Rails.env.production?
      config = config.merge(
        host: ENV.fetch("INTRANET_HOST", config["host"]),
        port: ENV.fetch("INTRANET_PORT", config["port"]).to_i,
        username: ENV.fetch("INTRANET_USER", config["username"]),
        password: ENV.fetch("INTRANET_PASSWORD", config["password"]),
        database: ENV.fetch("INTRANET_DATABASE", config["database"])
      )
    end

    config.symbolize_keys
  end

  def converter_charset(registro)
    registro.transform_values do |valor|
      next if valor.nil?

      valor.is_a?(String) ? valor.encode("UTF-8") : valor
    end
  end

  # Aceita chaves string ou símbolo (a query devolve símbolo; um dump pode vir
  # string) — mesmo cuidado do ImportarGestoresIndividuaisService.
  def normalizar_linha(linha)
    hash = linha.respond_to?(:with_indifferent_access) ? linha : linha.to_h
    hash.with_indifferent_access
  end

  # --- processamento de uma atribuição legada --------------------------------

  def processar(linha)
    login = linha[:login].to_s.strip
    role_legado = linha[:role_legado].to_s
    role_local = MAPEAMENTO[role_legado]

    if role_local.nil?
      # Defensivo: a query já filtra, mas nenhum `roleId` fora do MAPEAMENTO
      # pode virar role local. Nada é criado.
      return registrar_nao_resolvido(login, "role legado fora do escopo da migração (não é uma das 2 roles da cascata)")
    end

    user = encontrar_user(login)
    if user.nil?
      return registrar_nao_resolvido(login, "login legado sem User local correspondente (username/CPF)")
    end

    if user.has_role?(role_local)
      @sem_alteracao += 1
    else
      atribuir(user, role_local)
      @atribuidos += 1
    end
  rescue StandardError => e
    # Uma linha ruim não pode abortar o lote (filosofia do SyncDigitais). O
    # erro sai contado e logado — sem PII (só a classe da exceção).
    @erros += 1
    log("ERRO — role=#{role_local.inspect}: #{e.class}")
  end

  # Casamento por chave estável (ver cabeçalho): `username` primário e CPF como
  # fallback quando o login é um CPF. O username é casado CASE-INSENSITIVE
  # (`lower(username)`, com bind) — o mesmo critério do login do próprio app
  # (`User.find_for_database_authentication`, `app/models/user.rb:142`); sem
  # isso, um login legado em caixa diferente viraria "não resolvido" falso.
  def encontrar_user(login)
    return nil if login.blank?

    user = User.where("lower(username) = ?", login.downcase).first
    user ||= User.find_by(cpf: login) if login.match?(/\A\d{11}\z/)
    user
  end

  # Idempotência SEQUENCIAL garantida pelo `has_role?` em `processar`; a
  # duplicidade sob CONCORRÊNCIA não é protegida (users_roles sem índice único,
  # check-then-insert não atômico) — débito S3 documentado no cabeçalho.
  def atribuir(user, role_local)
    return if @dry_run

    user.add_role(role_local)
    log("ATRIBUÍDO — role=#{role_local} user_id=#{user.id}")
  end

  def registrar_nao_resolvido(login, motivo)
    @nao_resolvidos << NaoResolvido.new(login: login, motivo: motivo)
    log("NÃO RESOLVIDO — #{motivo}")
    nil
  end

  def log(mensagem)
    File.open(@log_path, "a") do |f|
      f.puts("[#{Time.current.strftime('%Y-%m-%d %H:%M:%S')}] #{mensagem}")
    end
    Rails.logger.info("[MigrarRolesCascata] #{mensagem}")
  end
end
