# PokéScan — personal Pokémon card collection app

Personal-use mobile app: scan a Pokémon card with the phone camera, identify it,
show a rough market value, flag likely fakes, and store it in a local collection.
Zero recurring cost is a hard constraint. No grading. No accounts. No backend
unless explicitly added later.

## Decisions already made (don't relitigate without asking)

| Area | Choice | Why |
|---|---|---|
| Framework | Flutter (Dart) | One codebase, iOS + Android, ML Kit plugin exists |
| Card data + prices | TCGdex REST API (`https://api.tcgdex.net/v2/{lang}/...`) | Free, no key, pricing embedded in card response (Cardmarket EUR + TCGplayer USD) |
| Identification | On-device OCR (Google ML Kit text recognition) → lookup in TCGdex | No per-scan API cost |
| Storage | SQLite via `drift` (or `sqflite`) | Offline-first, personal device |
| Currency | USD (TCGplayer) primary, EUR (Cardmarket) secondary | TCGplayer prices per variant; Cardmarket is one blob per card, so it misreads reverse/holo. Changed 2026-09-20. |
| Fake detection | Heuristic warnings + side-by-side reference image | No reliable fake API exists; never present a verdict, only signals |
| Grading | Out of scope | Deliberately dropped |

Verify TCGdex endpoint shapes against https://tcgdex.dev before coding — the
notes below are from memory and may be slightly off.

## Status (updated 2026-09-15)

| Phase | State |
|---|---|
| 1 Skeleton + manual lookup | Done, verified in browser |
| 2 Local collection | Done, verified in browser (drift on IndexedDB) |
| 3 Camera + OCR | Code complete, **OCR accuracy still unverified** — needs the physical iPhone; see below |
| 4 Fake signals | Done, except the counterfeit done-when needs a real fake card |
| 5 Polish | CSV export and price-change badge done; Japanese support not started |
| 6 Findability | Single-box finder, candidate artwork, set browser — done 2026-09-20, verified in browser |
| Shipping | Web live; iOS installed on the iPhone; signed Android APK builds |
| Shipping | Web app live and installable; iOS build for scanning only |

### Shipping (decided 2026-09-16)

Two targets, same code:

- **Web app — https://dennisjhuman.github.io/pokescan/** — the one people
  actually use. Add to Home Screen gives an icon and a chrome-less launch. No
  signing, no expiry, no install dance, works on any device. Deployed by
  GitHub Actions on every push to `main`, which runs `flutter analyze` and the
  test suite first. Repo is public because Pages on a free account requires it.
- **Android build** — added 2026-09-20, and the easiest of the three. ML Kit
  has real arm64 support here, so unlike iOS the emulator works and there is
  no 7-day signing expiry: an APK installs and stays until it is uninstalled.
  `flutter build apk --release --split-per-abi` and hand over
  `app-arm64-v8a-release.apk` (~36 MB; the universal APK is 94 MB for no
  reason). Install with `adb install -r <apk>`, or just send the file and let
  the phone's own installer handle it.
- **iOS build** — kept for camera scanning only, since ML Kit is mobile-only.
  Signed with a free personal team, so it stops launching after 7 days and
  needs a reinstall (`flutter build ios --release`, then
  `xcrun devicectl device install app --device <udid> build/ios/iphoneos/Runner.app`).

The Scan tab falls back to manual entry on web via a conditional import, since
ML Kit is mobile-only and the cropper needs `dart:io`.

### Android toolchain (set up 2026-09-20)

No Android Studio. Command-line tools only, which is enough to build and to
run an emulator, and avoids a 1.2 GB IDE for a project that does not need one:

```
brew install openjdk@17                       # formula, not the cask: no sudo
brew install --cask android-commandlinetools
sdkmanager --sdk_root=~/Library/Android/sdk \
  "platform-tools" "platforms;android-36" "build-tools;36.0.0" "cmdline-tools;latest"
flutter config --android-sdk ~/Library/Android/sdk --jdk-dir /opt/homebrew/opt/openjdk@17
```

