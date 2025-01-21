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
  delete 'chores/remove', to: 'chores#remove', as: :chore_remove


  resources :household_members, only: [:new, :create]


  resources :households, only: [:new, :create]

  resources :liked_tasks, only: [:create]
end
