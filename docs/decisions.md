# 50/50 — journal des décisions

## 2026-11-08 · Session glissante d'une semaine
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** c'est le standard des apps mobiles. La semaine repart à chaque ouverture de l'app : une personne active ne se reconnecte pas.
- **Garde-fous :** cookie `HttpOnly`, `Secure` et `SameSite` ; invalidé au changement de mot de passe ; effacé à la déconnexion.
- **Rejeté :** une semaine fixe depuis la connexion.

## 2026-11-08 · Limites d'envoi des emails de compte
- **Décidé par :** la porteuse du projet.
- **Règle :** 3 demandes par heure par adresse email, 9 par heure depuis une même connexion. S'applique à l'inscription, au mot de passe oublié et au renvoi de confirmation.

## 2026-11-08 · Anti-énumération à l'inscription : compromis accepté
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la confirmation ne bloque pas, donc une vraie inscription connecte la personne alors qu'un email déjà connu renvoie vers la connexion. La différence reste visible pour un observateur attentif ; on l'accepte pour garder une inscription sans attente.

## 2026-11-08 · Six membres au plus par foyer
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la palette compte six couleurs de membre, chacune unique dans le foyer.

## 2026-11-08 · Les comptes existants sont considérés comme confirmés
- **Décidé par :** la porteuse du projet (standard du marché).
- **Pourquoi :** la confirmation de l'email arrive après leur création ; on ne leur impose pas un bandeau a posteriori. Les nouveaux comptes confirment leur adresse.

## 2026-11-08 · La session reste ouverte une semaine
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** sur un téléphone, se reconnecter chaque jour décourage d'enregistrer. Une semaine couvre un cycle complet de bilan.
- **Rejeté :** 30 jours (G5), et une session limitée à la case « Garder la session ouverte ».
- **Repose sur :** A4, G5.

## 2026-11-08 · La confirmation de l'email ne bloque pas la création du foyer
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la mise en place ne doit pas s'arrêter sur un email à aller chercher.
- **Rejeté :** bloquer B1 tant que l'adresse n'est pas confirmée.
- **Repose sur :** A2, A10, B1.

## 2026-11-08 · Un seul foyer par compte
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** aucun écran ne permet de passer d'un foyer à l'autre, et les chiffres d'une personne se lisent dans un seul foyer.
- **Rejeté :** plusieurs foyers par compte en V1.
- **Repose sur :** B9 (une personne déjà dans un foyer doit le quitter avant d'en rejoindre un autre), F7.

## 2026-11-08 · Monogramme : l'initiale, deux lettres en cas de doublon
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** une lettre suffit tant qu'elle ne prête pas à confusion.
- **Rejeté :** initiale et dernière lettre par défaut (P2).
- **Repose sur :** F1, P1, P2.

## 2026-11-08 · Les décisions de la semaine tombent le lundi, après la clôture
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** le bilan du dimanche 20:00 reste provisoire. Un enregistrement tardif peut encore le changer.
- **Rejeté :** décider dès le dimanche soir.
- **Repose sur :** la clôture du lundi à 3:00 (`docs/backend-backlog.md` §2.1).

## 2026-11-08 · Une seule déclaration « Oui, absence » suffit
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la personne absente ou n'importe quel autre membre sait si l'absence a eu lieu. Exiger un accord ajoute de la charge mentale.
- **Rejeté :** deux réponses identiques, et l'accord de la personne qui avait répondu « Non » (l'ancien écran F9).
- **Repose sur :** la question est posée à tout le foyer jusqu'au mercredi 20:00 (E11, P5, P9).

## 2026-11-08 · La semaine d'arrivée d'un membre ne compte pas
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** une semaine incomplète fausserait la part de la personne qui arrive.
- **Rejeté :** compter cette semaine au prorata.
- **Repose sur :** D12.

## 2026-11-08 · Une seule barre par membre dans la répartition proposée
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la barre affiche la moyenne des deux charges, ce qui reste lisible. Le bilan vérifie toujours les deux charges séparément, et la carte « À retenir » d'E1 explique l'écart quand une seule des deux est dans la zone.
- **Rejeté :** deux barres dans la proposition.
- **Repose sur :** C4 à C14, E1.

