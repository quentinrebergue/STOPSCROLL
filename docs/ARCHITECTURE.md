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
- pilote des interactions (timer, open article, open settings)

## 2. Flux principal

1. L app charge Instagram dans `InstagramWebView`.
2. Swift injecte les modules JS (`modules/*`, puis `block_reels.js`).
3. Le runtime scanne les posts (`runtime-scan`, `tracking`, `ad-detection`).
4. Quand une opportunite est validee, une carte est construite (`card-builder/*`) puis injectee.
5. Les actions utilisateur passent par le bridge `stopScrollBridge`.
6. Swift traite l action (ex: fetch article, open reader) puis reinjecte les donnees vers JS.

## 3. Bridge natif <-> web

### JS -> Swift

- Handler `openBookReader`: ouvre le lecteur
- Handler `stopScrollBridge`: messages structures (`openArticle`, `fetchGuardianArticle`, `setTimer`, `openSettings`, etc.)

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

## 4. Sous-systemes importants

### 4.1 Injection feed

- Detection:
  - `modules/ad-detection.js`
  - labels sponsorises + heuristiques follow/suggested
- Choix carte:
  - `modules/card-logic.js` (weighted random + anti-repetition)
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
- met a jour `currentArticleId` puis active le reader

5. Pour garantir le rechargement meme si c est le meme article (meme ID),
`currentArticleId` est force en deux etapes (`""` puis `bookId`) uniquement
si on rouvre le meme article. Si c est un nouvel article, `bookId` est pose
directement avant `showingReader = true` pour eviter le bug du premier clic.

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

## 7. Points de vigilance techniques

1. Cohabitation `currentBookId` vs `currentArticleId`:
- ne jamais ecraser le livre courant quand on ouvre un article.

2. Deduplication article:
- eviter la creation de doublons dans `library` pour le meme article.

3. Bridge JS/Swift:
- privilegier JSON serialization, eviter interpolation string brute pour JS.

4. Performance scan:
- garder des scans legers, eviter observers redondants et mutations inutiles.
