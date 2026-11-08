# 50/50 — design system

Les maquettes appliquent ces valeurs, et l'app doit les reprendre telles quelles.

## Couleurs

| Rôle | Valeur |
|---|---|
| Fond | `#f6fbf8` |
| Surface (cartes) | `#ffffff` |
| Aplat menthe (encadré du chiffre de la semaine, boutons sur fond encre) | `#b9f2d4` |
| Encre (texte, bouton principal, alertes) | `#0f1a14` |
| Texte secondaire | `#55625b` |
| Bordures | `#dcebe3` ; champs `#c9dcd1` ; séparateurs `#eaf3ee` |
| Fond des boutons secondaires et des segments | `#e3efe8` / `#eef5f1` |
| Part de la personne qui regarde (barres, part du logo) | terracotta `#c8553d` |
| Piste des barres | `#cfe2d7` |
| Part des autres membres (foyer de 3 et plus) | `#55625b` |
| Données d'une semaine équilibrée | vert foncé `#1d5c3f` |
| Barres de ratio et de progression du foyer | encre `#0f1a14` |

**Règles d'usage**
- **Alerte :** toujours en encre, une pastille ou un bloc noir avec du texte blanc. Jamais de rouge ni de jaune.
- **Terracotta :** il ne marque que la part de la personne qui regarde l'écran.
- **Couleurs de membre :** chaque membre choisit la sienne, unique dans le foyer, parmi menthe `#b9f2d4`, bleu `#dfe7f3`, pierre `#ece6dc`, ciel `#d6ecf3`, sauge `#d3e4c8` et sable `#efe3cf`.
- **Pastille de membre :** l'initiale du prénom, ou deux lettres quand deux initiales coïncident (« Km », « Ke »).
- **Jamais la couleur seule :** chaque couleur s'accompagne d'un mot ou d'un chiffre.

## Typographie

- **Unbounded** (600, 700, 800) pour les titres et la phrase-chiffre de la semaine, avec un interlettrage de −0,02 em.
- **Figtree** (400 à 700) pour tout le reste, avec des chiffres tabulaires.

## Logo

Un cercle de rayon 13, à fond `#f6fbf8` et contour encre de 3. Une part terracotta d'environ 62 % (`M25 8 A13 13 0 1 0 25 32 Z`). Une ligne verticale fixe à 50 % (`M20 2 V38`). Le source SVG est dans chaque en-tête de maquette.

## Composants récurrents

- **Bouton principal :** une pilule encre de 52 px de haut, au texte menthe.
- **En-tête des onglets :** le logo et le nom du foyer, sans avatar.
- **Barre d'onglets :** Accueil, Tâches, Bilan, Foyer (`project/TabBar.dc.html`).
- **Balance :** une barre par charge avec un repère à 50 % (`project/Balance.dc.html`).
