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
| Currency | EUR (Cardmarket) primary, USD secondary | Denmark-based |
| Fake detection | Heuristic warnings + side-by-side reference image | No reliable fake API exists; never present a verdict, only signals |
| Grading | Out of scope | Deliberately dropped |

Verify TCGdex endpoint shapes against https://tcgdex.dev before coding — the
notes below are from memory and may be slightly off.

## Status (updated 2026-09-15)

| Phase | State |
|---|---|
| 1 Skeleton + manual lookup | Done, verified in browser |
| 2 Local collection | Done, verified in browser (drift on IndexedDB) |
| 3 Camera + OCR | Code complete, **unverified on device** — needs an iOS sim or phone |
| 4 Fake signals | Not started |
| 5 Polish | Not started |

Dev loop right now is Flutter web (`.claude/launch.json` → `web`), because Xcode
first-run components are not installed (`sudo xcodebuild -runFirstLaunch` needs
a password). The Scan tab falls back to manual entry on web via a conditional
import, since ML Kit is mobile-only and the cropper needs `dart:io`.

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

### Phase 5 — Polish (only if still enjoying it)
- Export collection to CSV.
- Price-change badge on cards whose trend moved >10 % since last refresh.
- Japanese card support: switch `{lang}` to `ja` in TCGdex calls; OCR with ML Kit Japanese model.

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
      card_text_parser.dart    # regex / heuristics → candidate ids
      manual_entry_sheet.dart
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
  card_text_parser_test.dart   # pure-Dart, test this heavily
  tcgdex_models_test.dart
```

## Data model (drift)

```
cards_cache
  id            TEXT PK        -- TCGdex card id, e.g. "swsh3-136"
  json          TEXT           -- raw card response
  fetched_at    INTEGER        -- epoch ms

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

Card value = price for `variant` from cached pricing (Cardmarket `trend`
preferred, fall back to `avg`, then TCGplayer `market`). Store nothing
computed; derive at read time.

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
