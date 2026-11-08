Rails.application.routes.draw do
  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }

  # Page d'accueil
  root "pages#home"

  # Devise pour les utilisateurs
  devise_for :users, controllers: {
    registrations: "users/registrations",
    passwords: "users/passwords",
    confirmations: "users/confirmations"
  }

  # Vérification de santé du serveur
  get "up" => "rails/health#show", as: :rails_health_check

  get "dashboard" => "pages#dashboard", as: :dashboard
  get "bilan" => "reports#show", as: :report

  # Pages d'erreur (config.exceptions_app = routes)
  match "/404", to: "errors#not_found", via: :all
  match "/403", to: "errors#forbidden", via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#server", via: :all

  # Configuration des chemins pour les coquilles Hotwire Native
  get "configurations/ios_v1", to: "configurations#show", defaults: { platform: "ios", format: :json }
  get "configurations/android_v1", to: "configurations#show", defaults: { platform: "android", format: :json }

  # Catalogue de composants, en développement et en test seulement
  get "styleguide" => "styleguide#show" if Rails.env.local?


  resources :tasks, only: [:index]

  resources :chores, only: [:index, :new, :create, :edit, :update, :destroy] do
    resource :completion, only: [:new, :create], controller: "chores/completions"
  end

  resources :households do
    resources :household_members
    resource :chores_setup, only: [:show, :update], controller: "households/chores_setup"
    resource :liking_session, only: [:show, :update], controller: "households/liking_sessions"
  end
  resources :liked_tasks, only: [:create]
end
