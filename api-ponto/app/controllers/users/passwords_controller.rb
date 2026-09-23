# frozen_string_literal: true

# Task 23.8 — Controller Devise customizado para recuperação de senha
# (recoverable).
#
# O controller padrão (`Devise::PasswordsController`) renderiza as views em
# `app/views/devise/passwords/` e usa o layout default (`application` — o
# layout administrativo com sidebar). Para as rotas `/u/password/*` (módulo
# Devise no `User`, task 23.6) servirem as telas de recuperação no mesmo
# padrão visual da tela de login, criamos `Users::PasswordsController` —
# mesmo padrão da 23.6 para `Users::SessionsController`:
#
# 1. `layout "login"` — mesma tela AdminLTE 4 da autenticação, sem sidebar
#    (ver `app/views/layouts/login.html.erb`).
# 2. Views próprias em `app/views/users/passwords/` (new/edit), resolvidas
#    pelo controller path — sem depender de `config.scoped_views`.
#
# A lógica de recuperação é 100% do Devise (gerar token, e-mail de
# instruções, redefinir senha). Obs.: o envio de e-mail depende de
# ActionMailer, que NÃO está montado nesta aplicação (config/application.rb
# não requer o railtie) — o fluxo visual e a geração de token funcionam; o
# disparo real do e-mail fica para quando o ActionMailer for habilitado
# (débito documentado na task 23.8).
class Users::PasswordsController < Devise::PasswordsController
  layout "login"

  # B1 (bug_report_23_cs) — degradação controlada do recoverable sem
  # ActionMailer.
  #
  # O fluxo real gera `reset_password_token` (persistido) e tenta disparar
  # `Devise::Mailer` — constante inexistente porque o railtie do
  # ActionMailer NÃO está montado (config/application.rb) → NameError →
  # HTTP 500 público (rota aberta para qualquer usuário não autenticado).
  #
  # Decisão documentada (bug report + iteration 23): opção (b) falha limpa
  # com flash de aviso — NÃO habilitamos ActionMailer (opção a), que exigiria
  # SMTP/env/views de mailer (mudança de infraestrutura, fora da correção
  # mínima). O caminho SENDÁVEL permanece 100% Devise: quando o ActionMailer
  # for habilitado no futuro, `super` completa o disparo real sem nenhuma
  # alteração aqui; `reset_password_by_token` (PATCH) continua funcional.
  # O token gerado antes da falha é inócuo (nunca chega ao usuário sem
  # e-mail) e é substituído a cada nova solicitação.
  def create
    super
    # Bug 10 (bug_report_23_bug-finder-r4) — phantom work para equalizar o
    # timing entre email conhecido e desconhecido.
    #
    # Contexto: com `config.paranoid = true`, o caminho de email CONHECIDO
    # executa 5 queries (SELECT por email + SELECT por reset_password_token
    # do token_generator + SAVEPOINT/UPDATE/RELEASE do save) e ainda
    # levanta/captura NameError (mailer desmontado); o caminho DESCONHECIDO
    # executa apenas 1 query (SELECT miss) e retorna normal. Esse delta de
    # ~1-2ms é um timing side-channel: um atacante pode, medindo o tempo de
    # resposta, enumerar quais emails existem no sistema.
    #
    # Correção escolhida (sem feature creep): quando `super` retorna SEM
    # exceção, só pode ter sido o caminho de email desconhecido (no caminho
    # conhecido, o disparo do mailer levanta NameError antes do retorno —
    # capturado no rescue abaixo). Então replicamos o trabalho do caminho
    # conhecido de forma INÓCUA: geramos um token fantasma (SELECT por
    # reset_password_token, como faz o Devise) e executamos uma transação
    # aninhada que grava em registro inexistente (id = -1 → UPDATE de 0
    # linhas, com SAVEPOINT/RELEASE — mesmas 3 queries adicionais do save).
    # Nenhum dado é alterado; o número de queries fica idêntico (5 = 5).
    #
    # NOTA: o custo do raise/rescue do NameError não é replicado (seria um
    # anti-pattern lançar exceção de propósito); o delta residual é de
    # microssegundos e dominado pelo I/O das queries, que ficam iguais.
    unless resource.persisted?
      _raw, enc = Devise.token_generator.generate(resource_class, :reset_password_token)
      resource_class.transaction(requires_new: true) do
        resource_class.where(id: -1).update_all(
          reset_password_token: enc,
          reset_password_sent_at: Time.now.utc
        )
      end
    end
  rescue NameError => e
    raise unless e.name == :Mailer

    # Bug 9 (bug_report_23_bug-finder-r3): logamos o erro real
    # (mail_unavailable) apenas internamente, para o administrador perceber
    # que o mailer está fora do ar — mas o flash exposto ao usuário final
    # usa a MESMA chave/tipo (:notice, :send_paranoid_instructions) que o
    # caminho paranoid (email desconhecido) já usa. Antes desta correção, o
    # flash divergia (:alert, :mail_unavailable) e, como o ActionMailer
    # nunca está montado nesta aplicação, TODO email conhecido caía
    # deterministicamente aqui — reabrindo a enumeração de contas que o
    # `paranoid` deveria eliminar, mesmo com status HTTP idêntico (B8).
    Rails.logger.error(
      "[Users::PasswordsController] #{I18n.t('devise.passwords.mail_unavailable')} " \
      "(email=#{resource_params[:email].inspect})"
    )
    set_flash_message!(:notice, :send_paranoid_instructions)
    # Bug 2 (bug_report_23_bug-finder, 2ª rodada): status explícito
    # `:see_other` (303) para bater com `config.responder.redirect_status`
    # do projeto — o caminho paranoid (email desconhecido) responde via
    # `respond_with`/responder Devise, que já usa 303; sem isso, este
    # redirect manual cairia no default do Rails (302) e reintroduziria uma
    # diferença de status observável entre email conhecido/desconhecido.
    redirect_to new_user_session_path, status: :see_other
  end
end
