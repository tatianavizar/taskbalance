Rails.application.routes.draw do
  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }

  # Page d'accueil
  root "pages#home"

  # Devise pour les utilisateurs
  devise_for :users, controllers: {
    registrations: "users/registrations",
    passwords: "users/passwords",
    confirmations: "users/confirmations",
    sessions: "users/sessions"
  }
  devise_scope :user do
    get "users/password/sent", to: "users/passwords#sent", as: :sent_user_password
    get "users/confirmation/pending", to: "users/confirmations#pending", as: :pending_user_confirmation
  end

  # Vérification de santé du serveur
  get "up" => "rails/health#show", as: :rails_health_check

  # Intro avant l'inscription (I1 à I3)
  get "intro", to: redirect("/intro/1"), as: :intro_start
  get "intro/:step", to: "intro#show", as: :intro, constraints: { step: /\d+/ }

  # Compte (F4) : prénom, email et mot de passe se modifient chacun sur leur écran.
  get "compte" => "accounts#show", as: :account
  scope "compte", controller: "accounts" do
    get "prenom", action: :edit_first_name, as: :edit_first_name
    patch "prenom", action: :update_first_name
    get "email", action: :edit_email, as: :edit_email
    patch "email", action: :update_email
    get "mot-de-passe", action: :edit_password, as: :edit_password
    patch "mot-de-passe", action: :update_password
    patch "notifications", action: :update_notifications, as: :account_notifications
  end

  # Fil de notifications (H) et désinscription en un clic depuis un email (D9).
  get "notifications" => "notifications#index", as: :notifications
  patch "notifications/lecture" => "notifications#read_all", as: :read_all_notifications
  get "notifications/:id" => "notifications#show", as: :notification, constraints: { id: /\d+/ }
  get "desinscription/:token" => "unsubscribes#show", as: :unsubscribe
  post "desinscription/:token" => "unsubscribes#create"
  post "desinscription/:token/reactiver" => "unsubscribes#resubscribe", as: :resubscribe

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
