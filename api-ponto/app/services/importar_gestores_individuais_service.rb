# Tarefa 29.3 (Sprint 29) — importação idempotente dos gestores individuais
# do Intranet legado (PRD §2.5).
#
# O Intranet será descomissionado; a partir desta importação o Frequencia
# passa a ser a fonte de verdade do vínculo de gestão individual. Por isso o
# objetivo NÃO é "copiar uma vez", é poder reimportar quantas vezes for
# preciso sem duplicar nada ("segunda execução = 0 criações") e sem descartar
# o histórico: um registro excluído no legado entra como INATIVO, nunca é
# ignorado.
#
# Fonte: `SticapiClient::Intranet.gestores_individuais` — cada item traz
# `id, data_criacao, data_exclusao, observacao, id_vinculo_gestor,
# matricula_gestor, id_vinculo_gerido, matricula_gerido`. A listagem é uma
# tabela de LIGAÇÃO (uma linha = um par gestor→gerido), enquanto o modelo do
# Frequencia 29.2 separou o par em dois: `GestorIndividual` (o gestor, por
# pessoa) e `GestorIndividualGerenciado` (o vínculo gestor→gerido). Esta
# separação é o que torna o mapeamento de chave abaixo não-trivial.
#
# ── Mapeamento de identidade (decisão da importação, Bug 10 da 29.2) ────────
# A lista do Intranet tem N linhas por gestor (uma por gerido), mas o
# `GestorIndividual` do Frequencia é UMA linha por PESSOA (a tela
# `admin/gestores_individuais` lista gestores e conta `gerenciados` — N
# linhas da mesma pessoa apareceriam duplicadas). Logo as duas tabelas usam
# chaves estáveis DIFERENTES, ambas previstas nos índices UNIQUE da 29.2:
#
#   - `gestor_individual_gerenciados.id_legado` = `id` da linha legada
#     (a chave do PAR — o índice UNIQUE do par ativo/histórico depende disso);
#   - `gestores_individuais.id_legado` = `id_vinculo_gestor` (a chave da
#     PESSOA-gestor; estável e única por vínculo, então reimportar não cria um
#     gestor novo por gerido).
#   - `gestores_individuais.gestor_cpf` é a ponte de casamento documentada na
#     29.2 (Bug 10) — casa a linha legada com o gestor já importado quando o
#     `id_vinculo_gestor` vier ausente/divergente.
#
# ⚠️ Este mapeamento é o único consistente com os índices UNIQUE criados na
# 29.2, mas o critério da tarefa diz apenas "upsert por id_legado" — está
# isolado em `encontrar_gestor`/`chave_do_gestor` justamente para ser
# ratificado ou trocado pelo CTO sem tocar no resto desta classe.
#
# ── Modo de escrita (CTO, 2026-09-29 / ADR-0007) ───────────────────────────
# ActiveRecord (create/update!), NUNCA `upsert_all`: o invariante de
# auto-gerência cruza duas tabelas e não é expressável em SQL, então um
# upsert em massa o contornaria. Consequência aceita: uma linha que viole o
# invariante (ex.: gestor = seu próprio gerido ativo) é RECUSADA aqui e sai
# no relatório de não-resolvidos — não é gravada "por baixo".
#
# Regras de borda que caem nesta tarefa (triagem do CTO):
#   - ⚪ 11: `id_legado > 0` — 0/negativo/ausente nunca vira chave de upsert;
#   - ⚪ 14: `gestor_cpf: ""` → `nil` (`presence`), sem mexer em `allow_nil`;
#   - 🟢 19: resgatar `DeleteRestrictionError` E `InvalidForeignKey` — a FK é
#     que segura o hard-delete (o `restrict_with_exception` do model não cobre
#     quem escreve fora do cache do `has_many`);
#   - Bug 8: `RecordInvalid` nunca vaza `e.message` cru (o locale só é seguro
#     com `errors.full_messages`);
#   - Bug 3 da D7 / A5: `ativo: nil` normalizado na borda (não pode "pular" a
#     validação de auto-gerência nem virar estado implausível para auditoria);
#   - `data_exclusao` legada é gravada DIRETO no atributo (via `update!`),
#     nunca via `desativar!` — o método data a exclusão ao momento da chamada,
#     que não é a data do legado (ADR-0007, regra 4).
class ImportarGestoresIndividuaisService
  # Relatório final da importação. `nao_resolvidos` é enumerável (nada é
  # silenciosamente ignorado) — cada item traz o id legado e o motivo.
  Resultado = Struct.new(:importados, :atualizados, :nao_resolvidos, :dry_run, keyword_init: true) do
    def total
      importados + atualizados + nao_resolvidos.size
    end

    # String pronta para o log da task/job e para a inspeção manual.
    def resumo
      modo = dry_run ? "DRY-RUN (nenhuma escrita)" : "execução real"
      linhas = [
        "Importação de gestores individuais do Intranet — #{modo}",
        "  linhas lidas:   #{total}",
        "  importados:     #{importados}",
        "  atualizados:    #{atualizados}",
        "  não resolvidos: #{nao_resolvidos.size}"
      ]

      nao_resolvidos.each do |n|
        linhas << "    - linha legada #{n.id_legado.inspect}: #{n.motivo}"
      end

      linhas.join("\n")
    end
  end

  NaoResolvido = Struct.new(:id_legado, :motivo, keyword_init: true)

  # `registros:` permite injetar a lista (testes, reexecução a partir de um
  # dump do Intranet) sem tocar a rede; `silencioso` evita logs de cada linha
  # em dry-run/uso programático.
  def self.call(registros: nil, dry_run: false)
    new(dry_run: dry_run).call(registros)
  end

  def initialize(dry_run: false)
    @dry_run = dry_run
    @importados = 0
    @atualizados = 0
    @nao_resolvidos = []
  end

  def call(registros = nil)
    # Normaliza TODAS as linhas antes de qualquer leitura por chave: o mapa
    # matrícula→CPF e as linhas precisam falar a mesma "língua" de chave
    # (indifferent access), senão `l[:matricula_gestor]` seria `nil` sobre um
    # Hash de chaves string — e a importação inteira viraria "não resolvido".
    linhas = Array(registros || carregar_registros).map { |linha| normalizar_linha(linha) }
    pares = mapa_matricula_cpf(linhas)

    linhas.each { |linha| importar_linha(linha, pares) }

    Resultado.new(
      importados: @importados,
      atualizados: @atualizados,
      nao_resolvidos: @nao_resolvidos,
      dry_run: @dry_run
    )
  end

  private

  def carregar_registros
    SticapiClient::Intranet.gestores_individuais
  end

  # A gem devolve Array de Hash com chaves string. `with_indifferent_access`
  # evita depender do tipo exato de chave devolvido em cada versão da API.
  def normalizar_linha(linha)
    hash = linha.respond_to?(:with_indifferent_access) ? linha : linha.to_h
    hash.with_indifferent_access
  end

  # Um único mapa matrícula→CPF para toda a importação (a folha é lida uma
  # vez, não por linha) — mesmo desenho do ImportarServidoresUnidadeJob.
  def mapa_matricula_cpf(linhas)
    matriculas = linhas.flat_map { |l| [ l[:matricula_gestor], l[:matricula_gerido] ] }
                       .compact
                       .map(&:to_s)
                       .reject(&:blank?)
                       .uniq
    return {} if matriculas.empty?

    ResolverCpfPorMatriculaService.mais_recente(matriculas)
  end

  # --- uma linha legada = um par gestor→gerido ------------------------------

  def importar_linha(linha, pares)
    id_registro = inteiro_positivo(linha[:id])
    if id_registro.nil?
      return registrar_nao_resolvido(linha[:id], "id legado inválido (ausente, zero ou negativo) — ⚪ 11")
    end

    gestor_cpf = resolver_cpf(linha[:matricula_gestor], pares, linha[:id_vinculo_gestor])
    if gestor_cpf.blank?
      return registrar_nao_resolvido(id_registro, "matrícula do gestor #{linha[:matricula_gestor].inspect} sem CPF")
    end

    gerido_cpf = resolver_cpf(linha[:matricula_gerido], pares, linha[:id_vinculo_gerido])
    if gerido_cpf.blank?
      return registrar_nao_resolvido(id_registro, "matrícula do gerido #{linha[:matricula_gerido].inspect} sem CPF")
    end

    gerido_user = User.find_by(cpf: gerido_cpf)
    if gerido_user.nil?
      return registrar_nao_resolvido(id_registro, "gerido (CPF #{gerido_cpf}) não tem User no Frequencia")
    end

    aplicar(id_registro, linha, gestor_cpf, gerido_user)
  end

  # A escrita real (ou a simulação, em dry-run). Isolada para que o dry-run
  # percorra EXATAMENTE o mesmo caminho de resolução — só não persiste.
  def aplicar(id_registro, linha, gestor_cpf, gerido_user)
    gestor = encontrar_gestor(gestor_cpf, chave_do_gestor(linha))
    vinculo = GestorIndividualGerenciado.find_or_initialize_by(id_legado: id_registro)
    criacao = gestor.new_record? || vinculo.new_record?

    if @dry_run
      registrar_resultado(criacao)
      return
    end

    gestor_user = User.find_by(cpf: gestor_cpf)
    momento_exclusao = tempo(linha[:data_exclusao])

    ActiveRecord::Base.transaction do
      aplicar_gestor(gestor, linha, gestor_cpf, gestor_user, momento_exclusao)
      aplicar_vinculo(vinculo, gestor, gerido_user, momento_exclusao)
    end

    registrar_resultado(criacao)
  rescue ActiveRecord::RecordInvalid => e
    # Bug 8 (blocker da 29.3): `e.message` cru cai em "Translation missing"
    # quando o namespace do locale não resolve. `full_messages` é a fonte
    # confiável.
    registrar_nao_resolvido(id_registro, "registro inválido: #{e.record.errors.full_messages.to_sentence}")
  rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::InvalidForeignKey => e
    # 🟢 19: o `restrict_with_exception` do model só cobre quem destrói pelo
    # `has_many`; um vínculo/deleção fora desse cache levanta a FK crua. Ambos
    # os tipos são resgatados aqui — a FK é a garantia real do "nunca
    # hard-delete".
    registrar_nao_resolvido(id_registro, "violação de integridade referencial: #{e.class}")
  rescue StandardError => e
    # Mesma filosofia dos demais jobs de importação: uma linha ruim não pode
    # abortar a importação inteira. O erro sai no relatório, não no silêncio.
    registrar_nao_resolvido(id_registro, "#{e.class}: #{e.message}")
  end

  def aplicar_gestor(gestor, linha, gestor_cpf, gestor_user, momento_exclusao)
    gestor.id_legado = chave_do_gestor(linha)
    gestor.gestor_cpf = normalizar_cpf(gestor_cpf)
    gestor.nome ||= nome_do_gestor(gestor_cpf)
    gestor.observacao = linha[:observacao].presence
    gestor.data_criacao_legado = tempo(linha[:data_criacao])
    gestor.gestor_user = gestor_user
    aplicar_estado(gestor, momento_exclusao)

    gestor.save!
  end

  def aplicar_vinculo(vinculo, gestor, gerido_user, momento_exclusao)
    vinculo.gestor_individual = gestor
    vinculo.user = gerido_user
    aplicar_estado(vinculo, momento_exclusao)

    vinculo.save!
  end

  # Normalização de `ativo` na borda (Bug 3 da D7 / A5): um `ativo: nil` do
  # legado PULA a validação de auto-gerência (só o NOT NULL do banco segura) e
  # é um estado implausível. Regra: excluído no legado ⇒ inativo; senão ativo.
  # E `data_exclusao` é gravada direto no atributo — nunca `desativar!`.
  def aplicar_estado(registro, momento_exclusao)
    registro.data_exclusao = momento_exclusao
    registro.ativo = momento_exclusao.nil?
  end

  # --- identidade -----------------------------------------------------------

  # Chave da PESSOA-gestor (ver cabeçalho): `id_vinculo_gestor` quando válido.
  def chave_do_gestor(linha)
    inteiro_positivo(linha[:id_vinculo_gestor])
  end

  # Upsert idempotente do gestor, tolerante a bases parcialmente importadas:
  #   1. pela chave estável (`id_legado` = id_vinculo_gestor);
  #   2. senão pela ponte `gestor_cpf` (importação anterior sem id_vinculo);
  #   3. senão, novo.
  def encontrar_gestor(gestor_cpf, id_legado)
    por_chave = id_legado.present? ? GestorIndividual.find_by(id_legado: id_legado) : nil
    return por_chave if por_chave

    GestorIndividual.where(gestor_cpf: normalizar_cpf(gestor_cpf)).order(:id).first || GestorIndividual.new
  end

  # --- resolução matrícula→CPF (espelha o pessoas2, incl. o fallback) -------

  # `matricula` vem da folha do GestoRH; quando ela não resolve, o legado
  # ainda dá o vínculo do Intranet, que o Pessoas2 casa por `codigo_de_para`
  # (mesmo fallback de `GestaoIndividual.create_gestor_individual`).
  def resolver_cpf(matricula, pares, id_vinculo)
    cpf = pares[matricula.to_s] if matricula.present?
    return cpf if cpf.present?

    cpf_por_vinculo_legado(id_vinculo)
  end

  def cpf_por_vinculo_legado(id_vinculo)
    return if id_vinculo.blank?

    vinculo = Pessoas::Vinculo.where(codigo_de_para: id_vinculo.to_s).order(inicio: :desc).first
    vinculo&.pessoa&.cpf
  rescue StandardError => e
    Rails.logger.warn("[ImportarGestoresIndividuaisService] falha ao resolver vinculo legado #{id_vinculo}: #{e.class} - #{e.message}")
    nil
  end

  # O payload legado não traz o nome do gestor; o Pessoas é a autoridade
  # cadastral. Fallback determinístico porque `nome` é obrigatório no model e a
  # linha legada é válida — não podemos descartá-la só por falta de nome.
  def nome_do_gestor(gestor_cpf)
    Pessoas::Pessoa.find_by(cpf: gestor_cpf)&.nome.presence || "Gestor individual #{normalizar_cpf(gestor_cpf)}"
  rescue StandardError => e
    Rails.logger.warn("[ImportarGestoresIndividuaisService] falha ao ler nome do gestor #{gestor_cpf}: #{e.class} - #{e.message}")
    "Gestor individual #{normalizar_cpf(gestor_cpf)}"
  end

  # --- utilidades -----------------------------------------------------------

  # ⚪ 14: `""` → `nil` (`presence`), sem tocar no `allow_nil` do model.
  def normalizar_cpf(cpf)
    cpf.to_s.presence
  end

  # ⚪ 11: id legado só vale como chave se for inteiro > 0 (0 e negativo
  # colidiriam com id real; string numérica é aceita e convertida).
  def inteiro_positivo(valor)
    numero = Integer(valor, exception: false)
    numero if numero && numero.positive?
  end

  # Timestamps do legado vêm como "2019-10-30 10:03:25.0". Falha de parse
  # vira `nil` (não derruba a linha) — `Time.zone.parse` é o ponto que respeita
  # o timezone da aplicação.
  def tempo(valor)
    return if valor.blank?

    Time.zone.parse(valor.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def registrar_resultado(criacao)
    criacao ? @importados += 1 : @atualizados += 1
  end

  def registrar_nao_resolvido(id_legado, motivo)
    @nao_resolvidos << NaoResolvido.new(id_legado: id_legado, motivo: motivo)
    Rails.logger.warn("[ImportarGestoresIndividuaisService] linha legada #{id_legado.inspect} não resolvida: #{motivo}")
    nil
  end
end
