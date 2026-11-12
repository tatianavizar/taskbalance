# 50/50 — plan de travail de l'app mobile

Ce plan part du [backlog](backend-backlog.md) et des 104 écrans du canvas (https://claude.ai/artifact/KmQFCsbQNFrSTRtzDnc1FN). Il relève les écarts entre les deux, liste les décisions produit à prendre, puis découpe le travail en lots ordonnés.

Tailles pour une personne : **S** = moins d'une demi-journée, **M** = 1 à 3 jours, **L** = plus de 3 jours.

## 1. Choix technique

**Rails 8 + Turbo + Stimulus, dans des coquilles Hotwire Native iOS et Android.** Pas de React Native.

- Tous les écrans restent des vues Rails servies par ce dépôt. Les coquilles natives (Swift / Kotlin, quelques centaines de lignes chacune) apportent :
  - la barre d'onglets native (Accueil, Tâches, Bilan, Foyer) avec une pile de navigation par onglet ;
  - les modales et les sheets natives ;
  - les notifications push APNs / FCM ;
  - les liens universels (un email d'invitation ouvre l'app) ;
  - la présence sur l'App Store et le Play Store.
- La même app tourne dans un navigateur mobile. Cela sert pour le développement, et de repli pour une personne invitée qui n'a pas encore installé l'app.
- **Ce que ça change dans le backlog :**
  - **Priorité 4 :** Web Push est remplacé par APNs / FCM.
  - **1.5 :** la barre d'onglets HTML est masquée dans les coquilles natives.
  - Ajouts : un fichier de configuration des chemins (path configuration), des composants bridge et des liens universels.
- **Socle à nettoyer avant d'empiler les écrans :**
  - Un seul pipeline d'assets : on garde Propshaft, on retire Sprockets, Bootstrap, sassc, font-awesome-sass et simple_form.
  - Tailwind avec les tokens du [design system](design-system.md).
  - Solid Cable pour les mises à jour en direct.
  - Un service de suivi d'erreurs (G4 annonce « L'équipe est déjà prévenue »).

**Principes d'architecture**
- **Une source unique pour les chiffres.** La semaine en cours est calculée en direct par le même objet (`WeeklyStats`) qui écrit `household_weeks` à la clôture. Accueil, bilan, emails et push lisent tous cet objet.
- **Les règles dans des constantes.** Part juste, zone ± 10, seuils de niveaux, fenêtre de 52 semaines, 85 %. Les écrans de règles (I1 à I4) et les libellés « entre 40 et 60 % » les lisent au lieu de les coder en dur, pour suivre automatiquement la taille du foyer.
- **Une librairie de composants.** Partials et helpers sous `app/views/components/`, avec Stimulus. On la construit au lot 0, à partir des listes de composants relevées dans les écrans (section 5).
- **Les mises à jour en direct.** `broadcasts_refreshes` par foyer, avec le morphing de Turbo : quand un membre enregistre une tâche, l'accueil des autres membres se met à jour.

## 2. Déjà fait

- **1.1 :** le jeton d'invitation est généré avant la validation, et un email invalide réaffiche le formulaire au lieu d'une erreur 500. Tests modèle et contrôleur ajoutés.
- **1.2 :** « Fait par » est retiré. L'auteur d'un enregistrement est toujours `current_user`, et un `user_id` envoyé est ignoré. Tests mis à jour.
- **Lot 0** (socle mobile) et **lot 1** (comptes, foyer, écrans A1–A10, B1, B2, F4, F7, intro I1–I3) : fusionnés dans `mobile-v1`.
- **Lot 5a** (moteur : `WeeklyStats`, bilans, niveaux, pauses) : sur la branche `lot5a-engine`, en cours de reprise.
- **Tests :** dans le sandbox, lancer `PARALLEL_WORKERS=1 bin/rails test` (le socket DRb des tests parallèles y est bloqué).

## 3. Écarts entre les maquettes et le backlog

Ce que les écrans demandent et que le backlog ne prévoit pas, ou prévoit autrement. Les numéros renvoient au backlog.