## 2026-11-08 · La part prévue se calcule en occurrences par semaine
- **Décidé par :** la porteuse du projet, après l'audit.
- **Pourquoi :** une tâche quotidienne pèse 7 fois plus qu'une tâche hebdomadaire. Les pourcentages affichés doivent découler des assignations visibles.
- **Rejeté :** compter chaque tâche une fois, quelle que soit sa fréquence.
- **Repose sur :** les assignations de C4b, C8, C9, B11, B14, C14 et P8.

## 2026-11-08 · Assignation multiple, sans « Pour le foyer »
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** une tâche partagée compte en entier pour chaque membre. Une tâche sans personne assignée n'est portée par personne.
- **Rejeté :** une réserve de tâches « Pour le foyer ».
- **Repose sur :** C5, C14, P6, F2 (quand un membre part, ses tâches passent aux autres).

## 2026-11-08 · À partir de 3 membres, on assigne avec un panneau de liste
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** les pastilles côte à côte deviennent illisibles à trois.
- **Rejeté :** le défilement horizontal, et les pastilles jusqu'à 4 membres.
- **Repose sur :** C14, P6.

## 2026-11-08 · La répartition est proposée chaque lundi, puis reste fixe
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** une base stable sur la semaine rend le bilan juste. Les changements ponctuels passent par la réassignation d'une tâche (D15, D16), qui vaut pour la semaine en cours seulement.
- **Rejeté :** une répartition qui change au fil de la semaine.
- **Repose sur :** C9, D11.

## 2026-11-08 · Les réglages de la répartition se valident à tous
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** tous les membres peuvent modifier les réglages. Un changement ne s'applique qu'une fois validé par tout le foyer.
- **Rejeté :** des réglages réservés à la personne qui gère le foyer.
- **Repose sur :** C16. Une option permet de valider automatiquement toute répartition proposée.

## 2026-11-08 · Deux états de validation seulement
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** savoir qui a validé et quand n'apporte rien. L'écran affiche « Validée par tous les deux » ou « En attente de [prénom] ».
- **Rejeté :** un historique de validation par membre.
- **Repose sur :** C9, D11, F1, C16.

## 2026-11-08 · Seule la personne qui porte l'écart peut le remettre à zéro
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** l'écart reporté protège la personne qui a porté le surplus. Elle seule peut y renoncer, depuis la répartition de la semaine.
- **Rejeté :** une remise à zéro dans les réglages, ou validée par tous.
- **Repose sur :** C9.

## 2026-11-08 · Les parts s'écrivent en pourcentage, sans « points »
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** le pourcentage et la zone dessinée sur la barre suffisent.
- **Rejeté :** « x points au-dessus », y compris pour l'écart reporté.
- **Repose sur :** E1, C9.

## 2026-11-08 · Un message de réussite ne nomme personne ; un déséquilibre nomme qui porte le plus
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la réussite appartient au foyer. Le déséquilibre est un fait, qu'on ne doit pas adoucir.
- **Rejeté :** des messages de réussite centrés sur une personne.
- **Repose sur :** E8, E14, E1.

## 2026-11-08 · Formulations non genrées, sans point médian
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** l'app ne connaît pas le genre de ses membres.
- **Rejeté :** l'accord au masculin par défaut, et le point médian.
- **Repose sur :** les textes de tous les écrans et les Consignes UX.

## 2026-11-08 · Pas de mode hors ligne
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** promettre qu'un enregistrement partira plus tard, sans garantie, fausserait les parts.
- **Rejeté :** une file d'attente d'enregistrements sur le téléphone.
- **Repose sur :** G1, G4, G5.

## 2026-11-08 · Confirmation avant de supprimer une saisie ou d'annuler une invitation
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** ces deux actions ne peuvent pas être annulées.
- **Rejeté :** un bandeau « Annuler » pendant 10 secondes.
- **Repose sur :** E16, B15.

## 2026-11-08 · La demande d'autorisation des notifications arrive à la fin de l'intro
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** l'intro vient d'expliquer ce que l'app enverra. On peut la rouvrir depuis Mon compte.
- **Rejeté :** une carte sur l'accueil du premier jour.
- **Repose sur :** I3 → H1 → A2, et F4.

