# Strategie 2 WebView Instagram (StopScroll)

## Objectif

Eviter la navigation fragile via simulation de clics DOM entre sections Instagram, tout en gardant une UX fluide avec navbar native.

## Architecture cible

1. WebView principale (`main`)
- URL de base: `https://www.instagram.com/`
- Porte les sections feed/search/profile.
- Porte le runtime StopScroll principal.

2. WebView messages (`messages`)
- URL de base: `https://www.instagram.com/direct/inbox/`
- Surface secondaire pour les sections Instagram hors feed (messages/search/profile).
- Active quand l'utilisateur ouvre un onglet Instagram natif autre que feed.

3. Affichage
- Une seule WebView visible/interactable a la fois.
- Switch natif = changement de surface visible (pas recreation immediate).

4. Repartition fonctionnelle
- WebView 1 reste la surface feed prioritaire.
- WebView 2 est la surface de navigation Instagram secondaire.
- Home affiche la surface feed.
- Messages/Search/Profile affichent la surface secondaire.
- Garantie de routage: les commandes de navigation Instagram sont desactivees sur WebView 1 et autorisees uniquement sur WebView 2.
- Ordre de transition: la surface secondaire est rendue active/visible puis la commande de navigation est envoyee.

7. Routage deterministe URL sur surface secondaire
- Messages: `https://www.instagram.com/direct/inbox/`
- Search: `https://www.instagram.com/explore/`
- Profile: `https://www.instagram.com/<pseudo>/`
- Le mapping est centralise dans `InstagramSecondaryRoute` (Swift), teste en unit tests.
- Objectif: eviter les regressions de navigation liees aux changements DOM Instagram.

5. Optimisation JS par surface
- WebView 1 (feed): runtime complet StopScroll.
- WebView 2 (secondaire): profile JS leger (`constants`, `dom-utils`, `nav-management`) + sync nav state periodique.
- Objectif: reduire la charge CPU/memoire de la surface secondaire.

## Optimisations necessaires

1. Pause/reprise runtime JS
- WebView inactive: `setPaused(true)`
- WebView active: `setPaused(false)`
- Effets:
  - stop des scans periodiques
  - blocage des scans et injections
  - pause video best-effort

2. Activation exclusive
- `opacity` + `allowsHitTesting(false)` sur la WebView inactive.
- Evite interactions concurrentes et etats incoherents.

3. Chargement lazily utilisable ensuite
- Les deux WebView sont initialisees puis conservees.
- Le switch est instantane apres le premier chargement.

6. Gouvernance memoire (etape suivante)
- Si pression memoire iOS: detruire la WebView inactive la moins recente.
- Recharger a la demande avec restauration minimale d'URL.

## Eviction memoire V1 implementee

1. Detection
- ecoute de `UIApplication.didReceiveMemoryWarningNotification` cote SwiftUI.

2. Politique
- conserver la WebView active.
- detruire la WebView inactive (`has*Surface = false`).

3. Rehydration
- recreation lazy de la surface au prochain tap utilisateur sur l'onglet correspondant.
- remise de l'etat loading pour garder un feedback propre.

## Decision UX

1. Navbar native reste la source de verite pour:
- livre
- dashboard
- parametres
- switch surface `main` <-> `messages`

2. Pour `home/search/profile`
- On repasse sur la surface `main`.
- Puis on envoie une commande de navigation interne (quand possible).
- Le fallback de navigation peut rester actif selon les contraintes Instagram.

## Risques residuels

1. Les pages Instagram restent dynamiques et peuvent evoluer.
2. Les handlers DOM de navigation peuvent changer entre versions Instagram.
3. Le modele 2 WebView consomme plus de RAM qu'une seule (mais bien moins que 4).

## KPI techniques a suivre

1. Temps moyen de switch `main` <-> `messages`
2. Memoire moyenne par session
3. CPU en idle sur WebView inactive
4. Taux d'echec navigation interne `home/search/profile`

## Etat implementation (V1)

1. Deux surfaces WebView actives: `main` + `messages`
2. Pause/reprise runtime JS par surface
3. Scan periodique stoppe sur surface inactive
4. Barre native conservee comme UI principale
