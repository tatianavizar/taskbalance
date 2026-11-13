# 50/50 — app mobile, première version

50/50 mesure la répartition réelle des tâches dans un foyer, en séparant la charge mentale (planifier, décider) de l'exécution (faire). Chaque membre enregistre ce qu'il a fait. Chaque lundi, le foyer reçoit un bilan factuel et une répartition à valider pour la semaine. Le foyer monte en niveaux à mesure qu'il cumule des semaines équilibrées. L'app s'adresse d'abord à la personne qui porte la charge et veut des faits, puis à chaque membre de son foyer (deux personnes le plus souvent, trois ou plus possible). La première version remplace le prototype web Rails actuel par l'app décrite dans les maquettes ([brief](../docs/brief.md)).

## Contenu

| Artefact | Chemin | Ce qu'il contient |
|---|---|---|
| Brief | [../docs/brief.md](../docs/brief.md) | Le problème, le produit, le périmètre de la V1, ce qui ne se négocie pas |
| Règles produit et backlog technique | [../docs/backend-backlog.md](../docs/backend-backlog.md) | Les règles de calcul (équilibre, niveaux, absence, pauses, clôture, répartition), puis le travail backend par priorité |
| Parcours | canvas, `project/Parcours.dc.html` | Le parcours utilisateur de bout en bout |
| Service blueprint | canvas, `project/Blueprint.dc.html` | Ce qui tourne derrière chaque étape : jobs, emails, notifications |
| Maquettes (prototype cliquable) | canvas https://claude.ai/artifact/KmQFCsbQNFrSTRtzDnc1FN, `project/*.dc.html` | 104 écrans de 390 px avec leurs vrais textes. Les liens entre écrans forment le prototype. `project/canvas.json` regroupe les écrans par section de parcours |
| Composants | canvas, `project/Balance.dc.html`, `project/TabBar.dc.html` | La balance d'une charge, la barre d'onglets |
| Design system | [../docs/design-system.md](../docs/design-system.md) | Couleurs, typographie, logo, règles d'usage, à reprendre telles quelles |
| Consignes UX | canvas, `project/Consignes.dc.html` | Les règles que chaque écran respecte : navigation, chiffres, erreurs, ton, accessibilité |
| Audit UX | [../docs/audit-ux.md](../docs/audit-ux.md) | 33 constats par gravité. Les critiques sont corrigés ; les constats encore ouverts sont dans les questions ouvertes |
| Journal des décisions | [../docs/decisions.md](../docs/decisions.md) | Les décisions produit, avec ce qui a été rejeté, et la vérification des pratiques manipulatrices |

Le canvas se lit avec l'outil Artifact (`action: "read"`, `path: "project/…"`).

## Comment les pièces s'articulent

Le parcours se lit dans l'ordre des sections : accès, création du foyer, arrivée du ou de la partenaire, mise en place, puis la semaine type (première visite, lundi, reste de la semaine). Les états hors parcours principal viennent ensuite : foyer et compte, erreurs, notifications, intro, foyer de 3. Chaque section correspond à une ligne du canvas. Les règles qui pilotent chaque écran sont dans le backlog, section « Product rules the backend implements ». Les variantes d'erreur et les notifications sont déclenchées par le système : elles n'ont pas de lien entrant dans le prototype.

