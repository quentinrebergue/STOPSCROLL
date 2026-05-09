# Architecture StopScroll

## 1. Vue d ensemble

StopScroll combine 2 couches:

1. Couche native iOS (SwiftUI)
- affiche Instagram via `WKWebView`
- injecte les scripts JS dans la page
- gere les ponts JS <-> Swift
- gere la lecture de livres/articles

2. Couche runtime Web (JavaScript injecte)
- detecte les posts remplacables
- choisit un type de carte
- injecte visuellement la carte dans le feed
- pilote des interactions (timer, open article, open settings, open dashboard)

## 2. Flux principal

1. L app charge Instagram dans `InstagramWebView`.
2. Swift injecte les modules JS (`modules/*`, puis `block_reels.js`).
3. Le runtime scanne les posts (`runtime-scan`, `tracking`, `ad-detection`).
4. Quand une opportunite est validee, une carte est construite (`card-builder/*`) puis injectee.
5. Les actions utilisateur passent par le bridge `stopScrollBridge`.
6. Swift traite l action (ex: fetch article, open reader) puis reinjecte les donnees vers JS.

Mise a jour (2026-05-08):
- le choix de type de carte passe prioritairement par une decision native Swift (`requestCardForOpportunity`), puis JS injecte la carte.
- en cas d indisponibilite bridge/timeout, JS conserve un fallback legacy local (`card-logic.js`) pour eviter les trous visuels.

## 3. Bridge natif <-> web

### JS -> Swift

- Handler `openBookReader`: ouvre le lecteur
- Handler `stopScrollBridge`: messages structures (`openArticle`, `fetchGuardianArticle`, `setTimer`, `openSettings`, `openDashboard`, etc.)
- nouveau message `requestCardForOpportunity`: JS demande a Swift une decision de carte versionnee.

Format bridge v1 (enveloppe unifiee):
- `{ v: 1, id: string, type: string, payload: object, ts: number }`
- Compatibilite legacy conservee: string (`"reloadFeed"`) et objets `{ type, ... }`

### Swift -> JS

- Injection d etat global:
  - `__STOPSCROLL_AD_LABELS`
  - `__STOPSCROLL_FREQUENCY`
  - `__STOPSCROLL_ARTICLE_SOURCES`
  - `__STOPSCROLL_DEV_MODE`
  - `__STOPSCROLL_BOOK`
- Callbacks de donnees article:
  - `window.StopScroll.wikipedia._setFromNative(...)`
  - `window.StopScroll.guardian._setFromNative(...)`

- Reponse bridge native (ack/erreur):
  - `window.StopScroll.dom._onNativeBridgeResult({ ok, requestId, type, code?, message?, ts })`

- Reponse decision carte (payload versionne):
  - `{ contractVersion: 1, decision: 'inject' | 'skip', reason: string, card?: { schemaVersion: 1, renderMode: 'legacy-builder-v1', type: string, content: object, meta: object } }`

## 4. Sous-systemes importants

### 4.1 Injection feed

- Detection:
  - `modules/ad-detection.js`
  - labels sponsorises + heuristiques follow/suggested
- Choix carte:
  - priorite native Swift via bridge `requestCardForOpportunity`
  - fallback JS `modules/card-logic.js` (weighted random + anti-repetition)
- Injection:
  - `modules/card-injection.js`

### 4.2 Runtime orchestration

- Etat runtime: `runtime/runtime-state.js`
- Boucle scan: `runtime/runtime-scan.js`
- Gestion UI/navigation: `runtime/runtime-ui.js`, `modules/nav-management.js`, `modules/top-menu.js`

### 4.3 Reader livre/article

- Parsing: `Models/BookParsing/*`
- Persist: `BookStorage` + UserDefaults (`library`, IDs courants, progression)
- UI: `BookReaderView`

#### Workflow bouton "Lire l article" (card culture)

1. Le bouton de la card culture (`card-culture.js`) envoie un message bridge:
- Wikipedia: `type: openArticle`, payload `{ title, lang }`
- Guardian: `type: openGuardianArticle`, payload `{ url, title }`

2. Le bridge JS (`dom-utils.js`) enveloppe le message en format v1:
- `{ v, id, type, payload, ts }`

