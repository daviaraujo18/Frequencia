module Admin
  class DashboardController < Admin::ApplicationController
    def index
      if current_user.admin?
        hoje = Time.current.beginning_of_day

        @total_usuarios = User.count
        @usuarios_ativos = User.ativos.count
        @usuarios_inativos = @total_usuarios - @usuarios_ativos
        @usuarios_com_digitais = User.com_digitais.count

        @registros_hoje = TimeRecord.where("punched_at >= ?", hoje).count
        @registros_semana = TimeRecord.where("punched_at >= ?", 7.days.ago).count
        @registros_mes = TimeRecord.where("punched_at >= ?", 30.days.ago).count

        # Sprint 15 (task 15.1): KPIs simples de "Fase A" — contagem direta,
        # sem nenhum cálculo de banco de horas/fechamento (Fase B, Sprint
        # 16+, ver task 15.2). `FrequentadorCache` é o espelho local de
        # frequentadores vindo do Pessoas (Sprint 8/10). `EstacaoPonto` não
        # tem campo de status/ativação no schema atual (não existe coluna
        # `ativa` nem conceito de desativação) — toda estação cadastrada é
        # contada, já que o schema não distingue estações ativas de
        # inativas nesta fase.
        @total_frequentadores = FrequentadorCache.count
        @total_estacoes = EstacaoPonto.count

        # "Últimas Batidas" exibe entradas e saídas em colunas separadas
        # (esquerda/direita) — buscamos os dois tipos independentemente para
        # que ambos os lados fiquem preenchidos mesmo se um tipo for muito
        # mais frequente que o outro no momento.
        @ultimas_entradas = TimeRecord.includes(:user)
                                       .where(punch_type: "entry")
                                       .order(created_at: :desc)
                                       .limit(5)
        @ultimas_saidas = TimeRecord.includes(:user)
                                     .where(punch_type: "exit")
                                     .order(created_at: :desc)
                                     .limit(5)
      end
    end
  end
end
