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

  # Back-office (ActiveAdmin 4) : l'équipe 50/50, comptes AdminUser séparés de
  # ceux de l'app, double authentification obligatoire. Pas d'inscription, pas de
  # mot de passe oublié (voir `bin/rails admin:bootstrap`).
  devise_for :admin_users, ActiveAdmin::Devise.config.merge(
    controllers: ActiveAdmin::Devise.controllers.merge(sessions: "back_office/sessions")
  )
  scope "admin", module: "back_office", as: "back_office" do
    resource :two_factor, only: [ :show, :create ]
  end
  ActiveAdmin.routes(self)

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
    # F5 : la suppression elle-même passe par DELETE /users (Users::RegistrationsController#destroy).
    get "supprimer", action: :delete_account, as: :delete_account
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


  resources :tasks, only: [ :index ]

  # D3 (liste de la semaine), D5 (détail), C5/C6/M1 (ajout et modification), C7.
  resources :chores, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    # C7 : confirmation avant de supprimer une tâche perso
    get :delete, on: :member
  end

  # « Fait » en un geste sur une occurrence de la liste (D3).
  resources :chore_occurrences, path: "occurrences", only: [] do
    post :complete, on: :member
  end

  # Enregistrer une tâche (D6, D7, D10), mon journal (E6), corriger (E12) et
  # supprimer (E16) un enregistrement. Seule son autrice ou son auteur le peut.
  resources :chore_logs, path: "journal", only: [ :index, :new, :create, :edit, :update, :destroy ] do
    get :delete, on: :member
  end

  # Invitation, côté personne invitée (B7 à B9, B12). Le jeton fait office d'identifiant.
  resources :invitations, only: [ :show ], param: :token do
    member do
      post :claim
      post :accept
      post :decline
      get :waiting
    end
  end

  resources :households do
    # F3 : confirmation de la suppression (réservée à la personne qui gère le foyer)
    get :delete, on: :member
    # F2 : quitter le foyer
    resource :departure, only: [ :new, :create ], controller: "households/departures"
    # Invitation, côté foyer (B3, B5, B13, B15)
    resources :invitations, only: [ :new, :create, :show, :destroy ], controller: "households/invitations" do
      member do
        post :resend
        get :cancel
      end
    end
    # Mise en place : reprend à l'étape en cours (« Mise en place 2 sur 4 »)
    resource :setup, only: [ :show, :update ], controller: "households/setups"
    # C1, M1, C2 : tâches du foyer
    resource :chores_setup, only: [ :show, :update ], controller: "households/chores_setup"
    # C3, B10 : préférences, privées
    resource :preferences, only: [ :show, :update ], controller: "households/preferences"
    # C12, C4, C8, B11, B14 : répartition
    resource :split, only: [ :show, :update ], controller: "households/splits" do
      get :choice
      post :wait
      post :approve
      # Lot 6 : parts en direct (rien n'est enregistré), C9 remise à zéro de l'écart
      post :preview
      post :reset_gap
    end
    # D15, D16 : réassignation ponctuelle d'une tâche, pour la semaine
    resources :handovers, only: [ :new, :create, :show ], controller: "households/handovers" do
      member do
        post :accept
        post :refuse
        post :cancel
      end
    end
    # C16 : réglages de la répartition
    resource :split_settings, only: [ :show, :update ], controller: "households/split_settings" do
      post :approve
    end
  end
end