3. Cote Swift (`InstagramWebView.Coordinator`), `dispatchBridgeAction` route vers:
- `fetchFullArticleAndOpen(...)` (Wikipedia)
- `fetchGuardianFullArticleAndOpen(...)` (Guardian)

4. Une fois le texte recupere, `handleOpenArticle(...)`:
- deduplique dans `library`
- sauvegarde les chapitres (si nouvel article)
- met a jour `savedCardIndex` / `savedBookTitle`
- met a jour `currentArticleId`
- incremente `currentArticleOpenToken`
- active le reader

5. `BookReaderView` recharge l article sur:
- changement de `currentArticleId`
- changement de `currentArticleOpenToken`

Ce token garantit le rechargement meme si le meme article (meme ID) est ouvert
plusieurs fois et evite les races condition du premier clic.

## 5. Persistance

## 5.1 UserDefaults

- `library` (catalogue des livres/articles)
- `currentBookId`
- `currentArticleId`
- `savedCardIndex`
- `savedBookTitle`
- settings app (`ss_*`)

## 5.2 Fichiers Documents

- `Books/<bookId>.json` (chapitres)
- `Books/<bookId>_cover.bin` (cover)

## 6. Tests

- `BookParserEPUBTests.swift`: validation des chapitres via fixtures/manifests
- `GuardianAPITests.swift`: URL, mapping JSON, appels API live
- `ArticleOpenWorkflowTests` (dans `GuardianAPITests.swift`):
  - non-regression sur ouverture article (`currentArticleOpenToken`)
  - non-regression sur `splitIntoChapters` (sections + filtres references)
- `WikipediaArticleButtonWorkflowTests` (dans `GuardianAPITests.swift`):
  - URL Wikipedia correctement construite pour le flux `openArticle`
  - sanitation du lang
  - encodage titre (accents, apostrophes, `&`)
- `WikipediaArticleSelectionTests` (dans `GuardianAPITests.swift`):
  - evite de reservir le meme titre Wikipedia consecutivement quand une alternative existe
- `ArticleFirstClickTimingTests` (dans `GuardianAPITests.swift`):
  - valide le fallback `UserDefaults` -> `BookReaderView` quand `@AppStorage` est encore vide au premier affichage

Destination de test recommandee dans ce repo:
- `platform=iOS Simulator,name=iPhone 17`

## 7. Points de vigilance techniques

1. Cohabitation `currentBookId` vs `currentArticleId`:
- ne jamais ecraser le livre courant quand on ouvre un article.

2. Deduplication article:
- eviter la creation de doublons dans `library` pour le meme article.

3. Bridge JS/Swift:
- privilegier JSON serialization, eviter interpolation string brute pour JS.

4. Performance scan:
- garder des scans legers, eviter observers redondants et mutations inutiles.

5. Diversite des cartes article:
- la selection Wikipedia cote native evite le dernier titre injecte pour limiter les repetitions visibles.

6. Ouverture article (premier clic):
- ordre d execution renforce cote native: ecriture `currentArticleId` / `currentArticleOpenToken` avant presentation du reader
- `BookReaderView` lit l ID article depuis `UserDefaults` au chargement pour eviter une ouverture vide liee a une propagation tardive de `@AppStorage`

7. Dynamic Island XP (natif app):
- affichage SwiftUI overlay dans `InstagramView` (pas injecte dans le DOM Instagram)
- un nouveau message bridge `grantXP` remonte les interactions boutons des cartes injectees
- persistance locale `ss_xp_total` + progression par niveau (100 XP / niveau)
- couverture etendue: tous les boutons des cards injectees (metrics, book, culture, mood, timer, stop, fallback legacy) donnent `+12 XP`
- anti re-trigger: une card ne peut donner l XP qu une seule fois (meme si plusieurs taps sur ses boutons)
- animation organique type "Apple-like": transition asymetrique (scale/offset) + spring d apparition + disparition douce
- mode compact uniquement avec illusion "sort du cutout": ancrage visuel noir adapte notch/dynamic island selon `safeAreaInsets.top`
- ajustement visuel: ancrage place au bord haut de l ecran (overlay `ignoresSafeArea(.top)`) pour eviter l effet de decalage sous la barre Instagram
- mitigation glitch animation: suppression du blur pendant transition + rendu compose (`compositingGroup`) pour limiter le scintillement sur les contours
- compact island reduite (empreinte visuelle plus faible)
- timeline UX en 2 temps: `+XP` rapide, puis ratio `xpCourante / xpNiveau`
- progression bar: l island affiche d abord l etat courant du niveau (sans partir de 0), puis anime uniquement le gain XP jusqu a l etat cible
- demarrage de l animation de barre volontairement retarde pour laisser le temps de lire l etat instantane avant progression

