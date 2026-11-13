# 50/50 — brief produit

## Le problème

Dans un foyer, une partie du travail domestique ne se voit pas : y penser, prévoir, décider. Cette charge mentale retombe le plus souvent sur une seule personne, en général une femme, et elle n'apparaît dans aucun chiffre. Sans données, la discussion reste une affaire de ressenti.

## Le produit

50/50 est une app mobile qui mesure la répartition réelle des tâches dans un foyer. Chaque membre enregistre ce qu'il a fait lui-même. L'app sépare deux charges :
- **la charge mentale :** planifier, organiser, décider ;
- **l'exécution :** faire physiquement.

Le temps passé est affiché, mais il ne compte pas dans l'équilibre.

Chaque lundi :
- l'app clôt la semaine et publie un bilan factuel ;
- elle propose une répartition des tâches pour la semaine qui commence, que tous les membres valident.

Le foyer progresse en niveaux à mesure qu'il cumule des semaines équilibrées.

## Pour qui

En premier lieu, la personne qui porte la charge et veut des faits. Elle crée le foyer et invite son ou sa partenaire.

Ensuite, chaque membre du foyer : deux personnes le plus souvent, jusqu'à 3 et plus.

## Ce que la première version fait

- Comptes, création du foyer et invitation par email, avec un consentement explicite pour rejoindre.
- Mise en place :
  - choix des tâches dans un catalogue ;
  - tâches personnalisées ;
  - préférences de chaque membre ;
  - répartition proposée, puis validée par tous les membres.
- Enregistrement d'une tâche en trois gestes au plus, rétrodaté jusqu'à 7 jours.
- Bilans :
  - bilan de la semaine (provisoire le dimanche, définitif le lundi à 3:00) ;
  - historique sur 4 semaines ;
  - journal personnel de chaque membre.
- Progression du foyer par niveaux (1, 3, 6, 10 et 15 semaines équilibrées), et maintien du niveau ultime.
- Semaine sans saisie :
  - une semaine vide déclenche une alerte ;
  - après deux semaines, une question d'absence est posée à tout le foyer ;
  - sans déclaration d'absence, le foyer redescend d'un niveau et sa progression est bloquée.
- Pauses déclarées par la personne concernée ou par un autre membre, y compris après coup.
- Notifications et emails : bilan du dimanche, alerte, question d'absence, répartition du lundi.

## Ce que la première version ne fait pas

- **Pas de mode hors ligne :** sans réseau, on ne peut pas enregistrer.
- **Pas de genre :** l'app ne connaît pas le genre de ses membres, et toutes les formulations sont épicènes.
- **Pas de tâche « pour le foyer » :** chaque tâche a au moins une personne assignée.
- **Pas d'écriture dans le journal d'un autre membre :** chacun n'enregistre que ce qu'il a fait.

## Ce qui ne se négocie pas

- **Ton :** féministe dans le message, universel dans l'exécution. Factuel et direct. On n'adoucit jamais un chiffre et on ne protège pas une personne de ses chiffres. Le test : écrirait-on ce texte pour une marque masculine engagée ?
- **Données :**
  - les enregistrements appartiennent à la personne qui les a faits, et la suivent si elle quitte le foyer ;
  - le foyer n'est qu'un agrégat ;
  - le motif d'une pause reste privé.
- **Règles de calcul et de progression :** elles sont dans `docs/backend-backlog.md`, section « Product rules the backend implements ».

## Ce qui dira que ça marche

- Les deux membres enregistrent des tâches chaque semaine.
- La part de charge mentale de la personne qui en porte le plus baisse au fil des semaines.
- Le foyer valide la répartition du lundi sans la contester.