| Écran | Maquette | Section du parcours | Onglet | Rôle |
|---|---|---|---|---|
| A1 | `project/A1-Bienvenue.dc.html` | Accès au compte | — | Bienvenue |
| A2 | `project/A2-Inscription.dc.html` | Accès au compte | — | Inscription |
| A3 | `project/A3-Inscription-erreurs.dc.html` | Accès au compte | — | Inscription — erreurs |
| A4 | `project/A4-Connexion.dc.html` | Accès au compte | — | Connexion |
| A5 | `project/A5-Connexion-erreur.dc.html` | Accès au compte | — | Connexion — erreur |
| A6 | `project/A6-Mdp-oublie.dc.html` | Accès au compte | — | Mot de passe oublié |
| A7 | `project/A7-Mdp-envoye.dc.html` | Accès au compte | — | Lien envoyé |
| A8 | `project/A8-Mdp-nouveau.dc.html` | Accès au compte | — | Nouveau mot de passe |
| A9 | `project/A9-Mdp-lien-expire.dc.html` | Accès au compte | — | Lien expiré |
| A10 | `project/A10-Email-confirmer.dc.html` | Accès au compte | — | Confirmer son email |
| B1 | `project/B1-Foyer-creer.dc.html` | Virginie · créer le foyer et inviter | — | Créer le foyer |
| B2 | `project/B2-Foyer-creer-erreur.dc.html` | Virginie · créer le foyer et inviter | — | Créer le foyer — erreur |
| B3 | `project/B3-Inviter.dc.html` | Virginie · créer le foyer et inviter | — | Inviter |
| B4 | `project/B4-Inviter-erreurs.dc.html` | Virginie · créer le foyer et inviter | — | Inviter — erreurs |
| B5 | `project/B5-Invitation-envoyee.dc.html` | Virginie · créer le foyer et inviter | — | Invitation en attente |
| B13 | `project/B13-Invitation-declinee.dc.html` | Virginie · créer le foyer et inviter | — | Invitation déclinée |
| B15 | `project/B15-Invitation-annuler.dc.html` | Virginie · créer le foyer et inviter | — | Annuler l'invitation · confirmation |
| B6 | `project/B6-Email-invitation.dc.html` | Karim · rejoindre le foyer | — | Email d'invitation |
| B7 | `project/B7-Rejoindre.dc.html` | Karim · rejoindre le foyer | — | Rejoindre le foyer |
| B12 | `project/B12-Karim-attente.dc.html` | Karim · rejoindre le foyer | — | Karim · mise en place en cours |
| B10 | `project/B10-Karim-preferences.dc.html` | Karim · rejoindre le foyer | — | Karim · préférences |
| B11 | `project/B11-Karim-repartition.dc.html` | Karim · rejoindre le foyer | — | Karim · répartition |
| B9 | `project/B9-Accepter-invitation.dc.html` | Karim · rejoindre le foyer | — | Accepter (compte existant) |
| B8 | `project/B8-Invitation-invalide.dc.html` | Karim · rejoindre le foyer | — | Invitation invalide |
| B14 | `project/B14-Karim-propose.dc.html` | Karim · rejoindre le foyer | — | Karim propose la répartition |
| C1 | `project/C1-Catalogue.dc.html` | Mise en place | — | Choisir les tâches |
| C12 | `project/C12-Repartition-choix.dc.html` | Mise en place | — | Attendre Karim ou avancer |
| C4 | `project/C4-Repartition.dc.html` | Mise en place | — | Répartition · tout fermé |
| C4b | `project/C4b-Repartition-ouverte.dc.html` | Mise en place | — | Répartition · tout ouvert |
| C8 | `project/C8-Repartition-ecart.dc.html` | Mise en place | — | Répartition · écart reporté |
| C5 | `project/C5-Tache-perso.dc.html` | Mise en place | — | Tâche perso |
| C6 | `project/C6-Tache-perso-erreurs.dc.html` | Mise en place | — | Tâche perso — erreurs |
| M1 | `project/M1-Taches-modifier.dc.html` | Modifier la mise en place (depuis Foyer) | — | Tâches du foyer · modifier |
| C2 | `project/C2-Catalogue-retrait.dc.html` | Modifier la mise en place (depuis Foyer) | — | Retirer une tâche |
| C7 | `project/C7-Tache-perso-supprimer.dc.html` | Modifier la mise en place (depuis Foyer) | — | Supprimer une tâche perso |
| C3 | `project/C3-Preferences.dc.html` | Modifier la mise en place (depuis Foyer) | — | Mes préférences |
| C16 | `project/C16-Repartition-reglages.dc.html` | Modifier la mise en place (depuis Foyer) | Foyer | Réglages de la répartition |
| D1 | `project/D1-Accueil-premier-jour.dc.html` | Première visite | Accueil | Accueil — jour 1 |
| D14 | `project/D14-Accueil-attente-Karim.dc.html` | Première visite | Accueil | Accueil · en attente de Karim |
| D9 | `project/D9-Accueil-solo.dc.html` | Première visite | Accueil | Accueil — seul·e |
| D12 | `project/D12-Accueil-Karim.dc.html` | Première visite | Accueil | Accueil de Karim · jour 1 |
| D11 | `project/D11-Accueil-lundi.dc.html` | Le lundi : bilan, décisions, répartition | Accueil | Accueil · lundi, répartition proposée |
| C9 | `project/C9-Repartition-compensee.dc.html` | Le lundi : bilan, décisions, répartition | — | Répartition · semaine suivante, compensation |
| E1 | `project/E1-Bilan.dc.html` | Le lundi : bilan, décisions, répartition | Bilan | Bilan de la semaine |
| E14 | `project/E14-Bilan-equilibre.dc.html` | Le lundi : bilan, décisions, répartition | Bilan | Bilan · semaine équilibrée |
| E2 | `project/E2-Historique.dc.html` | Le lundi : bilan, décisions, répartition | — | 4 dernières semaines |
| E3 | `project/E3-Alerte-blocage.dc.html` | Le lundi : bilan, décisions, répartition | — | Alerte : semaine sans saisie |
| E11 | `project/E11-Absence-question.dc.html` | Le lundi : bilan, décisions, répartition | — | Était-il absent ? (question à Virginie) |
| E4 | `project/E4-Foyer-bloque.dc.html` | Le lundi : bilan, décisions, répartition | Accueil | Régression et blocage |
| E15 | `project/E15-Descente-vue-Karim.dc.html` | Le lundi : bilan, décisions, répartition | Accueil | Descente de niveau (Karim) |
| E8 | `project/E8-Niveau-atteint.dc.html` | Le lundi : bilan, décisions, répartition | — | Niveau atteint |
| E9 | `project/E9-Niveau-ultime.dc.html` | Le lundi : bilan, décisions, répartition | Accueil | Niveau ultime |
| E13 | `project/E13-Ultime-perdu.dc.html` | Le lundi : bilan, décisions, répartition | Accueil | Niveau ultime perdu |
| E7 | `project/E7-Semaine-neutre.dc.html` | Le lundi : bilan, décisions, répartition | Bilan | Semaine sans charge mentale |
| E10 | `project/E10-Bilan-pause.dc.html` | Le lundi : bilan, décisions, répartition | Bilan | Bilan · semaine en pause |
| D2 | `project/D2-Accueil.dc.html` | Le reste de la semaine | Accueil | Accueil |
| D3 | `project/D3-Taches.dc.html` | Le reste de la semaine | Tâches | Tâches |
| D4 | `project/D4-Taches-vide.dc.html` | Le reste de la semaine | Tâches | Tâches — vide |
| D5 | `project/D5-Tache-detail.dc.html` | Le reste de la semaine | — | Détail tâche |
| D6 | `project/D6-Enregistrer.dc.html` | Le reste de la semaine | — | Enregistrer |
| D10 | `project/D10-Enregistrer-date.dc.html` | Le reste de la semaine | — | Enregistrer · choisir le jour |
| D7 | `project/D7-Enregistrer-erreur.dc.html` | Le reste de la semaine | — | Enregistrer — erreur |
| D8 | `project/D8-Enregistre.dc.html` | Le reste de la semaine | Accueil | Enregistré |
| D15 | `project/D15-Reassignation-demande.dc.html` | Le reste de la semaine | Tâches | Tâche proposée (Karim) |
| D16 | `project/D16-Reassignation-refusee.dc.html` | Le reste de la semaine | Tâches | Réassignation refusée (Virginie) |
| D13 | `project/D13-Accueil-Karim-alerte.dc.html` | Le reste de la semaine | Accueil | Accueil de Karim · semaine sans saisie |
| E5 | `project/E5-Debloque.dc.html` | Le reste de la semaine | Accueil | Débloqué |
| E6 | `project/E6-Journal.dc.html` | Le reste de la semaine | Bilan | Mon journal |
| E12 | `project/E12-Saisie-modifier.dc.html` | Le reste de la semaine | — | Modifier une saisie |
| E16 | `project/E16-Saisie-supprimer.dc.html` | Le reste de la semaine | — | Supprimer une saisie · confirmation |
| F1 | `project/F1-Foyer.dc.html` | Foyer et compte | Foyer | Foyer |
| F2 | `project/F2-Quitter-foyer.dc.html` | Foyer et compte | — | Quitter le foyer |
| F3 | `project/F3-Supprimer-foyer.dc.html` | Foyer et compte | — | Supprimer le foyer |
| F4 | `project/F4-Compte.dc.html` | Foyer et compte | — | Compte |
| F5 | `project/F5-Supprimer-compte.dc.html` | Foyer et compte | — | Supprimer le compte |
| F6 | `project/F6-Pause.dc.html` | Foyer et compte | — | Déclarer une pause |
| F7 | `project/F7-Sans-foyer.dc.html` | Foyer et compte | — | Compte sans foyer |
| F8 | `project/F8-Pause-pour-un-membre.dc.html` | Foyer et compte | — | Déclarer un membre absent |
| F10 | `project/F10-Pause-en-cours.dc.html` | Foyer et compte | — | Pause en cours |
| F11 | `project/F11-Sans-foyer-Virginie.dc.html` | Foyer et compte | — | Sans foyer (Virginie) |
| G1 | `project/G1-Hors-ligne.dc.html` | Erreurs système | Tâches | Hors ligne |
| G2 | `project/G2-Introuvable.dc.html` | Erreurs système | — | Page introuvable |
| G3 | `project/G3-Acces-refuse.dc.html` | Erreurs système | — | Accès refusé |
| G4 | `project/G4-Erreur-serveur.dc.html` | Erreurs système | — | Erreur serveur |
| G5 | `project/G5-Session-expiree.dc.html` | Erreurs système | — | Session expirée |
| H1 | `project/H1-Autoriser-notifs.dc.html` | Notifications | — | Autoriser les notifications |
| H2 | `project/H2-Notifs-verrouille.dc.html` | Notifications | — | Notifications reçues |
| H3 | `project/H3-Email-bilan.dc.html` | Notifications | — | Email du dimanche |
| H4 | `project/H4-Notifs-refusees.dc.html` | Notifications | — | Notifications refusées |
| H5 | `project/H5-Notifs-question.dc.html` | Notifications | — | Notification · question d'absence |
| I1 | `project/I1-Regles-charges.dc.html` | Introduction et règles | — | Règles · deux charges |
| I2 | `project/I2-Regles-progresser.dc.html` | Introduction et règles | — | Règles · progresser |
| I3 | `project/I3-Regles-absence.dc.html` | Introduction et règles | — | Règles · absence et pauses |
| I4 | `project/I4-Regles-rappel.dc.html` | Introduction et règles | — | Comment on calcule ? (connecté) |
| P1 | `project/P1-Inviter-plusieurs.dc.html` | Foyer de 3 personnes et plus | — | Inviter plusieurs membres |
| P2 | `project/P2-Choisir-couleur.dc.html` | Foyer de 3 personnes et plus | — | Choisir sa couleur (Karine) |
| C14 | `project/C14-Repartition-3.dc.html` | Foyer de 3 personnes et plus | — | Répartition · foyer de 3 |
| P3 | `project/P3-Accueil-3.dc.html` | Foyer de 3 personnes et plus | Accueil | Accueil · foyer de 3 |
| P4 | `project/P4-Bilan-3.dc.html` | Foyer de 3 personnes et plus | Bilan | Bilan · foyer de 3 |
| P5 | `project/P5-Absence-question-3.dc.html` | Foyer de 3 personnes et plus | — | Question d'absence · 2 réponses sur 3 |
| P6 | `project/P6-Assigner-liste.dc.html` | Foyer de 3 personnes et plus | — | Assigner · foyer de 5 et plus |
| P7 | `project/P7-Karine-preferences.dc.html` | Foyer de 3 personnes et plus | — | Préférences de Karine |
| P8 | `project/P8-Karine-repartition.dc.html` | Foyer de 3 personnes et plus | — | Répartition · Karine |
| P9 | `project/P9-Notif-absence-3.dc.html` | Foyer de 3 personnes et plus | — | Notification · absence (foyer de 3) |

