# Roadmap StopScroll

## Vision produit

Reduire le scroll passif sur Instagram en rempla cant les points de friction par des micro-interventions utiles (prise de recul, timer, culture, lecture), tout en gardant une UX fluide.

Spec concrete des prochaines features anti-procrastination:
- voir `docs/ANTI_PROCRASTINATION_FEATURES.md`

## Now (0-4 semaines)

1. Stabilite reader livre/article
- Fiabiliser ouverture article au premier clic
- Garantir retour automatique au livre courant apres fin d article
- Ajouter tests de non-regression sur les etats `currentBookId`/`currentArticleId`

2. Qualite cartes injectees
- Uniformiser animations (reveal, glass, transitions)
- Verifier layout responsif sur tailles ecran iPhone courantes
- Durcir les fallbacks quand une source article ne repond pas

3. Observabilite minimale
- Ajouter logs de debug ciblees (dev mode uniquement)
- Ajouter compteur local des echecs de fetch article

## Next (1-2 mois)

1. Experience lecture
- Resume intelligent (reprendre dernier paragraphe vu)
- Option de vitesse/rythme de lecture personnalisee
- meilleure navigation dans bookmarks

2. Qualite de detection feed
- Affiner detection suggested posts par langue
- reduire faux positifs/faux negatifs via heuristiques simples

3. Fiabilite tests
- Isoler tests reseau (Guardian) avec mode mock optionnel
- etendre fixtures EPUB a plus de structures de livres

## Later (3+ mois)

1. Personnalisation comportementale
- profils d intervention (soft / standard / strict)
- regles horaires (mode focus)

2. Data locale et feedback
- tableau de bord hebdo local (temps recupere, sessions coupees)
- suggestions basees sur usage local

3. Industrialisation
- pipeline CI (build + test)
- conventions release notes + changelog

## Criteres de priorisation

Un sujet passe en priorite haute si:
- impact direct utilisateur (bug bloquant / incomprehension UX), ou
- risque de corruption d etat de lecture, ou
- regression frequente observee.