## 2026-11-08 · Vérification des pratiques manipulatrices
- **Décidé par :** la porteuse du projet, sur la base de l'audit UX.
- **Pourquoi :** aucun écran ne culpabilise un refus, ne précoche un choix ni ne fabrique d'urgence.
  - « Garder la session ouverte » (A4) et les notifications (H1) sont désactivés par défaut. Les notifications ne s'activent qu'après l'écran d'explication.
  - Refuser une invitation (B9) et quitter le foyer (F2) ont le même poids visuel que l'action inverse.
  - Le délai de la question d'absence (mercredi 20:00) découle de la règle de clôture : ce n'est pas un compte à rebours.
  - Les niveaux ne punissent pas l'absence de connexion : seules deux semaines sans aucune saisie font redescendre le foyer, et toute pause ou déclaration d'absence l'évite.
  - Il n'y a ni rappel quotidien ni relance pour enregistrer (H1).
- **Rejeté :** les séries de jours consécutifs, et les relances quotidiennes.
- **Repose sur :** `docs/audit-ux.md`, verdict anti-patterns.

## 2026-11-12 · Écran de connexion sans mention de la durée de session
- **Décidé par :** la porteuse du projet.
- **Pourquoi :** la session d'une semaine n'a pas besoin d'être annoncée. La case « Garder la session ouverte » (A4) est retirée, et la ligne qui la remplaçait aussi.
- **Repose sur :** A4.

## 2026-11-12 · Mot de passe trop court : rappeler le minimum
- **Décidé par :** la porteuse du projet.
- **Règle :** l'erreur dit « 8 caractères minimum. », comme l'aide sous le champ.
- **Rejeté :** « 3 caractères sur 6 » (maquette A3) et « Trop court : … ».

## 2026-11-12 · Écarts de maquette acceptés sur les écrans de compte
- **Décidé par :** la porteuse du projet.
- « Changer d'adresse » (A10) mène au changement d'email du compte, pas à l'inscription, qui créerait un deuxième compte.
- I3 reprend la règle d'absence : une seule déclaration suffit, de la personne absente ou d'un autre membre. Le lien vers « Comment on calcule ? » attend I4.

## 2026-11-12 · CGU, politique de confidentialité et bandeau cookies avant le lancement
- **Décidé par :** la porteuse du projet.
- **À faire :** les pages CGU et confidentialité, liées depuis l'inscription (A2), et un petit bandeau cookies.
- **Note :** l'app ne pose aujourd'hui que des cookies nécessaires (session, intro déjà vue), exemptés de consentement : le bandeau informe, il ne demande rien tant qu'aucun traceur de mesure n'est ajouté.

## 2026-11-12 · Moteur hebdomadaire : règles confirmées
- **Décidé par :** la porteuse du projet.
- **Zone sur la part exacte :** on compare la part non arrondie à la zone ; l'arrondi ne sert qu'à l'affichage. 39,5 % est hors de la zone 40–60. La part juste reste arrondie (33 % à trois).
- **Niveau ultime :** le ratio de 85 % se mesure à partir de la semaine où le foyer a atteint le niveau ultime pour la première fois, sur 52 semaines au plus, semaines neutres exclues.
- **Pause :** une pause neutralise toute semaine qu'elle touche, même d'un jour, quel que soit le moment où elle est déclarée.
- **Part juste :** calculée sur les membres actifs (non en pause).
- **Régression :** appliquée le mercredi 20:00, après la question d'absence, pas au bilan définitif.
- **Personne n'enregistre :** la semaine est « silencieuse ». Elle ne compte pas dans les séries vides individuelles ; trois semaines silencieuses mettent le foyer en sommeil.
- **Semaine d'arrivée :** neutre pour tout le foyer.
- **Rejeté :** arrondir les parts avant de vérifier la zone (cela avantage la personne qui en fait le moins).

## 2026-11-12 · D3 : pause déclarée après coup sur une semaine définitive
- **Décidé par :** la porteuse du projet.
- **Règle :** le bilan définitif stocké n'est jamais réécrit. Une correction liée à la pause s'affiche par-dessus (« Neutre · pause déclarée le … ») et la régression qu'avait causée la semaine est annulée (niveau et compteur restaurés, blocage levé). Fenêtre : celle des pauses rétroactives (14 jours, ou les semaines d'une question d'absence ou d'une régression jusqu'au bilan définitif suivant).
- **Repose sur :** E10, F8.