### Comptes et accès (A1 à A10)
- **Confirmation de l'email (A2, A10) — NEW, M.** Devise `confirmable` avec un lien valable 24 h, un renvoi avec compte à rebours, et « Changer d'adresse ». L'inscription par invitation (B7) confirme d'office.
- **Anti-énumération (A3, A5, A7) — NEW, M.** `config.paranoid`. Une inscription avec un email déjà connu ressemble à un succès et envoie un email « vous avez déjà un compte ».
- **Envois limités (A7, A10) — NEW, S.** Limite côté serveur sur les emails de réinitialisation et de confirmation, et compte à rebours sur le bouton.
- **Jeton vérifié à l'ouverture (A8, A9) — NEW, S.** Devise ne vérifie le jeton qu'à l'envoi du formulaire. Il faut afficher A9 dès l'ouverture d'un lien expiré.
- **Fuseau de l'utilisateur (A7) — 1.4, S.** Une heure d'expiration s'affiche avant qu'un foyer existe : ajouter `users.time_zone`.
- **Changement de mot de passe connecté (F4) — 1.5, S.** Avec saisie du mot de passe actuel. La déconnexion désinscrit aussi le téléphone des push.
- **Durée de session (A4, G5) — NEW, M.** Une session ouverte dans l'app native ne doit pas disparaître quand l'app est fermée. Un enregistrement en cours doit survivre à une reconnexion.

### Foyer et invitations (B1 à B15)
- **Lien d'invitation (B6 à B9) — 3.1, M.** Une route `GET /invitations/:token` envoie vers B7 (personne non connectée), B9 (personne connectée avec le bon email) ou une variante de B8 (autre compte, lien expiré, annulé ou déjà utilisé).
- **Accès avant d'être membre (B7, B10 à B12, B14) — 3.2, M.** On ne rejoint le foyer qu'à la dernière étape. Il faut donc `invitations.invitee_id`, un accès en lecture et en écriture aux tâches, aux préférences et à la proposition de répartition avant l'adhésion, et la reprise au bon écran après un redémarrage de l'app.
- **Cycle de vie de l'invitation (B5, B13, B15) — 3.2, S.**
  - États à ajouter : `declined`, `sent_at`, `resend_count`.
  - L'index unique `(email, household_id)` interdit de réinviter après une annulation, un refus ou une expiration. Le remplacer par un index unique partiel sur les invitations en attente.
- **Couleur et monogramme dès 2 membres (F1, P1, P2) — 2.2e vers 1.7, S.** Les avatars de F1 en ont à deux. Le monogramme est recalculé à chaque arrivée, sauf s'il a été modifié à la main.
- **Avancement de la mise en place (D1, B12, B1 à C4) — 2.2, S.** Une checklist « Mise en place 2 sur 4 » qu'on reprend où on l'a laissée.

### Catalogue, tâches et préférences (C1 à C16, M1)
- **Tâches du catalogue sans charge ni fréquence (C1, C4b, B11) — NEW, M.**
  - Les tâches du catalogue n'ont ni charge par défaut, ni fréquence. `chores_setup` crée des tâches dont les deux charges sont à faux.
  - Ajouter la charge par défaut, `frequency` et `times_per_period` (« 2 fois par semaine »).
  - C'est un prérequis de 2.2c : sans ces données, la part prévue n'a rien à calculer.
- **Tâche perso récurrente (C5, C6) — NEW, S.**
  - Impossible aujourd'hui : `recurring_chores.task_id` est NOT NULL.
  - La règle « au moins une charge » doit s'appliquer à toute tâche, et la durée doit valoir au moins 1.
- **Préférences à trois choix (B10, C3, P7) — à faire passer en V1, S à M.**
  - Le backlog les range dans « Plus tard ».
  - Créer `chore_preferences` : une préférence par tâche, tâches perso comprises, visible de son autrice ou auteur seulement.
- **Suppression d'une tâche perso (C7) — NEW, S.** Ajouter `chores.created_by_id`. Seule la personne qui l'a créée, ou celle qui gère le foyer, peut la supprimer.
- **Tâches mensuelles et annuelles (C4b) — 2.2c, S.** Elles ont besoin d'une date d'ancrage pour savoir dans quelle semaine elles comptent.

