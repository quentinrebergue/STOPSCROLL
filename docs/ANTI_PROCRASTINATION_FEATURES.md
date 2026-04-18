# Features anti-procrastination (spec integration)

## 1. Objectif

Transformer StopScroll d un systeme de cartes reactives vers un coach comportemental:

1. intervention au bon moment
2. friction graduelle (douce puis ferme)
3. alternative immediate au scroll passif
4. progression orientee "sortie reussie" plutot que simple interaction

## 2. Fondations recherche (inspiration)

1. Implementation Intentions (Si X alors Y)
- source: Gollwitzer et travaux derives

2. Commitment devices
- source: Bryan / Karlan / Nelson

3. JITAI (Just-In-Time Adaptive Interventions)
- source: Nahum-Shani et al.

4. Social media time reduction and well-being
- source: Hunt et al., Allcott et al. (directionnel)

## 3. Features a integrer (MVP concret)

### F1. Intention de session (pre-commit)

UX:
1. a l ouverture d InstagramView (1 fois par session):
- objectif: "Detendre" / "Trouver une info" / "Passer le temps"
- budget temps: 5/10/15/20 minutes
- action de sortie prevue: "Lire 1 page" / "Lancer timer" / "Quitter"

Integration app:
1. nouvel ecran SwiftUI: `SessionIntentSheet`
2. stockage local: `UserDefaults` clef `ss_session_intent_current` (JSON)
3. event bridge optionnel vers JS global:
- `window.__STOPSCROLL_SESSION_INTENT = { goal, budgetMin, exitPlan, startedAt }`

Mesures:
1. `% sessions avec intention explicite`
2. `% sessions respect budget`

### F2. Score de risque procrastination (JITAI simple)

UX:
1. score interne de 0 a 100 mis a jour pendant session
2. a 50+: micro carte douce
3. a 75+: friction active (compte a rebours 5-10s avant continuer)

Integration app:
1. nouveau service Swift: `ProcrastinationRiskEngine`
2. inputs:
- duree session
- nb cards injectees consecutives
- pattern d interaction (tap rapide en boucle)
- plage horaire (soir)
3. output:
- `riskTier = low|mid|high`
4. injection runtime:
- `window.__STOPSCROLL_RISK_TIER`

Mesures:
1. `% escalades mid->high`
2. `% sorties apres intervention high`

### F3. Friction graduelle

UX:
1. niveau soft (mid): rappel de l intention initiale
2. niveau hard (high): bouton "Continuer" active apres delai court
3. jamais de blocage permanent

Integration app:
1. nouvelles templates cartes:
- `friction_soft_*`
- `friction_hard_*`
2. bridge actions:
- `type: "ackFriction"`
- payload: `{ tier, acknowledgedAt }`

Mesures:
1. temps moyen avant reprise du scroll apres friction
2. taux de "quit app" dans les 60s apres friction hard

### F4. Alternative immediate (plan de sortie)

UX:
1. dans les cartes de friction: 3 actions max
- "Lire maintenant"
- "Timer 10 min"
- "Fermer Instagram"

Integration app:
1. mapping direct vers actions existantes:
- open reader
- setTimer
- open settings focus panel
2. ajout source analytics locale: `trigger = friction_card`

Mesures:
1. `% choix alternative vs continue scroll`
2. retention de l alternative a J+7

### F5. XP orientee outcomes (pas juste taps)

UX:
1. conserver XP actuelle
2. ajouter bonus outcome:
- +40 XP si session terminee <= budget
- +25 XP si alternative executee
- +60 XP pour 3 sorties reussies consecutives

Integration app:
1. `XPRewardPolicy` (Swift)
2. nouvelle clef: `ss_xp_streak_success`
3. nouvelle action bridge:
- `type: "grantXPOutcome"`

Mesures:
1. correlation entre XP outcome et baisse duree session

### F6. Retrospective hebdo actionnable

UX:
1. ecran hebdo local:
- "quand tu derapes"
- "ce qui a marche"
- "regle recommandee semaine prochaine"

Integration app:
1. nouvel ecran SwiftUI: `WeeklyReviewView`
2. agregation locale uniquement (pas de backend requis)

Mesures:
1. completion du review hebdo
2. reduction du temps moyen/semaine suivante

## 4. Plan technique incremental (4 sprints)

### Sprint A (faible risque)

1. F1 intention session
2. F5 XP outcome (partiel: bonus "session respectee")

Fichiers cibles:
1. `StopScroll/Views/InstagramView.swift`
2. `StopScroll/Views/SettingsView.swift`
3. `StopScroll/Views/InstagramWebView.swift`

### Sprint B (JITAI minimal)

1. F2 score risque v1
2. F3 friction soft

Fichiers cibles:
1. `StopScroll/Scripts/modules/card-logic.js`
2. `StopScroll/Scripts/modules/runtime-state.js`
3. `StopScroll/Scripts/modules/card-builder/*.js`

### Sprint C (friction hard + alternatives)

1. F3 hard
2. F4 alternatives immediates