## 2026-11-12 · D5 : marge affichée au niveau ultime
- **Décidé par :** la porteuse du projet.
- **Règle :** « il vous reste N semaines » : N est le nombre de semaines déséquilibrées consécutives que le foyer peut encore avoir avant de passer à 85 % ou moins, obtenu en simulant les semaines à venir comme déséquilibrées dans la fenêtre (depuis la première obtention du niveau ultime, 52 semaines au plus).
- **Repose sur :** E9.

## 2026-11-12 · D6 : « Tout le foyer » est un libellé
- **Décidé par :** la porteuse du projet.
- **Règle :** affiché quand tous les membres sont assignés à une tâche. En base, une assignation par membre ; chacun porte la tâche en entier. Il n'y a pas de pot commun.
- **Repose sur :** P8.

## 2026-11-12 · D14 : tâches du foyer modifiables par tout le monde, répartition verrouillée
- **Décidé par :** la porteuse du projet.
- **Règle :** tout membre peut ajouter, modifier et supprimer une tâche du foyer (remplace « la personne qui l'a créée ou celle qui gère le foyer » pour C7). Supprimer une tâche détache ses enregistrements, qui restent à leur auteur.
- **En cours de semaine :** la répartition validée ne bouge pas. Une tâche ajoutée s'enregistre « hors répartition » et entre dans la proposition du lundi suivant ; une tâche retirée reste prévue jusqu'à dimanche. Le bilan ne compte que les enregistrements.
- **Repose sur :** M1, C2, C5, C7.

## 2026-11-12 · D15 : la personne invitée compte dans la répartition de départ
- **Décidé par :** la porteuse du projet.
- **Règle :** elle compte dans la part juste de la répartition de départ, marquée provisoire. Elle ne compte dans les bilans qu'une fois membre active du foyer.
- **Repose sur :** P1, C4.

## 2026-11-12 · D18 : proposition de répartition à partir des préférences en V1
- **Décidé par :** la porteuse du projet.
- **Règle :** algorithme simple et prévisible : tâche aimée à qui l'aime, détestée à quelqu'un d'autre, puis équilibrage des occurrences prévues vers la part juste. La proposition reste modifiable.
- **Repose sur :** C4, C12, B11.

## 2026-11-12 · Niveau ultime : un quota de semaines déséquilibrées
- **Décidé par :** la porteuse du projet, après simulation des cas limites.
- **Règle :** le foyer garde le niveau ultime tant qu'il a **7 semaines déséquilibrées au plus sur les 52 dernières semaines** de la fenêtre. Les semaines neutres, y compris celles rendues neutres par une pause déclarée après coup (D3), ne comptent pas. Au-delà, retour au niveau 4 ; le niveau ultime revient dès que le compte repasse à 7.
- **Fenêtre :** elle part de l'obtention du niveau ultime, 52 semaines au plus. Elle repart de zéro à chaque nouvelle obtention après une régression (deux semaines vides). Elle ne repart pas quand le niveau revient après un dépassement du quota, sinon le quota se contournerait.
- **Marge affichée (E9) :** « il vous reste N semaines », N = 7 − semaines déséquilibrées dans la fenêtre.
- **Pourquoi :** à exigence égale (45 sur 52 = 86,5 %), le quota n'a pas la fragilité du ratio au début : avec le ratio, une seule semaine déséquilibrée juste après l'obtention faisait perdre le niveau.
- **Rejeté :** le ratio de 85 % (avec ou sans grâce de 7 semaines).

## 2026-11-12 · Le niveau repart de zéro quand la composition du foyer change
- **Décidé par :** la porteuse du projet.
- **Règle :** l'arrivée ou le départ d'un membre remet le niveau à 0, le compteur de semaines équilibrées à 0 et la fenêtre du niveau ultime à vide. L'historique des bilans reste.
- **Pourquoi :** le niveau mesure l'équilibre entre ces personnes-là ; une nouvelle personne n'hérite pas du niveau gagné par d'autres.

## 2026-11-12 · D8 : mêmes faits et mêmes chiffres pour tous
- **Décidé par :** la porteuse du projet.
- **Règle :** chaque destinataire reçoit les mêmes faits et les mêmes chiffres ; seule la formulation s'adapte (« vous » ou le prénom). Un déséquilibre nomme qui porte le plus.
- **Repose sur :** H2.

## 2026-11-12 · D9 : l'email est le repli du push, un plafond tous canaux confondus
- **Décidé par :** la porteuse du projet.
- **Règle :** un réglage par type d'événement. L'événement part en push quand la personne a un appareil enregistré et les notifications autorisées, sinon par email. Plafond : un bilan et une alerte par semaine et par personne, tous canaux confondus.
- **Repose sur :** H1, H4.

## 2026-11-13 · Renvoi d'une invitation : la personne qui l'a envoyée
- **Décidé par :** la porteuse du projet.
- **Règle :** seule la personne qui a envoyé l'invitation peut la renvoyer, ainsi que l'équipe 50/50 depuis le back-office. L'annulation reste ouverte à tout membre du foyer.

## 2026-11-13 · D12 : 3 envois en tout
- **Décidé par :** la porteuse du projet.
- **Règle :** 3 emails au plus par invitation, le premier envoi compris (donc 2 renvois), espacés de 15 minutes au moins, comptés par email et par foyer.

## 2026-11-13 · Pas d'email quand une invitation est déclinée
- **Décidé par :** la porteuse du projet.
- **Règle :** la personne qui gère le foyer le voit dans l'app (B13) ; aucun email.

## 2026-11-13 · Back-office ActiveAdmin 4
- **Décidé par :** la porteuse du projet.
- **Outil :** ActiveAdmin 4 (Tailwind, importmap ; la 3 demande Sprockets et Sass, retirés). Le Tailwind de l'espace reprend la DA 50/50 (tokens partagés avec l'app).
- **Accès :** modèle `AdminUser` séparé des comptes de l'app, double authentification obligatoire, pas d'inscription libre.
- **Ce que voit l'équipe :** comptes, foyers, invitations, et des agrégats par foyer. Jamais le détail des enregistrements ni les préférences : ils appartiennent à leur auteur.
- **Actions :** renvoyer ou annuler une invitation, débloquer un foyer, confirmer un email ; supprimer un compte arrive avec le lot 7. Chaque action est journalisée.
- **Réalisé (lot 9) :** `AdminUser` + TOTP (enrôlement à la première connexion, 5 essais puis blocage 30 min, session de 30 min, pas de mot de passe oublié : `bin/rails admin:bootstrap` recrée le mot de passe, `admin:reset_two_factor` refait l'enrôlement). Le journal est la table `admin_actions`, en lecture seule dans l'admin, sans nom ni email dans le détail.
- **Débloquer un foyer :** `Household#admin_unblock!(by:)` remet l'état (`active`, ou `solo` sous deux membres) et vide `blocked_at`. Niveau et compteur ne bougent pas. Il écrit l'EngineEvent `household.admin_unblocked` ; aucune notification n'en part (l'alerte E5 est liée à un bilan de semaine). À trancher : les membres doivent-ils être prévenus ?
- **Supprimer un compte :** `AccountDeletion#save_as_admin(typed_email:)`, sans mot de passe mais avec l'email tapé ; mêmes étapes et même sort des enregistrements (supprimés) que pour la personne. Le chemin de la personne (`save`) n'a pas changé.
- **Dernière activité d'un foyer :** la date du dernier enregistrement du foyer, rien de plus (un agrégat, jamais une ligne).

