# Audit UX des maquettes mobiles 50/50 (canvas « 50/50 — Maquettes », 100 écrans)

**Verdict anti-patterns : Mineur.** Aucun pattern trompeur : pas de confirmshaming, pas de case précochée intéressée, pas d'urgence fabriquée, pas de relance culpabilisante. Deux écarts à la règle de ton : des modèles de messages accordés au masculin alors que l'app ne connaît pas le genre (constat 15), et un écran de réussite qui nomme des membres (constat 19).

Comptes : 2 critiques, 14 majeurs, 15 mineurs, 2 cosmétiques.

---

## Critique

### 1. Les parts « Prévu cette semaine » ne découlent pas des assignations et cachent une charge mentale hors zone

- **Écrans :** C4, C4b, B11, B14, C8, C9, C14
- **Preuve :**
  - C4 affiche « 50 % Virginie · Karim 50 % ».
  - Dans la même liste, Virginie a « Préparer les sacs d'école · Mentale et exécution · 10 min · chaque jour », « Faire les courses · Mentale et exécution » et « Prendre RDV pédiatre · Mentale ».
  - Karim a « Planifier les repas » et « Faire la liste de courses » (chaque semaine), « Payer les factures » (chaque mois) et « Renouveler l'assurance habitation » (chaque année).
  - Avec la métrique du backlog (§2.2c, une tâche quotidienne compte 7 fois) :
    - charge mentale prévue : 8 à 9 occurrences pour Virginie contre 2 à 4 pour Karim, soit 67 à 82 % pour Virginie ;
    - exécution : 20 contre 18, soit 53 % ;
    - la moyenne dépasse 60 %.
  - C9 garde exactement les assignations de C4. Il affiche pourtant « 48 % » et « Karim prend 2 points de plus », alors qu'aucune tâche n'a changé de main.
  - C8 ajoute Karim sur « Lancer une lessive ». C'est une tâche partagée, qui compte en entier pour les deux. La part de Virginie passe pourtant de 50 % à 53 %.
  - C14 affiche « Karine 33 % » alors que Karine porte « Préparer les sacs d'école » (7 fois) et « Faire les courses », soit environ 70 % de la charge mentale prévue.
  - La métrique du backlog est marquée *(default)*. Les incohérences entre C4, C8 et C9 tiennent quelle que soit la métrique.
- **Impact :** le foyer valide un plan que le bilan déclarera non équilibré, puisqu'il vérifie chaque charge séparément. La charge mentale invisible, ce que le produit existe pour montrer, est masquée au moment où le foyer décide. Les chiffres de référence remis au développement sont faux.
- **Changement :**
  - Recalculer chaque part proposée à partir des assignations affichées.
  - Garder la barre unique, qui est une décision tranchée.
  - Quand une charge sortirait de la zone, ajouter une ligne sous la barre : « Charge mentale prévue : Virginie 75 %, hors zone. Le bilan la vérifie à part. »
- **Heuristique :** prévention des erreurs.

### 2. Enregistrer une tâche est impossible au clavier et au lecteur d'écran

- **Écrans :** D6, D7, D10
- **Preuve :**
  - D6, champ Tâche : `<label class="lbl">Tâche</label><div class="in">…<b>Payer les factures</b></div>`. Il n'y a aucun champ et le label ne vise rien.
  - Les suggestions sont des `<span class="chip">`.
  - Durée : `<span class="sb" aria-label="Moins 5 minutes">−</span>`, sans rôle ni `tabindex`.
  - « Quand » : un `role="radiogroup"` qui contient des `<span>` sans `role="radio"` ni `aria-checked`.
  - D10 : un `role="grid"` dont les jours sont des `<span class="d ok">` non focalisables.
- **Impact :**
  - La tâche principale de l'app ne peut pas être choisie sans pointeur.
  - La personne qui ne peut pas enregistrer apparaît à 0 %.
  - Elle déclenche ensuite l'alerte (E3), puis la descente de niveau du foyer (E4).
- **Changement :**
  - Tâche : un champ de saisie avec liste de suggestions (combobox).
  - Durée : de vrais boutons pour − et +.
  - Quand : des boutons radio natifs pour Aujourd'hui, Hier et Autre jour.
  - D10 : un bouton par jour dans chaque cellule, avec `aria-disabled` sur les jours futurs.
- **Fait quand :** « Payer les factures, 25 min, hier » s'enregistre au clavier seul, puis avec VoiceOver, et chaque contrôle annonce son nom, son rôle et son état.
- **Heuristique :** cohérence et standards.

---

## Majeur

### 3. Après « Valider la répartition », l'accueil affiche « Répartition à faire »

- **Écrans :** C4, C4b, C8, C14 → D1
- **Preuve :** le bouton « Valider la répartition » mène à `D1-Accueil-premier-jour.dc.html`. D1 affiche « Répartition à faire » avec un lien « Faire », et « Mise en place 2 sur 4 ».
- **Impact :** Virginie croit que la validation a échoué. Elle refait la répartition ou doute de l'app dès le premier jour.
- **Changement :** une variante de D1 qui coche « Répartition validée » et affiche « Mise en place 3 sur 4 ».
- **Heuristique :** visibilité de l'état du système.

### 4. Aucun écran ne montre qui a validé la répartition, ni un réglage en attente

- **Écrans :** C9, D11, C16
- **Preuve :**
  - D11 : « À valider · Virginie 48 %, Karim 52 % ».
  - C9 : « Valider la répartition » mène à D2, sans retour visible.
  - C16 : « Un changement s'applique une fois validé par tous les membres du foyer ». Pourtant, les interrupteurs n'ont que deux états, actif et inactif.
- **Impact :**
  - Après avoir validé, Virginie ne sait pas si la répartition est en vigueur ou attend Karim.
  - Un réglage changé paraît appliqué alors qu'il ne l'est pas.
  - Rien ne dit ce qui se passe si Karim modifie la répartition après la validation de Virginie.