8. Dashboard natif (SwiftUI)
- entree principale depuis la ligne StopScroll injectee dans la section utilisateur Instagram (action bridge `openDashboard`)
- entree secondaire depuis `SettingsView` (bouton "Open Dashboard")
- `DashboardView` affiche 3 blocs persistants: objectifs, usage du jour, progression XP

9. Settings reader (bibliotheque)
- tap direct sur un livre/article pour ouvrir immediatement dans le reader
- swipe gauche natif iOS sur chaque item pour actions rapides: delete, reset, rename

10. Navbar native synchronisee Instagram
- une barre native SwiftUI overlay remplace visuellement la barre Instagram
- synchronisation etat onglet actif -> natif via bridge (`nativeNavState`)
- synchronisation badge messages -> natif via bridge (`messageBadge`)
- navigation natif -> WebView via trigger des boutons Instagram (dispatch events DOM sur les liens de nav)
- sections supportees en V1: home, search, messages, activity, profile
- mapping des onglets verrouille sur la nav bottom d Instagram (heuristiques position + liens tab) pour eviter les collisions avec la topbar (ex: bouton +)
- navigation native anti-reload: interaction simulee prioritairement sur le noeud visuel interne des tabs (pas le lien brut), avec fallback `history.pushState` pour rester en SPA

11. Ajustements UX navbar native
- icone livre restauree dans la barre native (ouvre `BookReaderView` en natif)
- icone dashboard ajoutee dans la barre native avec acces Dashboard + Parametres app
- correction routage profil: priorite au lien avatar/profil Instagram (evite redirection vers edit settings)
- sans injection CSS de masquage: la webview est etendue vers le bas pour sortir la navbar Instagram de la zone visible
- icone coeur retiree de la barre native
- reader: suppression de la bottom bar interne pour eviter une double navigation visuelle

15. Ajustements layout WebView et navbar commune
- overscan bas augmente pour masquer completement la barre Instagram residuelle en bas
- safe area haute conservee; son fond est synchronise avec le theme Instagram detecte (dark/light)
- navbar native commune affichee egalement pendant le mode BookReader

18. Theme padding/loader persistant
- etat theme Instagram persiste localement (`ss_instagram_theme_dark`)
- au demarrage (avant bridge JS), padding haut et loader utilisent la derniere valeur connue
- en runtime, la detection theme met a jour cette valeur et rafraichit l UI

16. Reader alignment avec navbar commune
- reserve d espace basse appliquee au BookReader pour eviter chevauchement visuel avec la navbar native globale

17. Settings row Instagram
- injection JS de la ligne StopScroll dans les parametres Instagram desactivee

12. Strategie 2 WebView (main + messages)
- deux surfaces `WKWebView` sont maintenues: principale (`/`) et messages (`/direct/inbox/`)
- une seule surface est visible/interactable a la fois (activation exclusive)
- la surface inactive passe en mode pause runtime JS (`setPaused(true)`)
- optimisations pause:
  - arret scan periodique
  - blocage scan/injection
  - pause best-effort des videos
- reprise runtime au retour de la surface active (`setPaused(false)`)
- eviction memoire V1: sur memory warning iOS, destruction de la surface inactive puis recreation lazy au prochain switch
- details complets dans `docs/TWO_WEBVIEW_STRATEGY.md`

13. Fiabilisation navigation Search/Profile
- fallback `search` vers `/explore/` si mapping DOM indisponible
- fallback `profile` via pseudo Instagram configure (`ss_instagram_username`)
- commande de navigation renvoyee automatiquement quand une surface active est recreee (post-eviction)

14. Prompt pseudo Instagram pour onglet profil
- si l'utilisateur tape profil sans pseudo configure, une sheet native demande le pseudo
- apres validation, le pseudo est sauvegarde et la navigation profil est relancee
- cette valeur alimente le fallback profile de la nav secondaire