## 2026-11-13 · Prénom de la personne invitée
- **Décidé par :** la porteuse du projet.
- **Règle :** l'écran d'invitation (B3) demande le prénom. Il s'affiche partout où la personne invitée apparaît avant d'avoir rejoint le foyer, et pré-remplit son inscription (modifiable).

## 2026-11-13 · Catalogue et tâche perso
- **Décidé par :** la porteuse du projet.
- **Règle :** on garde le catalogue existant (49 tâches, 7 catégories), plus proche du réel que les chiffres de la maquette C1. Le formulaire de tâche perso reste tel que construit : catégorie « Personnalisées », champ « fois par période » en plus.

## 2026-11-13 · Pas de bilan pour un foyer d'une personne ; semaine vide : email de retour
- **Décidé par :** la porteuse du projet.
- **Règle :** un foyer de moins de deux membres ne reçoit pas de bilan hebdomadaire. Une semaine où personne n'a rien enregistré, dans un foyer de deux membres ou plus, remplace le bilan par un court email qui invite à revenir sur l'app : le fait, une ligne sur ce que fait l'app, un seul bouton. Il prend la place du bilan dans le plafond hebdomadaire et suit le réglage « Bilan de la semaine ».
- **Note :** l'entrée du 2026-11-08 sur les pratiques manipulatrices excluait toute relance pour enregistrer. Cet email reste hebdomadaire, factuel, sans culpabilisation ni urgence ; il remplace un bilan qui n'aurait rien dit, il ne s'ajoute pas.

