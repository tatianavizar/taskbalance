Rails.application.routes.draw do
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
