Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Admin frontend
  root to: "dashboard#index"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  get "dashboard", to: "dashboard#index"
  resources :users, except: [:show]
  resources :time_records, only: [:index]

  namespace :presenca do
    get "ValidarFrequentador", to: "validar_frequentador#show"
    get "DynFrequentadoresEstacao", to: "dyn_frequentadores_estacao#index"
    get "DynHashFrequentadoresEstacao", to: "dyn_hash_frequentadores_estacao#show"
    get "CarregaRelogioAtual", to: "carrega_relogio_atual#show"
    post "ajax/SincronizarRegistrosPonto", to: "sincronizar_registros_ponto#create"
    get "InicializarPonto", to: "inicializar_ponto#show"
    get "IniciarPonto", to: "iniciar_ponto#show"
    get "PontoDePresenca", to: "ponto_de_presenca#show"
    get "Frequentador", to: "frequentador#show"
    get "AdicioneEstacao", to: "adicione_estacao#show"
    get "ProblemaRegistro", to: "problema_registro#show"
  end
end