### La semaine (D1 à D16, E1 à E16)
- **Occurrences de la semaine (D3, D4, D12, D13) — NEW, M à L.** Les tâches de la semaine (en retard, aujourd'hui, plus tard), le bouton « Fait » et les filtres reposent sur des occurrences générées chaque semaine. `RecurringChoreScheduler` est dans « Plus tard » : il passe en priorité.
- **Enregistrement d'une tâche hors répartition (D6) — NEW, S.** Le nom et la catégorie sont saisis à la main, sans tâche liée.
- **Choix du jour (D10) — 2.1, S.** Le sélecteur dit si la semaine est encore ouverte ou déjà close.
- **Modifier ou supprimer un enregistrement (E12, E16) — NEW, M.** Réservé à son autrice ou auteur, avec un comportement défini quand le jour change de semaine ou que la semaine est close.
- **Pas de double enregistrement (G4) — NEW, S.** Une clé d'idempotence évite qu'un « Réessayer » après une erreur crée deux enregistrements.
- **Mon journal (E6) — NEW, M.** Tous les enregistrements de l'utilisateur, ceux détachés d'un foyer compris, groupés par jour et par semaine.
- **Mises à jour en direct (D2, D3, D8, E4) — NEW, M.** Diffusion Turbo Streams par foyer.
- **Bilan enrichi (E1, E2, P4) — 2.3, M.**
  - Le contrefactuel « il aurait suffi que Karim prenne 3 des 18 tâches ».
  - Le tableau par catégorie, sur les deux charges et le temps.
  - La navigation vers n'importe quelle semaine passée.
  - Le nombre de semaines déséquilibrées d'affilée.
  - « Mis à jour à 18:32 ».
- **Pourquoi une semaine ne compte pas (E2, E7, E9, E10) — 2.1, S.** Ajouter `household_weeks.neutral_reason` : pas de charge mentale, pas d'exécution, pause, foyer seul, arrivée d'un membre.
- **Question d'absence stockée (E11, P5, H5, P9) — 2.2, M.**
  - Tables `absence_inquiries` et `absence_answers`.
  - Un job le mercredi à 20:00 dans chaque fuseau.
- **Historique des niveaux (E8, E9, E13, F8) — NEW, S.**
  - Une table `level_changes` pour la date d'atteinte d'un niveau, l'écran vu une fois par membre, et le retour à l'état d'avant quand une pause annule une régression.
- **Réassignation ponctuelle (D5, D15, D16) — 2.2c, M.**
  - Une table `chore_reassignments`.
  - Accepter ou refuser, avec une notification dans les deux sens.
  - Expiration à la clôture de la semaine.
- **Répartition de la semaine stockée (C9, D11, B11, B14, C12) — 2.2c, M.**
  - 2.2c ne prévoit de table que pour les réglages en attente.
  - Ajouter `week_plans`, avec une validation par membre, un instantané des assignations et l'écart reporté.
- **Notifications dans l'app (E3, E5, E8, E13, D15, D16) — NEW, M.** Un fil avec l'état lu ou non lu, et l'écran sur lequel on arrive en ouvrant un push.

### Foyer, compte, erreurs, notifications, intro, foyer de 3 (F, G, H, I, P)
- **Quitter le foyer (F2) — 3.3, M.**
  - Mettre à nul le `household_id` des enregistrements de la personne qui part. Le foyer garde les totaux de `household_weeks`, sans le détail.
  - Règles à écrire : le dernier membre qui part ; ce que deviennent le niveau et le compteur quand un foyer de deux devient solo.
- **Supprimer son compte (F5) — 3.6, S.** Le prénom enregistré dans `household_weeks` est anonymisé.
- **Pauses (F6, F8, F10, E10) — 2.2b, S.**
  - Ajouter `declared_by_id`.
  - Modifier les dates d'une pause, l'arrêter plus tôt, interdire deux pauses qui se chevauchent.
- **Préférences de notification (F4, H3, H4) — NEW, M.**
  - Une table `notification_preferences` : par utilisateur, par événement et par canal.
  - Désinscription en un clic avec l'en-tête `List-Unsubscribe`.
- **Événements envoyés (H1, F4) — 3.7, M.** La liste est plus large que dans 3.7 : tâche assignée, répartition du lundi, question d'absence et sa décision, pauses, mise à zéro de l'écart, « Prêt » (B12).
- **Hors ligne (G1) — NEW, S à M.**
  - Un gestionnaire d'erreur de visite côté natif, et un bandeau Stimulus qui réagit aux événements `online` / `offline`.
  - Aucun cache.
- **Pages d'erreur (G2 à G5) — NEW, S.** `exceptions_app` avec des pages en français. Choisir entre 404 et 403 pour une personne qui n'est pas membre (le code renvoie 404, G3 montre 403).
- **Intro (I1 à I3) — NEW, S.** Une route publique, vue une seule fois, avant l'inscription.
- **Écran de règles (I4) — NEW, S.** Les valeurs s'adaptent à la taille du foyer.
- **Taille maximale du foyer (P2, P6) — NEW, S.** La palette n'a que 6 couleurs, et à 10 membres la zone va de 0 à 20 %.
- **Vérification technique — NEW, S.**
  - `allow_browser versions: :modern` ne doit pas renvoyer une erreur 406 à la WebView native.
  - Le manifeste PWA dit encore « TaskBalance ».

## 4. Décisions produit à prendre

**Tranchées le 2026-11-08** (voir [decisions.md](decisions.md)) :
- **D10 :** la session reste ouverte 1 semaine.
- **D11 :** la confirmation de l'email ne bloque pas la création du foyer.
- **D13 :** un seul foyer par compte en V1.
- **D16 :** monogramme selon 2.2e : l'initiale, deux lettres seulement quand deux initiales coïncident, modifiable.

Les autres restent ouvertes. Chacune bloque le lot indiqué.

| # | Question | Écrans | Bloque |
|---|---|---|---|
| D1 | Le bandeau « Annuler · 9 s » d'D8 est montré, mais l'annulation en 10 s a été rejetée dans les décisions, et le backlog la garde dans « Plus tard ». On la garde ? | D8 | Lot 4 |
| D2 | D15 et D16 disent qu'une tâche réassignée « compte dans votre charge mentale cette semaine », alors que le bilan ne compte que ce qui est enregistré. On change le texte (« prévue ») ou la règle ? | D15, D16 | Lot 6 |
| D3 | Une pause déclarée après coup rend neutre une semaine déjà définitive (E10, annulation d'une régression). On écrit l'exception à « un bilan définitif n'est jamais réécrit » ? | E10, F8 | Lot 5 |
| D4 | Qui peut remettre l'écart à zéro : la personne qui le porte, ou celle qu'il avantage ? Le backlog dit les deux (constat 17 de l'audit). | C9 | Lot 6 |
| D5 | La marge du niveau ultime : quelle formule, puisque la fenêtre de 52 semaines glisse ? | E9 | Lot 5 |
| D6 | « Tout le foyer » comme assignation dans P8 : simple raccourci d'affichage quand tout le monde est assigné, ou erreur de maquette ? | P8 | Lot 2 |
| D7 | I3 dit qu'une semaine déséquilibrée « ne fait pas reculer, sauf au niveau ultime ». Le backlog dit jamais. Quel texte ? | I2, I3 | Lot 10 |
| D8 | H2 donne des textes différents selon la personne, alors que 3.7 dit « mêmes mots pour tous ». On reformule en « mêmes faits et mêmes chiffres » ? | H2 | Lot 8 |
| D9 | L'email est un canal à part avec ses propres réglages (H4), ou toujours le repli du push (priorité 4) ? Que plafonne la limite « un bilan et une alerte par semaine », et par canal ou en tout ? | H1, H4 | Lot 8 |
| D12 | Les renvois d'invitation : 3 envois ou 4 ? Comptés par invitation ou par email et foyer ? | B5, B13 | Lot 3 |
| D14 | Qui peut modifier les tâches du foyer (C1, M1) ? Et que devient la répartition déjà validée quand on ajoute ou retire une tâche en cours de semaine ? | M1, C2, C5, C7 | Lot 2 |
| D15 | Une personne invitée mais pas encore inscrite compte-t-elle dans la part juste de la répartition de départ (« À trois… 33 % ») ? | P1, C4 | Lot 2 |
| D17 | Taille maximale du foyer ? | P2, P6 | Lot 10 |
| D18 | Proposition de répartition calculée à partir des préférences : C4, C12 et B11 la montrent, le backlog la met dans « Plus tard » (L). En V1 ? | C4, B11 | Lot 2 |
| D19 | Restent ouvertes, depuis le handoff : textes d'E4 et E15, repère à 50 % du temps, variantes d'E10, E4 et E2 pour un foyer de 3, chiffres divergents entre écrans (constat 20), CGU et politique de confidentialité. | — | Lot 10 |

## 5. Lots

Ordre conseillé. Chaque lot se termine sur des écrans utilisables de bout en bout, avec des tests. La coquille native commence au lot 0 : chaque écran est construit et vérifié dedans dès le départ, pas adapté à la fin.

### Lot 0 — Socle mobile (≈ 1,5 semaine)
- Nettoyer le pipeline d'assets : Propshaft seul, Tailwind seul, retirer Bootstrap, Sprockets, sassc, font-awesome-sass et simple_form. M
- Mettre les tokens du design system dans Tailwind, charger Unbounded et Figtree, faire un layout mobile de 390 px avec les zones de sécurité. S
- Mettre l'app en français par défaut : `rails-i18n`, `devise-i18n`, dates sans point (« 8 oct »). M
- Construire la librairie de composants, première passe :
  - boutons, champs avec erreur, résumé d'erreurs, encadré info menthe ;
  - carte, ligne de liste, avatar, pastille de statut, interrupteur, contrôle segmenté ;
  - sheet de confirmation, CTA collé en bas, barre d'onglets, en-tête.

  M
- Les composants **Balance** (N membres, repère à la part juste, zone) et **progression de niveau**. M
- Le helper `hotwire_native_app?` : masquer la barre d'onglets et l'en-tête web dans les coquilles. S
- Coquilles Hotwire Native iOS et Android minimales :
  - 4 onglets natifs ;
  - le fichier de configuration des chemins (modales pour D6, D10, E12, E16 et D15 ; mise en place sans onglets ; remplacement de l'écran pendant l'onboarding pour qu'on ne revienne pas en arrière) ;
  - gestionnaire d'erreur de visite.

  L
- Mettre en place Solid Cable et le suivi d'erreurs, et vérifier `allow_browser` dans la WebView. S
- Pages d'erreur G2 à G5 en français. S

### Lot 1 — Comptes et foyer (≈ 1,5 semaine) · backlog 1.3 à 1.8
- 1.3 Envoi des emails (choisir le fournisseur), avec l'expéditeur de l'app. S
- 1.4 Fuseau du foyer **et** de l'utilisateur. Helper « Semaine 41 » et ses dates. S
- 1.5 Navigation (onglets), compte F4, déconnexion, changement de mot de passe connecté. M
- 1.6 Validation du nom du foyer. 1.7 Prénom. 1.8 Rôle de gestion du foyer. S chacun
- Couleur et monogramme sur `household_members` dès 2 membres : l'initiale, deux lettres en cas de doublon, modifiable (D16). S
- Confirmation de l'email, non bloquante : on peut créer le foyer avant de confirmer (D11). Anti-énumération, jeton vérifié à l'ouverture (A8, A9), limites d'envoi. M
- Session de 1 semaine (D10) : `remember_for 1.week`, cookie persistant dans la coquille native. S
- Un seul foyer par compte (D13) :
  - index unique sur `household_members.user_id` ;
  - `User has_one :household` au lieu de `has_many` ;
  - une personne déjà dans un foyer qui ouvre une invitation (B9) doit d'abord quitter le sien ;
  - retirer les listes de foyers (`households#index`).

  S à M
- Intro I1 à I3 avant l'inscription. S
- **Écrans :** A1 à A10, B1, B2, F4, F7, I1 à I3.

### Lot 2 — Catalogue et mise en place (≈ 2 semaines) · backlog 2.2d, 3.4, partie de 2.2c
- Catalogue : charge par défaut, fréquence, `times_per_period`, traduction et clé stable par tâche (3.8). M
- `Chore` : fréquence, occurrences par semaine, date d'ancrage, `created_by_id`, `active` (3.4). M
- 2.2d `chore_assignees`, au moins une personne assignée. M
- Tâche perso récurrente, validations C6, suppression C7. S
- `chore_preferences` à trois choix (B10, C3, P7). S à M
- Avancement de la mise en place (`setup_step`). S
- `week_plans` + validations : répartition de départ, proposée par la personne qui crée le foyer ou par la personne invitée, « Attendre » ou « Avancer » (C12, B11, B14). M
- Réglages de la répartition C16, avec validation par tous et validation automatique. M
- **Écrans :** C1 à C8, C12, C16, M1, B10, B11, B14.

### Lot 3 — Invitations et consentement (≈ 1,5 semaine) · backlog 3.1, 3.2
- `GET /invitations/:token`, aiguillage B7 / B9 / B8. M
- On ne rejoint le foyer qu'à la dernière étape, avec un accès avant l'adhésion (`invitee_id`). M
- États (avec `declined`), expiration à 14 jours, renvois (D12), annulation, index unique partiel. M
- Erreurs claires (son propre email, déjà membre, déjà invité, domaine incomplet). S
- **Écrans :** B3 à B9, B12, B13, B15.

### Lot 4 — Enregistrer et voir sa semaine (≈ 2,5 semaines) · backlog 2.3, scheduler
- Brancher `RecurringChoreScheduler` : générer les occurrences de la semaine. M à L
- Onglet Tâches D3 et D4 : en retard, aujourd'hui, plus tard, « Fait » en un geste, filtres. M
- Enregistrer D6, D7 et D10 : jour jusqu'à 7 jours en arrière, tâche hors répartition, durée ± 5 min, clé d'idempotence. M
- Modifier et supprimer un enregistrement E12, E16. M
- Mon journal E6, enregistrements détachés compris. M
- Accueil D1, D2, D8, D12 sur les vraies données via `WeeklyStats`, avec mise à jour en direct. M
- Détail d'une tâche D5 et son historique. S
- **Écrans :** D1 à D8, D10, D12, E6, E12, E16.

### Lot 5 — Le moteur (≈ 3 semaines) · backlog 2.1, 2.2, 2.2b
- Table `household_weeks` : instantané par membre (prénom compris), `neutral_reason`, pauses de la semaine. M
- Jobs du dimanche 20:00 (provisoire) et du lundi 3:00 (définitif) dans chaque fuseau. Idempotents, avec rattrapage des semaines manquées. M
- Niveaux, `balanced_weeks_count`, `level_changes`, fenêtre glissante du niveau ultime (D5). M
- Séries de semaines vides, états du foyer, régression et blocage, déblocage. M
- Question d'absence : `absence_inquiries`, `absence_answers`, job du mercredi 20:00. M
- Pauses : `member_pauses`, `declared_by_id`, pause rétroactive limitée, annulation d'une régression (D3). M
- Bilans E1, E2, E7, E9, E10, E14 ; alertes E3, E4, E5, E11, E13, E15, D13 ; niveaux E8, E9. M
- **Écrans :** E1 à E5, E7 à E11, E13 à E15, D13, F6, F8, F10.

### Lot 6 — Répartition de la semaine (≈ 2 semaines) · backlog 2.2c
- Proposition du lundi : part prévue en occurrences, écart reporté (moyenne des deux charges), compensation plafonnée à la zone. L
- Validation à deux états, verrouillage une fois validée, remise à zéro de l'écart (D4). M
- Avertissement quand une modification sort de la zone, sans bloquer l'enregistrement. S
- Réassignation ponctuelle D15, D16 (D2). M
- **Écrans :** C9, D11, D15, D16, C8.

### Lot 7 — Confiance et départs (≈ 1,5 semaine) · backlog 3.3 à 3.6
- Quitter le foyer F2 : réassigner ses tâches, mettre à nul le `household_id` de ses enregistrements, transmettre la gestion du foyer. M
- Supprimer le foyer F3 : réservé à la personne qui le gère, avec saisie du nom. S
- Supprimer son compte F5 : anonymisation, réassignation des tâches. M
- **Écrans :** F1, F2, F3, F5, F11.

### Lot 8 — Emails et notifications (≈ 2 semaines) · backlog 3.7, priorité 4 réécrite
- Table `notification_preferences`, désinscription en un clic (D9). M
- Catalogue d'événements complet, limite d'envoi, textes adaptés à chaque destinataire (D8). M
- Fil de notifications dans l'app, avec l'état lu ou non lu. M
- Push APNs / FCM :
  - une table `push_devices` ;
  - une gem côté serveur (Action Push Native ou Noticed v2) ;
  - chaque notification porte un chemin, pour que le toucher ouvre le bon écran ;
  - nettoyage des jetons invalides.

  L
- Composant bridge pour l'autorisation des notifications. H1 vient avant l'inscription : l'app garde le jeton du téléphone et l'envoie au serveur après la connexion. M
- Emails H3, et emails d'alerte E3, E4, E5. M
- **Écrans :** H1 à H5, F4 (notifications), P9.

### Lot 9 — Finitions natives (≈ 1,5 semaine)
- Liens universels et App Links (`apple-app-site-association`, `assetlinks.json`) pour les emails d'invitation, de réinitialisation et de confirmation. M
- Composants bridge : sélecteur de date (D10, F6), menu « ⋯ » (E6), confirmation native (E16, B15, C2), ouverture des réglages du téléphone. M
- Hors ligne G1 (bandeau et boutons désactivés), session expirée G5 en modale. S
- Tirer pour rafraîchir, icônes, écran de lancement, fiches des stores. M

### Lot 10 — Foyer de 3 et plus, accessibilité, lancement (≈ 2 semaines) · backlog 2.2e
- Une barre par membre, panneau d'assignation P6, choix de la couleur P2, inviter plusieurs membres P1, taille maximale (D17). M
- Écran de règles I4 qui lit les constantes. S
- Passe d'accessibilité : cibles de 44 px, rôles ARIA, VoiceOver et TalkBack (constats 16, 25 et 27 de l'audit). M
- Questions restantes (D7, D19). S
- CGU et politique de confidentialité, liées depuis A2, et petit bandeau cookies (décision 2026-11-12). S
- TestFlight, test interne sur le Play Store, puis publication. M
- **Écrans :** P1 à P8, C14, I4.

**Total indicatif :** environ 21 semaines pour une personne (somme des lots). C'est une estimation de taille, pas un engagement. Les lots 4 et 5 portent le produit : on peut tester avec de vrais foyers dès la fin du lot 5, dans la coquille native, avant les notifications.

## 6. Ce qui peut avancer en parallèle

| Lot | Dépend de | En parallèle de |
|---|---|---|
| 0 socle web | — | coquilles natives |
| Coquilles natives (part du lot 0) | config des chemins | socle web |
| 1 comptes | 0 | — |
| 2 catalogue | 1 | 3, 5a, 7 |
| 3 invitations | 1 | 2, 5a |
| 4 enregistrer | 2 | 5a, 7, 8a |
| 5a moteur (calculs et jobs) | 1 (fuseau, membres) | 2, 3, 4 |
| 5b moteur (écrans) | 4, 5a | 6 |
| 6 répartition | 2, 5a | 5b, 7, 8b |
| 7 départs | 2 (assignations), 3 | 4, 5, 6 |
| 8a préférences et emails | 1 (1.3) | 2 à 4 |
| 8b push et événements | 5a, coquilles | 6, 7 |
| 9 finitions natives | coquilles | tout, en continu |
| 10 foyer de 3, lancement | 6 | — |

**Trois pistes :**
- **Piste produit (Rails, écrans) :** 0 → 1 → 2 → 4 → 5b → 6 → 10. C'est le chemin critique, environ 13 semaines.
- **Piste moteur (Rails, calculs) :** 5a dès la fin du lot 1, testé sur des fixtures d'enregistrements, puis 3, 7 et 8a.
- **Piste native (Swift, Kotlin) :** coquilles au lot 0, bridges, push (8b), liens universels, stores (9).

**Points de couture à surveiller :**
- **`WeeklyStats` :** son interface (entrées, sorties) se fixe au début du lot 5a. Les écrans d'accueil du lot 4 la consomment.
- **Proposition par la personne invitée (B11, B14) :** la répartition vient du lot 2, mais l'accès avant adhésion vient du lot 3. Livrer d'abord l'accès, ou bouchonner l'accès dans le lot 2.
- **Config des chemins native :** chaque nouvel écran modal ou plein écran y ajoute une règle. Un seul fichier, à revoir à chaque PR.

Avec trois personnes : environ 13 à 14 semaines au lieu de 21. Avec deux (produit + moteur, le natif réparti entre elles) : environ 15 semaines.

## 7. Prochaines étapes
1. Reporter les ajouts de la section 3 et les décisions D10, D11, D13, D16 dans `docs/backend-backlog.md`.
2. Lancer le lot 0 et les coquilles natives.
3. Trancher les décisions restantes avant le lot qu'elles bloquent.