## 2026-11-13 · Suppression du compte : le journal est supprimé, les bilans passés restent sans le prénom
- **Décidé par :** la porteuse du projet.
- **Règle :** à la suppression d'un compte (F5), les enregistrements de la personne sont supprimés : ils lui appartiennent et elle part. Les bilans passés du foyer gardent leurs chiffres ; le prénom y devient « Ancien membre ». La personne quitte d'abord son foyer (F2) : ses tâches passent aux autres membres et la personne la plus ancienne devient gestionnaire.
- **Réversible :** `AccountDeletion#dispose_of_logs!` est le seul endroit qui l'applique (`LOGS_ON_DELETION`, `:keep_anonymised` pour garder les enregistrements sur le compte anonymisé).
- **Écart :** la maquette F5 et le backlog 3.6 refusaient la suppression tant que la personne gère un foyer partagé ; on la fait quitter le foyer à la place.

## 2026-11-13 · Recalcul des parts en direct
- **Décidé par :** la porteuse du projet.
- **Règle :** dans les écrans de répartition (C9, C12, B11), les pourcentages se mettent à jour dès qu'une assignation change, sans enregistrer. Seul « Valider » enregistre.

## 2026-11-13 · Écart reporté : lectures retenues au lot 6 (à confirmer)
- **Formule :** écart d'une semaine close = moyenne des parts exactes (mentale, exécution) − part juste. Le solde s'additionne jusqu'à compensation réelle ou remise à zéro. La cible du lundi = part juste − solde, ramenée dans la zone ; le reste reste reporté.
- **Exclues :** semaines neutres, semaines avant le premier plan, report désactivé, semaine validée « sans reporter l'écart ».
- **« Valider sans reporter l'écart » :** proposé seulement à la personne au-dessus de la zone (D4).
- **Remise à zéro à trois ou plus :** la personne qui la fait renonce à son seul surplus, rendu aux autres au prorata de ce qui leur est dû.
- **Arrivée ou départ :** l'écart n'est pas remis à zéro ; la personne qui arrive part de 0.

## 2026-11-13 · Lot 7 et écart : confirmations
- **Décidé par :** la porteuse du projet.
- **Écart reporté :** il reste jusqu'à ce que de vraies semaines le compensent (ou une remise à zéro) ; il ne s'efface pas tout seul.
- **Gestionnaire qui supprime son compte :** elle ou il quitte d'abord le foyer, la gestion passe à la personne la plus ancienne (au lieu du refus de F5).
- **Dernier membre qui part :** le foyer est supprimé.
- **Départ :** les enregistrements sont détachés du foyer et des tâches ; ils restent à leur auteur.
- **« Votre foyer a été supprimé » :** message transactionnel, envoyé quels que soient les réglages, sans lien de désinscription.

## 2026-11-13 · Lot 6 et lot 4 : confirmations
- **Décidé par :** la porteuse du projet.
- **Écart (lot 6) :** « Valider sans reporter l'écart » réservé à la personne au-dessus de la zone ; à trois ou plus, la remise à zéro ne porte que sur son propre surplus ; l'écart n'est pas remis à zéro à l'arrivée ou au départ d'un membre.
- **« Fait » (lot 4) :** enregistre en un geste avec les valeurs par défaut de la tâche ; le formulaire complet reste accessible.
- **Tâche non faite (révisé le même jour) :** « En retard » se limite à la semaine en cours. Une tâche quotidienne ou hebdomadaire non faite disparaît à la fin de la semaine ; une tâche mensuelle, annuelle ou ponctuelle reste en retard jusqu'à ce qu'elle soit faite. L'enregistrement compte dans la semaine où la tâche est faite.
- **Pas de lignes de série** (« Saisie 5 semaines sur 5 », « comme les 2 précédentes ») : cohérent avec la vérification des pratiques manipulatrices.