- **Changement :**
  - Sur C9 et D11, trois états :
    - « Validée par vous · en attente de Karim » ;
    - « Validée par tous · fixe jusqu'au lundi 26 oct » ;
    - « Karim a modifié la répartition après votre validation : à revoir ».
  - Sur C16, sous un interrupteur changé : « En attente : Karim n'a pas encore validé ce changement ».
  - Côté Karim, deux boutons : Valider et Refuser.
- **Heuristique :** visibilité de l'état du système.

### 5. Le bilan dans l'app ne dit pas s'il est provisoire ou définitif

- **Écrans :** E1 (aussi D2, D8, P4)
- **Preuve :**
  - H3 (email) écrit « Bilan provisoire. ».
  - E1 titre « Non équilibrée », sans statut.
  - I4 : « La semaine se clôt lundi 3:00 ; le bilan du dimanche soir est provisoire. »
- **Impact :**
  - Dimanche soir, le verdict se lit comme définitif, alors qu'un enregistrement tardif peut le changer.
  - Les décisions (alerte, question d'absence, niveau) ne tombent que lundi.
- **Changement :**
  - Sous le sélecteur de semaine, afficher « Provisoire · définitif lundi 9 nov à 3:00 », puis « Définitif · clos lundi 9 nov à 3:00 ».
  - Jusqu'à la clôture, titrer « Non équilibrée pour l'instant ».
- **Heuristique :** visibilité de l'état du système.

### 6. Une semaine sans charge mentale est appelée « non équilibrée » au lieu de « neutre »

- **Écrans :** E7, E9
- **Preuve :**
  - E7 : « La semaine n'est pas équilibrée : l'exécution est à 67 % pour Virginie, et sans charge mentale enregistrée elle ne peut pas l'être. » puis « Une semaine non équilibrée ne fait pas reculer ».
  - Le backlog (§1) dit : « Neutral week: no mental-load log or no execution log… neither balanced nor unbalanced ».
  - E10 emploie bien « Semaine neutre ».
  - E9 liste « En pause, non comptées 2 » et « Non équilibrées 7 », sans ligne pour les semaines neutres.
- **Impact :**
  - Au niveau ultime, les semaines neutres sont exclues du ratio, alors que les non équilibrées comptent contre les 85 %.
  - Le foyer croit avoir perdu de la marge.
  - Un développeur qui suit E7 compte la semaine contre le foyer.
- **Changement :**
  - E7, titre : « Semaine neutre : aucune charge mentale enregistrée ».
  - E7, texte : « Elle ne compte ni pour ni contre le foyer. »
  - E9 : ajouter la ligne « Neutres, non comptées ».
- **Heuristique :** cohérence et standards.

### 7. Quitter le foyer renvoie les tâches « au foyer », que la décision a supprimé

- **Écran :** F2
- **Preuve :**
  - F2 : « Vos 5 tâches assignées passent au foyer : n'importe quel membre peut les prendre. »
  - La décision supprime « Pour le foyer » : chaque tâche a au moins une personne assignée.
  - Le backlog §3.3 dit encore « become unassigned », ce qui contredit son propre §1.
- **Impact :** Karim croit ces 5 tâches libres, et dans la répartition suivante personne ne les porte.
- **Changement :** nommer la personne à qui les tâches passent (à deux, Karim), puis aligner le backlog §3.3 sur cette règle.
- **Heuristique :** cohérence et standards.

### 8. Deux règles affichées pour savoir qui propose la répartition quand Virginie attend Karim

- **Écrans :** C12, D14 contre B9, B14
- **Preuve :**
  - Version Virginie :
    - C12 : « Attendre Karim… La répartition vous est proposée dès qu'il a donné ses préférences » ;
    - D14 : « La répartition vous sera proposée dès qu'il aura rejoint et donné ses préférences ».
  - Version Karim :
    - B9 : « Si elle a choisi de vous attendre, c'est vous qui la proposez » ;
    - B14 : « Virginie a choisi de vous attendre. Assignez chaque tâche ; Virginie reçoit votre proposition et peut la modifier. »
- **Impact :** Virginie attend une proposition calculée, tandis que Karim est censé la construire. Chacun·e attend l'autre.
- **Changement :** aligner C12 et D14 sur B14 : « Karim proposera la répartition en rejoignant ; vous pourrez la modifier. »
- **Heuristique :** cohérence et standards.

### 9. Trois écrans promettent une file d'attente hors ligne que le backlog ne prévoit pas en V1

- **Écrans :** G1, G4, G5
- **Preuve :**
  - G1 : « 1 enregistrement attend le réseau ; il partira tout seul. »
  - G4 : « votre enregistrement est gardé sur ce téléphone ».
  - G5 : « Ce que vous étiez en train d'enregistrer est conservé ».
  - Le backlog range « Offline log queue in the service worker (G1) » dans *Later*.
- **Impact :** si la V1 sort ces écrans sans la file d'attente, des enregistrements se perdent après avoir été promis sauvés. C'est l'erreur qui fausse le plus directement la part d'un membre.
- **Changement :**
  - Soit la file d'attente passe en V1.
  - Soit, en V1, le bandeau G1 devient « Hors ligne. Rien n'est envoyé : réessayez une fois connecté·e. ». Le formulaire reste rempli, et G4 et G5 retirent la promesse.
- **Heuristique :** cohérence et standards.

### 10. Le terracotta et le vert ne disent plus la même chose d'un écran à l'autre

- **Écrans :** E2, H3, B11, B14, E5, E9, E13
- **Preuve :**
  - E2 :
    - la colonne de la semaine équilibrée est en `background-color: #B9F2D4` (menthe) ;
    - la légende dit « En menthe, les semaines équilibrées ; en terracotta, les non équilibrées ».
    - Or la décision veut du vert foncé #1d5c3f pour les semaines équilibrées, et le terracotta pour la part de la personne qui regarde.
  - H3 : la tuile S42 est en `background:#b9f2d4`.
  - B11 et B14 sont des écrans de Karim, mais le segment terracotta (`width:50%;…background:#c8553d`) est celui de Virginie.
  - E5 :
    - la semaine est équilibrée (54 % et 52 %), mais les deux balances sont importées sans `ok="true"`, donc en terracotta ;
    - le nouveau segment de la progression est `#c8553d`.
  - E9 et E13 : la barre du ratio du foyer est en terracotta.
  - La menthe sur une carte blanche donne 1,26:1, sous le minimum de 3:1 pour un élément graphique porteur de sens.
- **Impact :**
  - Le terracotta ne signifie plus « ma part ».
  - Sur B11, Karim lit la part de Virginie comme la sienne.
  - Dans E2 et H3, la semaine équilibrée est la marque la moins visible.
- **Changement :**
  - Semaines équilibrées en #1d5c3f partout : colonne et légende d'E2, tuile de H3, balances d'E5 avec `ok="true"`.
  - Terracotta seulement sur le segment de la personne qui regarde (sur B11 et B14, celui de Karim).
  - Barres de ratio du foyer (E9, E13) en encre #0f1a14.
- **Fait quand :** sur les 100 écrans, chaque terracotta marque la part de la personne qui regarde, et chaque semaine équilibrée est en #1d5c3f.
- **Heuristique :** cohérence et standards.

### 11. Des liens mènent au mauvais écran sur trois parcours clés

- **Écrans :** C5, D5, M1, B7, P2, F2, F3
- **Preuve :**
  - **Ajouter une tâche** :
    - le retour de C5 et « Ajouter la tâche » mènent toujours à C1 (`href="C1-Catalogue.dc.html"`), quelle que soit l'origine : B11, B14, C4, C9, C14, D3, D4 ou M1 ;
    - venu de B11, Karim atterrit donc dans la mise en place de Virginie ;
    - le lien « Modifier » de D5 ouvre C5, titré « Ajouter une tâche ».
  - **Catégories de M1** : « Courses 3 sur 4 › » mène à C1 :
    - son retour va à B5 ;
    - son bouton Continuer va à C12, qui affiche « Karim n'a pas encore rejoint ».
  - **Accepter avec un compte existant** :
    - B7, « J'ai déjà un compte : me connecter pour accepter », mène à A4 ;
    - le bouton « Se connecter » d'A4 mène à D2, l'accueil de Virginie ;
    - B9 n'est jamais atteint.
  - **Karine** : P2 (« Étape 1 sur 3 ») mène à C14 :
    - C14 est la répartition de Virginie (« Votre part en terracotta » sur Virginie) ;
    - les étapes 2 et 3 de Karine n'existent pas ;
    - le retour de C14 mène à P2.
  - **Quitter ou supprimer** : sur F2 et F3, des écrans de Virginie, « Quitter le foyer » et « Supprimer définitivement » mènent à F7, l'écran de Karim (avatar « K », « Invitation de Virginie · en attente »).
- **Impact :**
  - L'ajout d'une tâche après la mise en place fait rentrer dans l'onboarding.
  - Le partenaire déjà inscrit ne voit jamais l'écran de consentement.
  - Karine ne donne jamais ses préférences.
- **Changement :**
  - C5 revient à l'écran d'origine. Le « Modifier » de D5 ouvre une variante titrée « Modifier la tâche ».
  - Les catégories de M1 se déplient sur place, comme Cuisine.
  - Après un lien d'invitation, A4 mène à B9.
  - P2 enchaîne sur les préférences de Karine (variante de B10), puis sur la répartition (variante de B11).
  - F2 et F3 mènent à une variante de F7 pour Virginie.
- **Heuristique :** contrôle et liberté de l'utilisateur.

### 12. Des écrans clés n'ont aucun lien entrant

- **Écrans :** D11, B14, B13, P1, P3, P4, P5, D13, E5, E7, E8, E9, E13, E15
- **Preuve :**
  - Aucun `href` ne vise D11, B14, B13, P1, P5, D13, E5, E7, E8, E9, E13 ou E15.
  - P4 et P1 ne sont visés que par eux-mêmes, et P3 seulement par P5, qui n'a pas de lien entrant.
  - La barre d'onglets mène toujours à D2, E1 et F1.
  - Le « Inviter quelqu'un » de F1 mène à B3 (foyer de 2), pas à P1.
  - Les variantes d'erreur (A3, A5, A9, B2, B4, B8, C6, D7, G1, G3 à G5) et les notifications (H2 à H5) sont déclenchées par le système. Leur absence de lien entrant est normale.
- **Impact :** trois parcours ne peuvent pas être parcourus dans le prototype, et le développement n'en voit pas l'entrée :
  - le lundi : D11, puis E14, puis C9 ;
  - Karim qui propose la répartition (B14) ;
  - tout le foyer de 3 : P1, P2, C14, P3, P4, P5.
- **Changement :**
  - D11 comme accueil d'un lundi, atteint depuis H2.
  - C12 « Attendre Karim » ouvre la branche qui mène Karim de B10 à B14.
  - F1 « Inviter quelqu'un » mène à P1 quand un partenaire a déjà rejoint ; P1 enchaîne sur P2, puis P3 et P4.
  - La ligne de Karim dans F1 mène à B13 quand l'invitation est déclinée.
  - E3 mène à D13.
- **Heuristique :** contrôle et liberté de l'utilisateur.

### 13. Après un refus, l'invitation reste affichée « en attente »

- **Écrans :** B9, B11, B14, B12 → F7
- **Preuve :**
  - « Refuser l'invitation » (B9), « Finalement, ne pas rejoindre ce foyer » (B11, B14) et « Ne pas rejoindre ce foyer » (B12) mènent tous à F7.
  - F7 affiche « Invitation de Virginie · en attente · valable jusqu'au 22 oct ».
  - Au même moment, B13 dit à Virginie « Invitation déclinée le 10 oct ».
- **Impact :**
  - La personne qui vient de refuser ne peut pas savoir si son refus est pris en compte.
  - Les deux membres voient deux états différents.
- **Changement :** une variante de F7 après refus, sans carte d'invitation : « Vous avez refusé l'invitation de Virginie le 10 oct. Elle en est informée. »
- **Heuristique :** visibilité de l'état du système.

### 14. La descente de niveau et le blocage ne sont jamais écrits en toutes lettres

- **Écrans :** E4, E15
- **Preuve :**
  - E4 : « Niveau 2 : Karim n'a rien saisi depuis 2 semaines ». Le cadenas qui porte le blocage est en `aria-hidden="true"`.
  - E15 : « Niveau 2 : vous n'avez rien enregistré pendant 2 semaines ».
  - E11, lui, écrit en clair « le foyer redescend au niveau 2 et sa progression est bloquée ».
- **Impact :**
  - La conséquence la plus lourde du produit repose sur une icône que le lecteur d'écran ne lit pas.
  - « Niveau 2 » peut se lire comme un état, pas comme une chute depuis le niveau 3.
- **Changement :**
  - E4, titre : « Le foyer redescend au niveau 2 et sa progression est bloquée ».
  - E4, sous le titre : « Karim n'a enregistré aucune tâche du 1er au 14 fév. »
  - E15 : même formule, avec « vous ».
- **Heuristique :** visibilité de l'état du système.

### 15. Les modèles de messages accordent au masculin un genre que l'app ne connaît pas

- **Écrans :** E3, D13, E15, E4, E11, D14, C12, B9
- **Preuve :**
  - E3, D13 et E15 : « Absent ? ».
  - E4 : « Karim était absent ? ».
  - E11 : « Karim est absent ? » et « Il n'a enregistré aucune tâche ».
  - D14 et C12 : « dès qu'il aura rejoint » et « dès qu'il a donné ».
  - B9 : « Connecté en tant que Karim ».
  - Le modèle `User` ne reçoit qu'un prénom (backlog §1.7).
  - P5 emploie déjà la forme épicène « Absence de Karine ? ».
- **Impact :** les mêmes modèles diront « Absent ? » à Virginie ou à Karine. Pour un produit féministe dans son message, mégenrer les femmes dans les alertes casse la règle de ton.
- **Changement :**
  - Formes épicènes, comme dans P5 : « Absence ? », « Absence de Karim ? », « Aucune tâche enregistrée depuis 2 semaines », « dès que Karim aura rejoint », « Compte : Karim · karim.benali@gmail.com ».
  - Point médian seulement là où aucune forme épicène n'existe.
- **Incertitude :** si le genre doit être enregistré sur le compte, ce constat devient mineur.
- **Heuristique :** correspondance entre le système et le monde réel.

### 16. Des contrôles faits main sont invisibles pour les technologies d'assistance (hors D6)

- **Écrans :** C1, M1, B10, C3, C16, D3, E1, E14, P4
- **Preuve :**
  - C1 et M1 : `<label class="it"><span class="chk on">…</span>Préparer un repas</label>`, sans case à cocher.
  - B10 et C3 : `role="radiogroup"` qui contient `<span class="x">J'aime</span>`, sans `role="radio"` ni `aria-checked`. La sélection ne se voit qu'au remplissage.
  - C16 : les interrupteurs « Proposer une répartition chaque lundi » et « Reporter l'écart » sont des `role="switch"` sans nom accessible.
  - D3 : les filtres sont des `<span class="chip x">Toutes · 6</span>`.
  - E1, E14 et P4 : des onglets internes `role="tab"` sans panneau associé.
- **Impact :** sans la vue ou sans pointeur, les tâches suivantes sont impossibles ou muettes :
  - choisir les tâches du foyer ;
  - donner ses préférences ;
  - régler la répartition ;
  - filtrer les tâches.
- **Changement :**
  - Une vraie case à cocher dans chaque ligne de C1 et M1.
  - Des boutons radio dans B10 et C3.
  - Sur C16, un `aria-labelledby` qui pointe vers le texte de la ligne.
  - Des filtres en boutons `aria-pressed`.
  - Sur E1, des onglets avec `aria-controls` et un `tabpanel`.
- **Fait quand :** chaque contrôle annonce son nom, son rôle et son état sous VoiceOver, et bascule avec la barre d'espace.
- **Heuristique :** cohérence et standards.

---

## Mineur

### 17. Des actions irréversibles n'ont ni confirmation ni annulation

- **Écrans :** C9, E12, B5
- **Preuve :**
  - C9 : « Remettre à zéro » renvoie directement à C9.
  - E12 : « Supprimer cette saisie » mène à E6.
  - B5 : « Annuler l'invitation » mène à B3.
  - Aucune variante de C9 ne montre ce que voit Karim, qui ne peut pas remettre l'écart à zéro.
- **Impact :**
  - Un toucher efface l'écart que Virginie a porté, ou retire un enregistrement du bilan, sans retour possible.
  - Karim ne sait pas pourquoi il n'a pas le bouton.
- **Changement :**
  - Un bandeau d'annulation de 10 s, comme sur D8 : « Écart remis à zéro. Annuler · 9 s ». Même bandeau pour E12 et B5.
  - Côté Karim, à la place du bouton sur C9 : « Seule Virginie peut remettre cet écart à zéro. »
- **Heuristique :** contrôle et liberté de l'utilisateur.

### 18. L'écart reporté s'écrit en « points » (à trancher)

- **Écran :** C9
- **Preuve :** « Report de la semaine 42 : Virginie +3 points. » et « Karim prend 2 points de plus. 1 point reste, reporté. »
- **Incertitude :** la règle dit que les pourcentages s'écrivent seuls, sans « x points au-dessus ». L'écart est par nature une différence : il n'est pas sûr que la règle le couvre.
- **Changement, si la règle s'applique :** écrire chaque état comme une part :
  - « Semaine 42 : Virginie 53 %. »
  - « Proposé cette semaine : Virginie 48 %, Karim 52 %. »
- **Heuristique :** correspondance entre le système et le monde réel.

### 19. Un écran de réussite nomme des membres

- **Écran :** E5
- **Preuve :** « Virginie et Karim ont tous deux enregistré des tâches. » et « Le compte des semaines sans saisie de Karim repart de zéro. » La décision veut qu'en cas de réussite, on ne nomme personne.
- **Impact :** le déblocage rappelle à tout le foyer qui avait manqué, sur un écran de réussite.
- **Changement :**
  - « Chaque membre a enregistré au moins une tâche. La semaine est aussi équilibrée : elle compte pour le niveau 3. »
  - « Le compte des semaines sans saisie repart de zéro. »
- **Heuristique :** cohérence et standards.

### 20. Un même fait apparaît avec des chiffres ou des libellés différents

- **Écrans :** F1, M1, F3, D5, D9, D1, D3, E3, E4, P4, E9, B3, B4
- **Preuve :**
  - Nombre de tâches : F1 « Tâches du foyer 14 », M1 « 16 tâches actives », F3 « ses 16 tâches ».
  - D5 : « Dernières fois · depuis le 8 oct » liste un enregistrement du « 6 oct », puis dit « 1 fois sur 1 depuis le 8 oct ».
  - D9 :
    - daté « jeudi 8 oct, 18:20 », il affiche « Tâches 12 » alors que D1, le même jour, affiche « 0 tâche enregistrée » ;
    - atteint depuis B13 (« déclinée le 10 oct »), il dit « Karim n'a pas encore rejoint · expire le 22 oct ».
  - D3 :
    - « Préparer le dîner » et « Gérer la liste de courses », quand le catalogue dit « Préparer un repas » et « Faire la liste de courses » ;
    - D3 et D5 assignent « Payer les factures » à Virginie et « Préparer les sacs d'école » à Karim, l'inverse de C9.
  - E3 : « aucune tâche cette semaine » pour la semaine 5, déjà close (D13 : « Semaine 5 close »).
  - E4 :
    - « saisi », quand tous les autres écrans disent « enregistré » ;
    - daté « mercredi 17 fév » sans heure, alors que la descente ne s'applique qu'après 20:00 (E11).
  - P4 : la barre de progression est à `width:40%` pour « 4 semaines équilibrées · 6 pour le niveau 3 ». Les autres barres suivent le compte rapporté au seuil, comme E1 à 33 % pour 1 sur 3 : ce serait 67 %.
  - E9 : « Atteint le 13 juin 2027 » tombe un dimanche, alors que les niveaux changent le lundi.
  - Même état, deux sous-titres : B3 « La répartition se mesure à partir de deux membres », B4 « Les chiffres n'existent qu'à deux ».
- **Impact :** chaque écart entame la confiance dans les chiffres d'un produit dont la valeur est dans les chiffres.
- **Changement :** une valeur et un libellé par fait, repris à l'identique sur chaque écran cité.
- **Heuristique :** cohérence et standards.

### 21. La barre du temps porte un repère à 50 % alors que le temps ne compte pas

- **Écrans :** E1, E14
- **Preuve :**
  - La barre « Temps passé » porte le même repère `left:calc(50% - 1px)` que les deux charges comptées.
  - I4 : « Le temps est affiché, jamais compté. »
- **Impact :** le temps se lit comme un troisième objectif à atteindre.
- **Changement :** retirer le repère de la barre du temps et ajouter sous elle « Affiché, ne compte pas pour l'équilibre. »
- **Heuristique :** correspondance entre le système et le monde réel.

### 22. L'intro formule la règle d'absence de façon ambiguë

- **Écran :** I3
- **Preuve :** « Une seule personne du foyer, vous comprise, peut déclarer l'absence. »
- **Impact :** la phrase se lit « une seule personne a le droit ». La décision dit l'inverse : n'importe quel membre peut déclarer, et une seule déclaration suffit.
- **Changement :** « N'importe quel membre, vous compris·e, peut déclarer l'absence. Un seul « Oui » suffit. »
- **Heuristique :** aide et documentation.

### 23. La règle par défaut de la pastille contredit la décision

- **Écran :** P2
- **Preuve :**
  - P2 : « Par défaut : initiale et dernière lettre du prénom. »
  - La décision, que P1 applique (« V », « Km ») : l'initiale seule, et deux lettres seulement quand deux initiales coïncident.
- **Changement :** « Par défaut : votre initiale ; deux lettres si un autre membre a la même. »
- **Heuristique :** cohérence et standards.

### 24. Le foyer de 3 emprunte des écrans du foyer de 2

- **Écrans :** P4, P5, P6
- **Preuve :**
  - P5 : « Oui, absence » mène à E10 (« Karim était en pause ») et « Non » mène à E4 (Karim).
  - P4 : l'onglet « 4 semaines » mène à E2, un foyer de 2.
  - P6 : ouvert depuis C14, foyer de 3, il liste 5 membres, dont Inès et Paul.
  - P5 ne dit pas que la question est aussi posée à Karine, contrairement à E11.
  - Les titres du canvas ne correspondent pas aux écrans :
    - P5 « 2 réponses sur 3 », alors que l'écran n'affiche aucun compte de réponses ;
    - P6 « foyer de 5 et plus », alors que l'écran dit « Dès 3 membres ».
- **Changement :**
  - Des variantes à trois de E10, E4 et E2.
  - P6 avec les trois membres.
  - P5 : ajouter « La question est aussi posée à Karine. Un seul « Oui » suffit. »
- **Heuristique :** cohérence et standards.

### 25. Des cibles tactiles font moins de 44 px

- **Écrans :** E7, E10, D6, C5, E1, E14, E2, P4, B7, C1, M1, D4, F5, G5, D5, C16, F4, H4
- **Preuve :**
  - Changement de semaine sur E7 et E10 : `.sw a{width:36px;height:36px}`.
  - D6 : le pas de la durée fait `.sb{width:44px;height:40px}`.
  - C5 : les options de Répétition font `height:40px`.
  - E1, E14, E2 et P4 : onglets en `min-height:40px`.
  - Liens en `min-height:40px` sur B7, C1, M1, D4, F5 et G5.
  - D5 : « Modifier » n'a pas de hauteur minimale, soit environ 22 px.
  - C16, F4 et H4 : des interrupteurs de 44×26, seuls cliquables dans leur ligne.
  - Tout dépasse 24 px, sauf le « Modifier » de D5. L'exception d'espacement s'y applique probablement, puisqu'il est seul dans la barre du haut.
- **Changement :**
  - Une hauteur minimale de 44 px partout.
  - Toute la ligne cliquable pour les interrupteurs.
- **Fait quand :** chaque cible mesure au moins 44×44 dans l'inspecteur.
- **Heuristique :** cohérence et standards.

### 26. Le badge « Ult. » est sous 4,5:1

- **Écran :** I2
- **Preuve :** blanc sur #c8553d, en gras de 15 px : 4,35:1. À cette taille, le seuil est de 4,5:1. L'encre sur terracotta ferait pire (4,1:1).
- **Paires qui passent :**
  - #55625b sur #f6fbf8 : 6,1:1 ; sur #e3efe8 : 5,4:1 ; sur menthe : 5,1:1.
  - #1d5c3f sur #f6fbf8 : 7,6:1.
  - Barre terracotta sur le fond de piste #cfe2d7 : 3,2:1.
- **Changement :** passer le badge en 19 px gras (seuil de 3:1), ou en fond #0f1a14 avec un texte #b9f2d4, comme les boutons.
- **Heuristique :** cohérence et standards.

### 27. Des états et des relations ARIA manquent

- **Écrans :** tous les onglets (TabBar), C2, C7, D10, P6, A3, B2, B4, C6, D7, C5, F6, D6, I1, I2, I3, Balance
- **Preuve :**
  - Aucun `aria-current` sur les 100 fichiers : l'onglet actif n'est marqué que par la couleur et la graisse.
  - Les boîtes de dialogue C2, C7, D10 et P6 n'ont pas `aria-modal`.
  - Aucun `aria-invalid` ni `aria-describedby` : sur A3, B2, B4, C6 et D7, le message d'erreur n'est pas relié à son champ.
  - Des labels ne visent aucun champ : « Échéance » (C5), « Du » et « Au » (F6), « Tâche » (D6).
  - I1 à I3 : `aria-label="Écran 1 sur 3"` sur un `div` sans rôle, donc jamais annoncé.
  - Balance : le `role="img"` n'inclut pas le titre. Les deux balances d'un même écran s'annoncent de la même façon.
- **Changement :**
  - `aria-current="page"` sur l'onglet actif.
  - `aria-modal="true"` sur les boîtes de dialogue, avec le focus envoyé dans la boîte.
  - `aria-invalid` et `aria-describedby` vers le message d'erreur.
  - `for` sur chaque label.
  - `role="img"` sur les points de progression de l'intro.
  - Le titre au début de l'`aria-label` de Balance.
- **Fait quand :** sur D2, VoiceOver annonce « Accueil, onglet, page actuelle » et « Charge mentale : Virginie 71 %, Karim 29 %, repère à 50 % ».
- **Heuristique :** cohérence et standards.

### 28. Des états manquent

- **Écrans :** D2, E1, C9, D11, E11, P5, A8
- **Preuve :**
  - **Chargement :** aucun écran ne montre un bilan ou une répartition en cours de calcul, par exemple le lundi entre 3:00 et l'ouverture.
  - **Premier usage du Bilan :** en semaine 41, avant la première clôture, E1 n'a pas de variante vide.
  - **E11 et P5 :** rien n'est prévu une fois qu'un autre membre a répondu « Oui ».
  - **A8 :** pas d'erreur quand les deux mots de passe diffèrent.
- **Changement, à reprendre mot pour mot :**
  - E1, premier usage : « Premier bilan dimanche 11 oct à 20:00. Enregistrez ce que vous faites d'ici là. »
  - E11 et P5 : « Virginie a déclaré l'absence de Karim le 15 fév. Rien d'autre à faire. »
  - A8 : « Les deux mots de passe sont différents. »
  - Chargement : des zones en squelette aux dimensions des cartes.
- **Heuristique :** aide à reconnaître, diagnostiquer et réparer les erreurs.

### 29. Les conditions d'utilisation et la politique de confidentialité mènent à une page 404

- **Écrans :** A2, B7
- **Preuve :** `href="G2-Introuvable.dc.html"` sur « conditions d'utilisation » et sur « politique de confidentialité ».
- **Impact :** on consent au traitement de données sur la vie du foyer sans pouvoir lire les termes.
- **Changement :** ajouter les deux écrans.
- **Heuristique :** aide et documentation.

### 30. Des liens secondaires mènent au mauvais endroit

- **Écrans :** D3, E3, A3, C3, C1
- **Preuve :**
  - D3 : « Les miennes · 3 » mène à D4, qui affiche « Les miennes · 1 ».
  - E3 (Karim) : « Fermer » mène à D2, l'accueil de Virginie.
  - A3 : « Créer mon compte » mène à B1 et saute A10, la confirmation de l'email.
  - C3 : le retour mène à F1, même ouvert depuis C16.
  - C1 : le retour mène à B5, même après « Inviter plus tard » sur B3.
- **Changement :**
  - Le filtre de D3 garde l'écran D3 et filtre sur place.
  - Le « Fermer » d'E3 mène à D13.
  - A3 mène à A10.
  - C3 et C1 reviennent à l'écran d'origine.
- **Heuristique :** contrôle et liberté de l'utilisateur.

### 31. Une animation tourne sans fin

- **Écran :** I3
- **Preuve :** `.bar{animation:breathe 2.4s 1.4s ease-in-out infinite}`. La préférence de mouvement réduit est respectée, mais rien n'arrête l'animation (WCAG 2.2.2 au-delà de 5 s).
- **Changement :** 3 itérations, comme `.ping` sur le même écran.
- **Heuristique :** esthétique et design minimaliste.

---

## Cosmétique

### 32. La navigation de semaine tourne en rond, et E2 n'a pas de barre d'onglets

- **Écrans :** E14, E2
- **Preuve :**
  - Sur E14, « Précédent » mène à E14.
  - Sur E2, « Précédent » mène à E2.
  - E2 n'importe pas `TabBar`, contrairement à E1 et E14.
- **Changement :**
  - « Précédent » ouvre la semaine 41 ou les semaines 38 à 41.
  - E2 importe `TabBar` avec `active="bilan"`.

### 33. Les préférences gardent un texte d'avant l'arrivée de Karim

- **Écran :** C3
- **Preuve :** « Karim donnera les siennes de son côté » s'affiche depuis Foyer, alors que F1 indique « Karim · Membre · depuis le 9 oct ».
- **Changement :** « Personne ne voit les préférences des autres. »

---

## Verdicts par heuristique

- **Visibilité de l'état du système :** cassée, par « Aucun écran ne montre qui a validé la répartition, ni un réglage en attente ».
- **Correspondance entre le système et le monde réel :** cassée, par « Les modèles de messages accordent au masculin un genre que l'app ne connaît pas ».
- **Contrôle et liberté de l'utilisateur :** cassé, par « Des liens mènent au mauvais écran sur trois parcours clés ».
- **Cohérence et standards :** cassés, par « Le terracotta et le vert ne disent plus la même chose d'un écran à l'autre ».
- **Prévention des erreurs :** cassée, par « Les parts « Prévu cette semaine » ne découlent pas des assignations et cachent une charge mentale hors zone ».
- **Reconnaissance plutôt que rappel :** tient.
- **Flexibilité et efficacité :** tient.
- **Esthétique et design minimaliste :** tendue, par « Une animation tourne sans fin ».
- **Aide à reconnaître, diagnostiquer et réparer les erreurs :** tendue, par « Des états manquent ».
- **Aide et documentation :** tendue, par « L'intro formule la règle d'absence de façon ambiguë ».

---

## Parcours cognitif

Seules les étapes en hésitation (une réponse « non » aux quatre questions) ou en échec (deux ou plus) figurent ici.

**Créer le foyer et inviter (Virginie)**

| Étape | Résultat | Constat |
|---|---|---|
| C12 « Attendre Karim » | Hésitation : comprendre ce qui va se passer | Deux règles affichées pour savoir qui propose la répartition quand Virginie attend Karim |
| C4 lire la part et valider | Hésitation : le « 50 % » est faux | Les parts « Prévu cette semaine » ne découlent pas des assignations… |
| C4 → D1 | Hésitation : le retour contredit l'action | Après « Valider la répartition », l'accueil affiche « Répartition à faire » |

**Rejoindre en tant que partenaire (Karim)**

| Étape | Résultat | Constat |
|---|---|---|
| B7 « me connecter pour accepter » → A4 → D2 | Échec : B9 introuvable, arrivée sur l'accueil de Virginie | Des liens mènent au mauvais écran sur trois parcours clés |
| Branche « Virginie vous attend » (B14) | Échec : aucune entrée | Des écrans clés n'ont aucun lien entrant |
| B10 préférences au lecteur d'écran | Échec : état non annoncé, contrôle non activable | Des contrôles faits main sont invisibles pour les technologies d'assistance (hors D6) |
| B11 lire la barre | Hésitation : le terracotta est sur Virginie | Le terracotta et le vert ne disent plus la même chose d'un écran à l'autre |
| B11 « + Ajouter une tâche » → C5 → C1 | Échec : retour dans la mise en place de Virginie | Des liens mènent au mauvais écran sur trois parcours clés |
| B12 ou B9 refuser → F7 | Hésitation : l'invitation reste « en attente » | Après un refus, l'invitation reste affichée « en attente » |

**Enregistrer une tâche**

| Étape | Résultat | Constat |
|---|---|---|
| D6 choisir la tâche, la durée et le jour, au clavier ou au lecteur d'écran | Échec : aucun champ focalisable | Enregistrer une tâche est impossible au clavier et au lecteur d'écran |

**Lire le bilan du lundi et valider la répartition**

| Étape | Résultat | Constat |
|---|---|---|
| Ouvrir l'accueil un lundi | Échec : la barre d'onglets mène à D2, pas à D11 | Des écrans clés n'ont aucun lien entrant |
| E1 lire le verdict | Hésitation : provisoire ou définitif ? | Le bilan dans l'app ne dit pas s'il est provisoire ou définitif |
| C9 « Valider » → D2 | Hésitation : aucun retour sur l'état de la validation | Aucun écran ne montre qui a validé la répartition, ni un réglage en attente |
| C9 « Remettre à zéro » | Hésitation : aucune confirmation, aucun retour | Des actions irréversibles n'ont ni confirmation ni annulation |

**Gérer une absence ou une pause**

| Étape | Résultat | Constat |
|---|---|---|
| I3 comprendre qui peut déclarer | Hésitation : « une seule personne… peut » | L'intro formule la règle d'absence de façon ambiguë |
| E4 et E15 comprendre la conséquence | Hésitation : la descente n'est pas écrite | La descente de niveau et le blocage ne sont jamais écrits en toutes lettres |

**Foyer de 3 personnes**

| Étape | Résultat | Constat |
|---|---|---|
| F1 « Inviter quelqu'un » → B3 | Échec : P1 jamais atteint | Des écrans clés n'ont aucun lien entrant |
| P2 (Karine) « Continuer » → C14 | Échec : arrivée sur la répartition de Virginie | Des liens mènent au mauvais écran sur trois parcours clés |
| C14 lire 34 / 33 / 33 | Hésitation : Karine porte environ 70 % de la charge mentale prévue | Les parts « Prévu cette semaine » ne découlent pas des assignations… |
| P5 « Oui » → E10 | Hésitation : l'écran parle de Karim | Le foyer de 3 emprunte des écrans du foyer de 2 |

---

## Ce qui marche bien, à protéger

- **Chiffres du bilan cohérents d'un écran à l'autre :**
  - D2 (71 %, 17 tâches sur 24), puis D8 après un enregistrement (72 %, 18 tâches sur 25), puis E1, E2 et H3 (18/7, 18/31, 10 h 00 contre 5 h 10).
  - E9 et E13 (43 sur 50, puis 42 sur 50 = 84 %).
  - Le report de la semaine 42 (+3) est bien la moyenne de 54 % et 52 %.
- **La règle d'absence est exprimée exactement comme décidée** dans E11, H5, F8 et I4 : un seul « Oui », de n'importe qui, la personne absente comprise, réponse jusqu'au mercredi 20:00, sans accord à demander.
- **Le bilan est factuel et utile :**
  - E1 : « Il aurait suffi que Karim prenne 3 des 18 tâches mentales de Virginie. » ;
  - E1 : le cadre « À retenir pour la répartition de lundi » ;
  - P4 transpose le même modèle à trois.
  - C'est direct, sans adoucir, et ça dit quoi changer.
- **D8 permet d'annuler pendant 9 s**, dans un `role="status"`, et met à jour les chiffres tout de suite.
- **H1 annonce les notifications avant de les demander :**
  - il dit ce qui sera envoyé et ajoute « Pas de rappel quotidien, pas de relance pour enregistrer » ;
  - « Plus tard » a le même poids visuel que « Activer » ;
  - H4 garde l'email en secours quand les notifications sont refusées.
- **La propriété des données est rappelée là où elle compte :** A2, B6, E6, F2, F7, C2 et C7. C2 et C7 donnent même le nombre d'enregistrements conservés.
- **Les messages d'erreur sont précis et réparables :** « Trop court : 3 caractères sur 6 minimum » (A3), les trois variantes de B4, et G4 qui garde la saisie.
- **Les règles visuelles décidées sont tenues dans l'ensemble :**
  - les alertes sont en encre, sans rouge ni jaune ;
  - l'en-tête des onglets se limite au logo et au nom du foyer ;
  - les animations d'E8 et d'I1 à I3 respectent la préférence de mouvement réduit ;
  - la plupart des cibles font au moins 44 px (pastilles, retours, boutons de 52 px).

---

## Actions dans l'ordre

1. Les parts « Prévu cette semaine » ne découlent pas des assignations et cachent une charge mentale hors zone
2. Enregistrer une tâche est impossible au clavier et au lecteur d'écran
3. Des liens mènent au mauvais écran sur trois parcours clés
4. Des écrans clés n'ont aucun lien entrant
5. Après « Valider la répartition », l'accueil affiche « Répartition à faire »
6. Aucun écran ne montre qui a validé la répartition, ni un réglage en attente
7. Le bilan dans l'app ne dit pas s'il est provisoire ou définitif
8. Deux règles affichées pour savoir qui propose la répartition quand Virginie attend Karim
9. Quitter le foyer renvoie les tâches « au foyer », que la décision a supprimé
10. Une semaine sans charge mentale est appelée « non équilibrée » au lieu de « neutre »
11. Trois écrans promettent une file d'attente hors ligne que le backlog ne prévoit pas en V1
12. Le terracotta et le vert ne disent plus la même chose d'un écran à l'autre
13. La descente de niveau et le blocage ne sont jamais écrits en toutes lettres
14. Les modèles de messages accordent au masculin un genre que l'app ne connaît pas
15. Après un refus, l'invitation reste affichée « en attente »
16. Des contrôles faits main sont invisibles pour les technologies d'assistance (hors D6)
17. Un écran de réussite nomme des membres
18. Des actions irréversibles n'ont ni confirmation ni annulation
19. Un même fait apparaît avec des chiffres ou des libellés différents
20. L'intro formule la règle d'absence de façon ambiguë
21. Le foyer de 3 emprunte des écrans du foyer de 2
22. Des états manquent
23. Des états et des relations ARIA manquent
24. Des cibles tactiles font moins de 44 px
25. La barre du temps porte un repère à 50 % alors que le temps ne compte pas
26. La règle par défaut de la pastille contredit la décision
27. Le badge « Ult. » est sous 4,5:1
28. Les conditions d'utilisation et la politique de confidentialité mènent à une page 404
29. Des liens secondaires mènent au mauvais endroit
30. L'écart reporté s'écrit en « points » (à trancher)
31. Une animation tourne sans fin
32. La navigation de semaine tourne en rond, et E2 n'a pas de barre d'onglets
33. Les préférences gardent un texte d'avant l'arrivée de Karim
