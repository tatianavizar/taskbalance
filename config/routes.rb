Rails.application.routes.draw do
  # Page d'accueil
  root "pages#home"

  # Devise pour les utilisateurs
  devise_for :users

  # Vérification de santé du serveur
  get "up" => "rails/health#show", as: :rails_health_check

  get "dashboard" => "pages#dashboard", as: :dashboard


  resources :users, only: [:show]

  resources :tasks, only: [:index]

  resources :chores, only: [:index, :create, :edit, :update, :destroy] do
    member do
      patch :mark_as_completed
    end
  end

  post 'chores/add'


  resources :households do
    resources :household_members
    resource :chores_setup, only: [:show, :update], controller: "households/chores_setup"
    resource :liking_session, only: [:show, :update], controller: "households/liking_sessions"
  end
  resources :liked_tasks, only: [:create]
end