`cmdline-tools;latest` has to be installed *into the SDK root* even though the
cask already provides a copy elsewhere — `flutter doctor` looks for it there
specifically and reports the toolchain as broken otherwise.

Release signing: keystore at `~/.pokescan/pokescan-release.jks`, credentials in
`android/key.properties`. Both are gitignored, and `build.gradle.kts` falls
back to the debug key when `key.properties` is missing so a fresh clone still
builds. The keystore is not backed up anywhere — losing it does not break
anything already installed, but a later build could no longer *update* an
install, which would need an uninstall first.

R8 needs `android/app/proguard-rules.pro`: the ML Kit plugin names all five
script recognizers, we bundle only Latin, and the release build fails on the
four missing classes until they are `-dontwarn`ed.

Storage is local on every platform and is never sent anywhere. On web that is
IndexedDB, and the app requests persistent storage at startup so Safari does
not evict the collection. CSV export is the only backup.

Dev loop is `.claude/launch.json` → `web`, which runs `tool/dev_web.sh`.

Xcode 27.0 licence accepted and first-launch components installed on
2026-09-15, so the full toolchain works again. `tool/dev_web.sh` keeps a
fallback to the Command Line Tools for the next time an Xcode update re-arms
the licence gate — when that happens, *every* flutter command exits 69,
including `flutter build web`, and the fix is `sudo xcodebuild -license`.

### The iOS simulator cannot run this app (verified 2026-09-15)

ML Kit ships no arm64 simulator slice. On Apple Silicon, Xcode resolves that by
building the whole app x86_64-only, and iOS 26+ simulators dropped x86_64, so
the install fails with "This app needs to be updated by the developer to work on
this version of iOS". It is not just OCR that is unavailable — the app will not
launch in a simulator at all.

So iOS testing means a physical device. That needs signing configured in Xcode
(Apple ID → Personal Team on the Runner target), which needs the user. A free
personal team signs for 7 days at a time.

Build commands that do work without a device:
- `flutter build ios --debug --no-codesign` — proves the native side compiles.
- `tool/dev_web.sh` — the web loop, for anything that is not camera or OCR.

## Build order (phases — finish and run each before starting the next)

### Phase 1 — Skeleton + manual lookup (no camera yet)
- Flutter project, three tabs: **Scan**, **Collection**, **Card detail**.
- `TcgdexClient`: `getCard(id)`, `getSet(id)`, `searchCards(name, setId?)`.
- Manual entry form: type set code + card number → fetch card → show detail page.
- Card detail page: image, name, set, rarity, number, prices (EUR trend/avg/low, USD market/low/mid/high), variant selector.
- Done when: typing `swsh3` + `20` shows Charizard VMAX with prices. (`swsh3-136` is Furret — verified 2026-09-14.)

### Phase 2 — Local collection
- Drift schema (see Data model). Add / edit / delete from card detail.
- Collection list: grouped by set, sortable by value, search box.
- Collection total value (sum of chosen-variant price × quantity).
- Cache every fetched card JSON locally with a `fetched_at` timestamp; refresh prices only on pull-to-refresh or if older than 7 days.
- Done when: collection survives app restart and total value is correct.

### Phase 3 — Camera + OCR identification
- Camera screen with a card-shaped guide overlay (63 × 88 mm aspect, ~0.716).
- Capture → crop to guide → ML Kit text recognition.
- Parse strategy (in order, stop on first confident match):
  1. Regex for card number `(\d{1,3})\s*/\s*(\d{1,3})` in bottom-left/right region → set total narrows candidate sets; combine with any detected set code or name.
  2. Card name from largest text block near the top.
  3. Fall back to name search in TCGdex and let the user pick from a list.
- Always show "Not this card?" → manual entry.
- Done when: a modern English card identifies correctly in ≥ 8/10 tries under normal room light.
- **Not yet measured.** Parser is unit-tested against synthetic OCR fixtures
  (`test/card_text_parser_test.dart`); the 8/10 bar needs real photos on a real
  device. Expect the band constants (`_topBand`, `_bottomBand`) and the OCR
  digit fixups to need tuning once real ML Kit output is in hand.

