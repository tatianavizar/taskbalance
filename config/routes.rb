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
    # The one-time link printed by `admin:bootstrap` / `admin:reset_two_factor`.
    get "two_factor/link/:token", to: "two_factors#redeem", as: :two_factor_link, constraints: { token: /[^\/]+/ }
  end
  ActiveAdmin.routes(self)

  # Vérification de santé du serveur
  get "up" => "rails/health#show", as: :rails_health_check

  # Intro avant l'inscription (I1 à I3)
  get "intro", to: redirect("/intro/1"), as: :intro_start
  get "intro/:step", to: "intro#show", as: :intro, constraints: { step: /\d+/ }

  # Comment on calcule ? (I4) : les règles, publiques, lues dans HouseholdRules.
  get "regles", to: "rules#show", as: :rules

  # Pages légales (brouillon) : conditions d'utilisation et confidentialité.
  get "cgu", to: "legal#terms", as: :terms
  get "confidentialite", to: "legal#privacy", as: :privacy

  # « OK » du bandeau cookies : retient qu'il a été lu, dans un cookie nécessaire.
  resource :cookie_notice, path: "cookies", only: [ :create ]

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
  # Lot 8b : H1 (autoriser les notifications, coquilles natives) et le jeton du
  # téléphone, envoyé par le composant bridge « push-notifications ».
  get "notifications/autoriser" => "push_permissions#show", as: :push_permission
  resource :push_device, path: "appareils", only: [ :create, :destroy ]
  get "desinscription/:token" => "unsubscribes#show", as: :unsubscribe
  post "desinscription/:token" => "unsubscribes#create"
  post "desinscription/:token/reactiver" => "unsubscribes#resubscribe", as: :resubscribe

  get "dashboard" => "pages#dashboard", as: :dashboard
  # Onglet « Foyer » des coquilles natives : une adresse fixe.
  get "foyer" => "pages#household", as: :household_home
  # Bilan (E1, E7, E10, E14), les 4 semaines (E2) et les niveaux (E8, E9, E13).
  get "bilan" => "reports#show", as: :report
  get "bilan/historique" => "reports#history", as: :report_history
  get "niveaux" => "levels#show", as: :levels

  # La question d'absence (E11, P5) : réponses et corrections, jusqu'au mercredi 20:00.
  resources :absence_inquiries, path: "absences", only: [ :index, :show ] do
    member do
      post :answer
      patch :correct
    end
  end

  # Pauses : déclarer la sienne (F6) ou celle d'un membre absent (F8, ?pour=), la liste (F10).
  resources :member_pauses, path: "pauses", only: [ :index, :new, :create, :edit, :update ] do
    post :stop, on: :member
  end

  # Pages d'erreur (config.exceptions_app = routes)
  match "/404", to: "errors#not_found", via: :all
  match "/403", to: "errors#forbidden", via: :all
  match "/422", to: "errors#unprocessable", via: :all
  match "/500", to: "errors#server", via: :all

  # Configuration des chemins pour les coquilles Hotwire Native
  get "configurations/ios_v1", to: "configurations#show", defaults: { platform: "ios", format: :json }
  get "configurations/android_v1", to: "configurations#show", defaults: { platform: "android", format: :json }

  # Liens universels (iOS) et App Links (Android), lot 9 : voir NativeApp.
  get ".well-known/apple-app-site-association", to: "well_known#apple_app_site_association", format: false
  get "apple-app-site-association", to: "well_known#apple_app_site_association", format: false
  get ".well-known/assetlinks.json", to: "well_known#asset_links", format: false

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
  # Une fois l'invitation prise en main (connectée), B12 et le refus passent par
  # /invitation, sans jeton : l'app ne garde que son empreinte.
  get "invitation", to: "invitations#resume", as: :invitee_invitation
  get "invitation/attente", to: "invitations#waiting", as: :invitee_waiting
  post "invitation/refus", to: "invitations#decline", as: :invitee_decline
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
    # P2 : couleur et lettres du membre (ou de la personne invitée, avant d'avoir rejoint)
    resource :member_style, path: "pastille", only: [ :show, :update ], controller: "households/member_styles"
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