Fichiers cibles:
1. `StopScroll/Scripts/modules/card-builder/card-stop.js`
2. `StopScroll/Views/BookReaderView.swift`
3. `StopScroll/Views/InstagramWebView.swift`

### Sprint D (review hebdo)

1. F6 retrospective
2. instrumentation locale complete

Fichiers cibles:
1. `StopScroll/Views/SettingsView.swift`
2. nouveau `StopScroll/Views/WeeklyReviewView.swift`

## 5. Instrumentation locale minimale

Evenements a stocker en local (`ss_events`):

1. `session_started`
2. `session_intent_set`
3. `risk_tier_changed`
4. `friction_shown`
5. `alternative_chosen`
6. `session_ended`
7. `xp_outcome_granted`

Schema event:

1. `name`
2. `ts`
3. `sessionId`
4. `payload` (JSON)

## 6. Criteres de succes produit

KPI cibles (4-8 semaines):

1. -15% duree moyenne session Instagram
2. +20% taux de sorties volontaires dans les 5 min suivant une friction
3. +25% taux de choix d alternative utile

## 7. Contraintes et guardrails UX

1. eviter les popups trop frequentes (cooldown)
2. pas de jugement moral dans le wording
3. interventions adaptatives et desactivables
4. respecter la fluidite: < 16ms dans boucle scan runtime

## 8. Checklist implementation feature (template)

Pour chaque feature ajoutee:

1. spec UX courte (cas nominal + edge cases)
2. bridge contract (type + payload)
3. clefs UserDefaults ajoutees
4. tests unitaires/regression associes
5. doc `ARCHITECTURE.md` + `BACKLOG.md` + commit dedie

## 9. Decisions UI/UX concretes (questions ouvertes)

### Q1. Ou placer le dashboard dans une app qui tourne sur Instagram ?

Decision:
1. dashboard principal en natif SwiftUI (pas injecte dans Instagram)
2. point d entree principal depuis la section utilisateur Instagram via la ligne StopScroll deja injectee
3. point d entree secondaire depuis `SettingsView` (bouton "Dashboard")

Pourquoi:
1. robustesse: UI native moins fragile que le DOM Instagram
2. confidentialite/stockage local plus simple
3. meilleure fluidite pour graphs et historiques

Integration:
1. nouveau `StopScroll/Views/DashboardView.swift`
2. nouveau flag d etat dans `InstagramView`:
- `@State private var showingDashboard = false`
3. bridge JS -> Swift:
- nouveau type `openDashboard`
4. route actuelle:
- la ligne StopScroll (top-menu) envoie `openSettings`; dans Sprint Dashboard, elle enverra `openDashboard`
- fallback: garder `openSettings` si feature flag off

Structure Dashboard (tabs internes):
1. Objectifs (intentions, budget)
2. Usage (temps, sessions, risques)
3. Progression (XP, niveaux, streak)

### Q2. Cohabitation article / livre dans BookReader

Decision:
1. ne plus avoir un seul contexte "courant" implicite
2. introduire un switcher explicite en haut du reader
3. conserver progression separee article vs livre

UX proposee:
1. segmented control fixe:
- "Livre"
- "Article"
2. sous le segment actif, mini liste recente:
- dernier livre lu
- dernier article ouvert
3. bouton rapide "Retour au livre" depuis un article

Integration:
1. nouveau modele d etat:
- `reader_mode = book|article`
- `lastBookId`
- `lastArticleId`
2. evolutions `BookReaderView`:
- composant `ReaderContextSwitcher`
- chargement direct selon mode
3. compat backward:
- conserver `currentBookId` et `currentArticleId`, mais ajouter couche d orchestration mode

Tests a ajouter:
1. switch article -> livre conserve index livre
2. switch livre -> article conserve article courant
3. fermeture/reouverture reader conserve dernier mode

### Q3. Vrai dashboard (objectifs + usage + XP)

Decision:
1. dashboard natif unique avec 3 blocs persistants
2. metrics locales uniquement (MVP sans backend)

Bloc A - Objectifs:
1. objectif actif du jour
2. budget de session restant
3. adherence (respect/non respect)

Bloc B - Usage:
1. sessions du jour/semaine
2. temps total et median session
3. pics de risque (mid/high)

Bloc C - Progression:
1. niveau actuel
2. XP totale + progression niveau
3. streak "sorties reussies"

Integration technique:
1. events locaux deja prevus dans section 5
2. nouveau service `DashboardAggregator` (Swift)
3. calculs en lecture seule a partir de `ss_events` + `ss_xp_total`
4. refresh au `onAppear` + pull-to-refresh local

MVP visualisation:
1. cartes KPI (valeur + variation 7 jours)
2. mini sparkline locale (Swift Charts)
3. 1 recommandation actionnable en bas de page

## 10. Sprint UX prioritaire recommande

1. Sprint UX-1: Dashboard natif + point entree utilisateur
2. Sprint UX-2: ReaderContextSwitcher article/livre
3. Sprint UX-3: Dashboard complet objectifs/usage/XP + recommandations