### Phase 4 — Fake signals
Show a **"Things to check"** panel on the detail page, never a "FAKE" label.
- **Reference compare**: scan crop side-by-side with TCGdex official image, pinch-zoomable. Prompt list: font weight, border thickness, colour saturation, holo pattern, set symbol, energy symbols.
- **Text mismatch**: OCR'd HP and attack names vs TCGdex data. Mismatches → warning (fakes often have typos / wrong values).
- **Number sanity**: card number > set total, or number not in set → warning.
- **Set sanity**: name exists but not in the set implied by the number → warning.
- **Optional, soft**: average colour / saturation delta between scan and reference beyond a threshold → "colour looks off — check under daylight". Keep this low-confidence; phone lighting varies.
- Done when: a known counterfeit with wrong text triggers at least one warning.
- Covered by unit tests (`test/fake_signals_test.dart`) including a typo'd
  attack name and a wrong HP. Still worth running a real counterfeit through
  the camera when one is to hand.
- Mismatch thresholds are deliberately loose (0.6 similarity) so OCR noise
  does not manufacture warnings. Tighten only with real scans as evidence.
- The colour check needs the official image's bytes. An earlier note here said
  the TCGdex asset host blocks cross-origin reads — that was wrong. Verified
  2026-09-16: `assets.tcgdex.net` returns `access-control-allow-origin: *` on
  valid paths. The CORS error seen during development came from a **404** (a
  wrong set-symbol URL); error responses carry no CORS headers, which the
  browser reports as a CORS failure. Valid card images fetch fine on web, so
  the colour check should work there too.

### Phase 6 — Findability (added 2026-09-20, after testing with real cards)

The three-field number / total / set-code form asked the user to know which of
the things printed on the card was the set code. On a real card that is anyone's
guess. Six cards in hand, six different bottom edges:

| Printed | What it is |
|---|---|
| `E 123/203` | `E` is the **regulation mark**, not a set. Total → Evolving Skies. |
| `PAR EN 185/182` | `PAR` is a real set code, `EN` the language. 185 > 182 = secret rare. |
| `SVP EN 194 ★` | Promo. No total at all. |
| `SWSH153` | Promo, code glued to the number. |
| `M6 058/076 RR` | Japanese. `RR` is a rarity. |
| `swsh3-20` | A TCGdex id. |

What changed:

- **One search box.** `data/tcgdex/card_query.dart` (pure Dart, heavily
  unit-tested against all six of the above) reads number, total, set code,
  regulation mark, rarity code and language out of whatever gets typed.
  `card_text_parser.dart` now delegates to it, so a number read by OCR and a
  number typed by hand resolve identically.
- **Pick by artwork, not by set symbol.** When a number fits several sets, the
  candidate cards are fetched and shown as big images. "Which of these pictures
  is the card in your hand?" is answerable; "which 3 mm monochrome symbol is
  this?" is not. `features/scan/card_results.dart`.
- **Name results are grouped by set, newest first.** The set is derived offline
  from the id prefix (`SetResolver.setForCardId`), so a "Pikachu" search is
  labelled sections rather than a wall of 150 identical rows.
- **Thumbnails are card-shaped and ~190 px** (`shared/widgets/card_thumb.dart`),
  with a real "no artwork" tile carrying the name and number — TCGdex genuinely
  has no image for a lot of older promos, and the old 40 px broken-image icon
  told the user nothing.
- **Browse by set** (`features/scan/set_browser.dart`): search sets by name,
  year or code, see the logo at a legible size, then pick out of the set's grid.
  The escape hatch for an unreadable number.
- **Dead ends explain themselves.** An unknown code says so and offers near
  misses (`SetResolver.didYouMean`); a number above the set size is named as a
  secret rare rather than looking like an error.
- **Japanese is detected, not attempted.** Kana/kanji, or an unrecognised code
  shaped like a Japanese set id (`M6`, `SV1a`), shows a notice. Lookup stays
  English-only — see the open question below.
