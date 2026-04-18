# Backlog: issues et ameliorations

## Legende

- Priorite: P0 (critique), P1 (haute), P2 (moyenne), P3 (confort)
- Type: Bug, TechDebt, Improvement, Test
- Statut: Todo, In Progress, Done

## Backlog actif

| ID | Priorite | Type | Sujet | Description courte | Statut |
|---|---|---|---|---|---|
| SS-001 | P0 | Bug | Ouverture article premier clic | Le reader peut afficher ancien contenu avant chargement article | Todo |
| SS-002 | P0 | Bug | Doublons article en bibliotheque | Ouvrir plusieurs fois un article ne doit pas creer de copies | Todo |
| SS-003 | P1 | Improvement | Retour auto article -> livre | A la fin d un article, revenir vers le livre courant de facon fiable | In Progress |
| SS-004 | P1 | Test | Tests etat courant | Ajouter tests sur `currentBookId` / `currentArticleId` / `currentArticleOpenToken` | Done |
| SS-005 | P1 | Improvement | UX completion card | Harmoniser coins/espacements/transition avec toutes cartes reader | In Progress |
| SS-006 | P2 | TechDebt | Clefs UserDefaults | Centraliser les clefs dans une enum partagee | Todo |
| SS-007 | P2 | Test | Guardian API mock | Eviter dependance reseau dans suite principale | Todo |
| SS-008 | P2 | Improvement | Detection suggested locale | Couvrir plus de variantes linguistiques follow/suggested | Todo |
| SS-009 | P3 | Improvement | Dashboard local usage | Stats hebdo locales: temps recupere, sessions reduites | Todo |
| SS-010 | P1 | Improvement | Intention de session | Sheet pre-session (objectif, budget, sortie) avec persistance locale | Todo |
| SS-011 | P1 | Improvement | Risk score JITAI | Moteur local de score risque + tiers low/mid/high | Todo |
| SS-012 | P1 | Improvement | Friction graduelle | Interventions soft/hard selon risque avec cooldown | Todo |
| SS-013 | P1 | Improvement | Alternatives immediates | Actions directes (reader/timer/quit) depuis friction cards | Todo |
| SS-014 | P2 | Improvement | XP orientee outcomes | Bonus XP pour sorties reussies et respect budget | Todo |
| SS-015 | P2 | Improvement | Review hebdo actionnable | Ecran hebdo local avec recommandations de regles | Todo |
| SS-016 | P1 | Improvement | Dashboard natif StopScroll | Vue SwiftUI active (objectifs, usage, XP) + entree section utilisateur + entree secondaire settings | Done |
| SS-017 | P1 | Improvement | Cohabitation livre/article reader | Switcher explicite Livre/Article + reprise de contexte sans friction | In Progress |
| SS-018 | P2 | Improvement | Actions rapides bibliotheque reader | Tap direct pour ouvrir + swipe natif delete/reset/rename dans Settings reader | Done |
| SS-019 | P1 | Improvement | Navbar native synchronisee | Barre native, badge messages, masquage navbar Instagram, navigation onglets vers WebView | Done |

## Idees d amelioration produit

1. Mode Focus programmatique
- Definir des plages horaires avec agressivite d injection

2. Personnalisation des cartes
- Permettre activation/desactivation par type de carte depuis settings

3. Reader ergonomie
- Action rapide pour ajouter un bookmark depuis la barre basse

4. Feedback qualitatif
- Mini prompt ponctuel: "Cette carte vous a aide ?"

## Process issue

1. Creer une issue avec template (bug ou amelioration)
2. Ajouter ID `SS-xxx` dans le backlog
3. Ajouter criteres d acceptation
4. Lier la PR a l issue
5. Mettre a jour la documentation liee au changement
6. Faire un commit dedie (feature/fix + doc)
7. Passer en Done seulement si test manuel + test auto (quand possible)