## Laissé à l'équipe qui construit

- La technologie. Le dépôt contient aujourd'hui un prototype web Rails : à elle de choisir entre une PWA dans ce dépôt et une app native.
- Les animations au-delà de ce que montrent les maquettes : E8 (niveau atteint) et les écrans d'intro I1 à I3. Elles respectent toujours « réduire les animations ».
- Le comportement natif propre à chaque plateforme : clavier, retour arrière, autorisations système.

## Questions ouvertes

- L'accessibilité au-delà de l'enregistrement d'une tâche (D6, D7, D10) est reportée. Quand est-ce qu'on la traite ? Contrôles faits main, cibles de moins de 44 px, rôles ARIA : voir les constats 16, 25 et 27 de [l'audit](../docs/audit-ux.md).
- Les titres d'E4 et E15 doivent-ils dire en toutes lettres « Le foyer redescend au niveau 2 et sa progression est bloquée » ([audit](../docs/audit-ux.md), constat 14) ?
- La barre « Temps passé » d'E1 et E14 garde-t-elle un repère à 50 %, alors que le temps ne compte pas (constat 21) ?
- Le foyer de 3 doit-il avoir ses propres variantes d'E10, E4 et E2 ? Et P6 doit-il lister 3 membres au lieu de 5 (constat 24) ?
- Côté Karim, que voit-on à la place du bouton « Remettre à zéro » de C9 (constat 17) ?
- Les chiffres et libellés qui divergent d'un écran à l'autre (nombre de tâches, noms de tâches, dates) sont relevés dans le constat 20. Lesquels font foi ?
- Les conditions d'utilisation et la politique de confidentialité mènent à une page 404 (constat 29). Qui les rédige ?