## 2026-11-12 · Lot 10 A : foyer de 3 et plus, règles, accessibilité, pages légales (écarts de maquette tranchés par les décisions)
- **I4 (« Comment on calcule ? »)** lit tous ses chiffres dans `HouseholdRules` (zone et part juste de 2 à 6 membres, seuils de niveaux, quota 7 sur 52, 2 semaines sans saisie, mercredi 20:00, pauses de 14 jours, bilan provisoire dimanche 20:00 et définitif lundi 3:00). Écarts avec la maquette : « 85 % de semaines équilibrées » devient le quota de 7 semaines déséquilibrées sur 52 ; « 40 et 60 % » devient un tableau par taille de foyer. L'écran est public (l'intro y mène avant l'inscription).
- **I3 (D7, texte proposé, à confirmer) :** « Une semaine non équilibrée ne fait pas reculer : le foyer ne monte pas, c'est tout. Seule exception, le niveau ultime : au-delà de 7 semaines déséquilibrées sur 52, retour au niveau 4. » Même texte que la note de I2.
- **Une barre par membre à partir de 3** (accueil, bilan, répartition), avec la zone en pointillés et le repère de la part juste ; à 2, la barre partagée reste. Un membre en pause sort des barres (part juste sur les membres actifs).
- **P6 :** feuille à cases à cocher dès 3 personnes (invitations comprises), un bouton par tâche qui nomme les personnes assignées ; les pastilles restent à 2.
- **P2 :** la personne invitée dans un foyer qui a déjà 2 membres choisit couleur et lettres avant de rejoindre (étape 1 sur 3) ; le choix est gardé sur l'invitation (`invitations.color`, `monogram`) et donné au membre à l'arrivée si la couleur est encore libre, sinon la première libre. Chaque membre rouvre sa pastille depuis Foyer.
- **P1 :** l'étape « Partenaire » liste les membres et invitations, rappelle la part égale et la zone pour la taille attendue, et propose « Inviter une autre personne » jusqu'à 6 personnes, invitations comprises.
- **Cookies :** le bandeau informe et un « OK » mémorise la lecture (cookie nécessaire `cookie_notice_seen`, 12 mois). Pas de choix tant qu'aucun traceur n'existe. Masqué dans les coquilles natives.
- **Pages légales :** `/cgu` et `/confidentialite`, brouillons « à valider juridiquement », éditeur, adresse, immatriculation et hébergeur en espaces à compléter. **À traiter avant publication :** les polices se chargent depuis Google Fonts (adresse IP transmise à Google) ; les héberger supprime le transfert et garde la promesse « aucun traceur » sans réserve.
- **Contraste :** le badge « Ult. » (blanc sur terracotta, 4,35:1) passe en encre sur blanc ; le terracotta ne marque que la part de la personne qui regarde. L'app n'a qu'un thème clair ; les deux fonds vérifiés sont le fond clair et le fond encre (intro, alertes, bandeau).

## 2026-11-13 · Back-office : durcissement après revue de sécurité
- **Enrôlement :** le secret TOTP n'est montré qu'à une session arrivée par un lien à usage unique (30 min, lié au compte, remis hors bande par `admin:bootstrap` / `admin:reset_two_factor`) et connectée par mot de passe. Un secret neuf par lien ; réinitialiser met fin à toutes les sessions du compte.
- **Emails :** deux actions distinctes (adresse actuelle, changement en attente), chacune nomme l'adresse visée. Le journal garde des empreintes à clé (HMAC), pas les adresses.
- **Tri :** liste blanche par ressource ; tout le reste retombe sur l'ordre par défaut.
- **Dernière activité d'un foyer :** semaine ISO, seulement pour deux membres ou plus, non triable.
- **Journal :** connexions, refus, blocages et commandes console y figurent ; il est en ajout seul dans Postgres (trigger), donc `db/structure.sql`. Un compte admin se désactive, il ne se supprime pas. Session : 30 min d'inactivité, 8 h au total.