- Search is debounced as you type (450 ms), because Enter is not reliable on
  Flutter web.

Done when: all six cards above resolve from their printed bottom edge. They do.

### Phase 5 — Polish (only if still enjoying it)
- Export collection to CSV.
- Price-change badge on cards whose trend moved >10 % since last refresh.
  Done. `cards_cache` keeps one step of history (schema v2) rather than a
  history table; `PriceChange.between` compares the chosen variant and refuses
  to compare across currencies, so a Cardmarket-to-TCGplayer fallback does not
  read as a huge move.
- Japanese card support: switch `{lang}` to `ja` in TCGdex calls; OCR with ML Kit Japanese model.
  **Blocked on a decision, not on effort.** `GET /v2/ja/cards/M6-058` works fine
  and is priced, but Japanese set ids collide with English ones — JP `SV10` is
  ロケット団の栄光, EN `sv10` is Destined Rivals, and the cache lowercases its
  keys. So `lang` has to become part of the card id everywhere: cache key,
  route, `collection_items.card_id`, CSV export, fake signals. Until then the
  finder detects Japanese cards and says so rather than returning the wrong
  English card. Two of the six test cards are Japanese, so this is the next
  real chunk of work.

## Folder structure

```
lib/
  main.dart
  app.dart                     # routes, theme
  core/
    theme.dart
    constants.dart             # base URL, cache TTL, card aspect ratio
  data/
    tcgdex/
      tcgdex_client.dart       # HTTP calls
      tcgdex_models.dart       # Card, Set, Pricing (json_serializable)
      card_query.dart          # typed/OCR'd text → number, total, set code
      set_resolver.dart        # printed code/total → set ids, offline
    db/
      database.dart            # drift database + tables
      collection_dao.dart
      card_cache_dao.dart
    repositories/
      card_repository.dart     # cache-first: db → network
      collection_repository.dart
  features/
    scan/
      scan_screen.dart
      card_guide_overlay.dart
      ocr_service.dart         # ML Kit wrapper
      card_text_parser.dart    # OCR lines → CardQuery → candidate ids
      find_card_view.dart      # the one search box
      card_results.dart        # candidate grid + name results grouped by set
      set_browser.dart         # browse sets by logo, then pick out of the grid
    card_detail/
      card_detail_screen.dart
      price_panel.dart
      variant_picker.dart
      fake_signals_panel.dart
      reference_compare_view.dart
    collection/
      collection_screen.dart
      collection_summary.dart
  shared/
    widgets/
    utils/
test/
  card_query_test.dart         # the six real cards; test this heavily
  card_text_parser_test.dart   # pure-Dart, test this heavily
  tcgdex_models_test.dart
```

## Data model (drift)

```
cards_cache                    -- schema v2
  id                  TEXT PK  -- TCGdex card id, e.g. "swsh3-136"
  json                TEXT     -- raw card response
  fetched_at          INTEGER  -- epoch ms
  previous_json       TEXT ?   -- the response this row replaced
  previous_fetched_at INTEGER ?-- when that one was fetched

collection_items
  id            INTEGER PK autoincrement
  card_id       TEXT FK -> cards_cache.id
  variant       TEXT           -- normal | holo | reverse | firstEdition | wPromo
  quantity      INTEGER default 1
  condition     TEXT           -- NM | LP | MP | HP | DMG (self-assessed)
  language      TEXT default 'en'
  scan_path     TEXT nullable  -- local file path of the capture
  notes         TEXT nullable
  acquired_at   INTEGER nullable
  price_paid    REAL nullable
  added_at      INTEGER
```

Card value = price for `variant` from cached pricing: TCGplayer `marketPrice`
for that variant, then its `midPrice` / `lowPrice`, then Cardmarket
`trend` → `avg` → `low`. Store nothing computed; derive at read time.

