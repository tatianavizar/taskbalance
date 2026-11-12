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
- **Règle :** l'erreur dit « 6 caractères minimum. », comme l'aide sous le champ.
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