## 2026-11-13 · Revue de sécurité complète : correctifs appliqués
- **Périmètre :** quatre revues (comptes et accès, données du foyer, moteur/notifications/vie privée, back-office), 27 constats, aucun critique ; tous corrigés avec un test de non-régression.
- **Choix faits en corrigeant (à confirmer si besoin) :**
  - Connexion limitée à 30 essais par connexion et 10 par adresse sur 15 minutes ; au-delà, l'écran « mot de passe incorrect » habituel, pour ne rien révéler.
  - Mot de passe : 8 caractères minimum pour un nouveau mot de passe (les anciens restent valables).
  - Polices Unbounded et Figtree servies par l'app (plus d'appel à Google Fonts).
  - Politique de sécurité du contenu (CSP) active ; les attributs `style` en ligne restent autorisés (largeurs des barres).
  - Chaque visite pose le cookie de session (nécessaire, exempté de consentement).
  - Schéma de base enregistré en `db/structure.sql` (triggers du journal admin).
- **À faire au déploiement :** `APP_HOST` (et `APP_EXTRA_HOSTS`) dans l'environnement de production, base `cache` créée, clés de chiffrement Active Record (`bin/rails db:encryption:init`).

## 2026-11-13 · Retours sur la revue de sécurité, pause, déblocage, applications natives
- **Connexion (remplace les seuils choisis par l'agent) :** 4 mauvais mots de passe en 2 h bloquent le compte 2 h. Au 3e blocage (12 essais), le compte reste bloqué jusqu'à ce qu'un admin le débloque depuis le back-office (action journalisée). Un succès remet les compteurs à zéro. La limite par connexion (IP) reste.
- **Changement d'email :** 2 par compte sur 24 h glissantes.
- **Jetons d'invitation :** stockés en empreinte HMAC-SHA256, jamais en clair. Un renvoi émet un nouveau lien ; l'ancien ne marche plus.
- **Foyer supprimé :** pas d'email ; la notification reste dans l'app.
- **Email après départ :** acceptable ; le correctif déjà en place reste.
- **File des jobs :** Solid Queue, pas Sidekiq (pas de Redis à opérer ; le volume le permet).
- **Pause :** elle neutralise des semaines entières. Elle ne peut pas commencer ni s'étendre sur une semaine où la personne a déjà enregistré une tâche.
- **Déblocage par l'équipe (back-office) :** seul le membre concerné par le blocage est prévenu, pas le reste du foyer.
- **Back-office :** rôle superadmin, qui a tous les droits (y compris gérer les admins et voir les données individuelles) ; chaque consultation de données individuelles est journalisée. « Dernière activité » gardée. Pas de QR code à l'activation de la double authentification.
- **Applications iOS et Android (lots 8b, 9) :** écrites par les agents sans pouvoir les compiler ; la compilation et les essais sur appareil restent à faire.

## 2026-11-13 · Pause sans semaine saisie, foyer supprimé sans email
- **Pause :** elle ne peut ni commencer ni s'étendre sur une semaine locale (fuseau du foyer) où la personne a déjà enregistré une tâche, semaine en cours comprise. Fin de la pause d'un dimanche qui neutralise une semaine faible. Le message pointe le lundi suivant (« Vous avez déjà enregistré une tâche cette semaine : la pause peut commencer lundi 16 novembre. », avec le prénom pour une pause déclarée pour quelqu'un d'autre). Une saisie faite après la déclaration, dans une semaine déjà couverte, ne l'annule pas.
- **« Oui » à la question d'absence :** la pause ne couvre que les semaines sans saisie (une saisie antidatée est possible) ; si les deux semaines ont des saisies, la réponse est refusée.
- **Foyer supprimé :** notification dans l'app seulement, jamais d'email. Sans foyer, la personne la lit sur son écran d'arrivée (une fois, puis elle est marquée lue).

## 2026-11-13 · Choix confirmés : blocage de connexion, équipe, notifications
- **Blocage de connexion :** les sessions déjà ouvertes restent ouvertes pendant un blocage. Réinitialiser son mot de passe ne lève pas un blocage.
- **Équipe (back-office) :** un admin créé depuis « Équipe » reçoit un mot de passe généré, montré une seule fois. Pas encore d'écran pour le changer.
- **Notification de déblocage (`alert_block_lifted`) :** elle compte dans la limite d'une alerte par semaine. Si la personne a déjà reçu une alerte cette semaine, elle est dans l'app seulement, sans email.
- **Foyer supprimé :** l'avis s'affiche une fois sur l'écran sans foyer, puis il est marqué lu.
- **Rails :** passage en 8.1 (8.0 n'a plus de correctifs de sécurité depuis le 7 novembre 2026).
