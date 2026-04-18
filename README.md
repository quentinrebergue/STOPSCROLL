# StopScroll

StopScroll est une application iOS qui transforme Instagram en espace de reprise de controle:
- elle detecte les posts sponsorises/suggeres,
- elle injecte des cartes intentionnelles (mood, timer, stats, culture, lecture),
- elle redirige le bouton Reels vers un lecteur de livre/article,
- elle maintient une progression de lecture persistante.

## Stack

- SwiftUI + WebKit (WKWebView)
- Injection JavaScript modulaire (namespace `window.StopScroll`)
- Parsing EPUB/TXT natif (Swift)
- Tests XCTest (parser EPUB, Guardian API)

## Demarrage rapide

### 1) Ouvrir le projet

- Ouvrir `StopScroll.xcodeproj` dans Xcode
- Scheme: `StopScroll`

### 2) Build

```bash
xcodebuild -project StopScroll.xcodeproj -scheme StopScroll -configuration Debug build
```

### 3) Tests

```bash
xcodebuild -project StopScroll.xcodeproj -scheme StopScroll -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Test cible workflow article:

```bash
xcodebuild -project StopScroll.xcodeproj -scheme StopScroll -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:StopScrollTests/ArticleOpenWorkflowTests test
```

Test cible bouton article Wikipedia:

```bash
xcodebuild -project StopScroll.xcodeproj -scheme StopScroll -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:StopScrollTests/WikipediaArticleButtonWorkflowTests test
```

## Structure du repo

- `StopScroll/App`: point d entree SwiftUI
- `StopScroll/Views`: UI principale (`InstagramView`, `InstagramWebView`, `BookReaderView`, `SettingsView`)
- `StopScroll/Models`: settings, parsing EPUB/TXT, cartes de lecture
- `StopScroll/Scripts`: runtime JS injecte dans Instagram
- `StopScroll/Tests`: tests unitaires
- `project.yml`: spec XcodeGen

## Documentation projet

- `docs/ARCHITECTURE.md`: architecture fonctionnelle et technique
- `docs/ROADMAP.md`: plan de livraison (Now / Next / Later)
- `docs/BACKLOG.md`: issues techniques et pistes d amelioration priorisees

## Regles de contribution internes

1. Toute nouvelle feature doit avoir:
   - un item roadmap,
   - un item backlog (ou la fermeture d un item existant),
   - des criteres d acceptation clairs.
2. Toute regression corrigee doit ajouter:
   - un item de prevention dans le backlog,
   - un test si possible.
3. Eviter les changements larges non lies au sujet (small batches).
4. Pour chaque feature/fix:
   - mettre a jour la documentation pertinente (`README`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/BACKLOG.md`),
   - faire un commit dedie avec un message explicite.
