module Presenca
  # Controller base do contexto WebView-facing da Estação (ADR-001, Seção 4).
  # Sem autenticação de sessão administrativa — as rotas de presença são
  # consumidas diretamente pela Estação JavaFX via WebView. Mantém o layout
  # "application" (AdminLTE) já usado pelas views de presença desde a Sprint A.
  class ApplicationController < ::ApplicationController
  end
end
