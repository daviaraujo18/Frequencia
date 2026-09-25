# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

  A conexão `pessoas` de teste usa o banco local `frequencia_pessoas_espelho_test`
  com um schema copiado do Pessoas2 (ADR-0006). Uma vez por máquina/CI
  (o `app.frequencia` não tem CREATEDB):

  ```bash
  createdb -h localhost -U postgres -O app.frequencia frequencia_pessoas_espelho_test
  ```

  Antes da suíte (idempotente; só roda com RAILS_ENV=test e banco `*_test`):

  ```bash
  RAILS_ENV=test bin/rails test:pessoas_schema:load
  bin/rails test
  ```

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