TCGplayer leads because it quotes **per variant** — a reverse holo and a plain
copy of the same card get their own numbers. Cardmarket quotes one blob per
card (only the hyphenated `-holo` twins split it at all), so a reverse holo
read as the price of the common non-holo, which is what made the euro figure
look wrong. Anything that is not a real market price for the exact variant is
flagged `Price.estimate` and labelled as such in the UI. The collection total
is `usdTotal`, with anything TCGplayer does not list kept separate as
`eurOnlyTotal` — never converted, since there is no rate here.

## TCGdex notes (verify)

- Base: `https://api.tcgdex.net/v2/en`
- `GET /cards/{id}` → full card incl. `pricing.cardmarket` and `pricing.tcgplayer`
- `GET /sets` and `GET /sets/{id}` → set list / set with card ids
- `GET /cards?name={name}` → brief list (id, name, image); filters supported
- Card id = `{setId}-{localId}`
- Images are returned as a base URL; append quality + extension
  (e.g. `/high.webp`) — check docs for exact format.
- No key, no published rate limit. Be polite: cache aggressively, never poll.
- Verified 2026-09-14 against live API:
  - `pricing.cardmarket`: `unit`, `updated`, `idProduct`, `avg`, `low`, `trend`,
    `avg1`, `avg7`, `avg30`, plus hyphenated holo twins `avg-holo`, `low-holo`,
    `trend-holo`, `avg1-holo`… Any may be `null`. No reverse-specific fields.
  - `pricing.tcgplayer`: `unit`, `updated`, then one object per variant keyed
    `normal`, `holofoil`, `reverse-holofoil`, `1st-edition`… each with
    `lowPrice`, `midPrice`, `highPrice`, `marketPrice`, `directLowPrice`.
    Whole `tcgplayer` object can be `null`.
  - `localId` is a string. `variants` = `{normal, holo, reverse, firstEdition, wPromo}` bools.
  - **Zero padding is per set.** `swsh3-20` but `swsh9-020`, `sv04-042`, `svp-012`,
    `me01-005`, `swsh9tg-TG01`. Everything from Brilliant Stars (2022-02) on is
    padded; older main sets are not; promos mostly are. Bundled set index carries
    a `zeroPadded` flag detected from each set's card list — always build ids via
    `SetInfo.cardIdFor(printedNumber)`, never by hand. Regenerate with
    `dart run tool/gen_set_index.dart` when new sets release.
  - `image` is base URL; append `/high.webp`, `/low.webp`, or `/high.png`.
  - `?name=` is substring match; `&set.id=swsh3` narrows. Brief list = `{id, localId, name, image?}`.
  - 404 returns JSON `{type, title, status: 404, endpoint, method}`.
  - **Flaky:** same card fetched 5× in a row returned `pricing.tcgplayer: null`
    2/5 times (different backend nodes). Occasional empty/non-JSON responses
    and 503s on `assets.tcgdex.net` too. Phase 2 rule: when refreshing a cached
    card, keep the old `cardmarket`/`tcgplayer` block if the new one is null.
    Retry once on empty body.

## Packages (expected)

`http` or `dio`, `json_annotation` + `json_serializable`, `drift` +
`sqlite3_flutter_libs`, `camera`, `google_mlkit_text_recognition`,
`image` (cropping), `cached_network_image`, `go_router`, `riverpod` (state).

## Conventions

- Cache-first everywhere; the app must be usable offline for anything already fetched.
- No API keys, no `.env`, nothing to leak.
- Parser logic lives in pure Dart with unit tests; UI stays thin.
- Errors surface as a small banner, never a blocking dialog.
- Fake signals are always phrased as questions or "check X", never as conclusions.

## Non-goals

Grading, accounts/sync, selling/marketplace integration, push notifications,
any paid API, sports cards / other TCGs.

## Open questions for later

- iOS-only shortcut? If it only ever runs on one iPhone, Swift + Vision + the
  TCGdex Swift SDK would be leaner. Flutter chosen for optionality.
- How to handle pre-2011 cards with no set-total on the card number.
- Whether to keep captured images (storage) or just the derived data.
