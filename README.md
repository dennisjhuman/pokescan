# PokéScan

Scan a Pokémon card with your phone, see roughly what it is worth, check it
against the official artwork, and keep it in a local collection.

**Web app:** https://dennisjhuman.github.io/pokescan/
Open it on a phone and use *Add to Home Screen* to get an app icon.

Personal project. No accounts, no server, no paid APIs. Card data and prices
come from the free [TCGdex](https://tcgdex.dev) API.

## What it does

- **Look up a card** by the number printed on it (`020` / `189`), plus the
  three-letter set code on newer cards. Set codes are resolved offline from a
  bundled index of every set.
- **Prices** from Cardmarket in EUR and TCGplayer in USD, per variant, with a
  badge when a card has moved more than 10% since the last refresh.
- **Collection** grouped by set, searchable and sortable, with a running total.
  Export to CSV at any time.
- **Things to check** — never a verdict on whether a card is fake. It compares
  what the scan read against TCGdex, flags mismatched HP, attack names and
  card numbers, and puts your scan side by side with the official image.
- **Scanning** with on-device OCR, so identifying a card costs nothing and
  works without a connection to anything but TCGdex.

## Where it runs

| | Collection, lookup, prices | Camera scanning |
|---|---|---|
| Web (any phone or desktop) | Yes | No — falls back to typing the number |
| iOS / Android app | Yes | Yes |

Scanning needs Google ML Kit, which is mobile only, so the web build swaps the
camera for the manual entry form. Everything else is the same code.

Collection data is stored on the device and never leaves it. That also means it
is not backed up anywhere, so use the CSV export if you would miss it.

## Building it

```bash
flutter pub get
flutter test
flutter run            # attached device
tool/dev_web.sh        # web, on http://localhost:8787
```

Pushing to `main` builds and deploys the web app automatically.

The bundled set index is generated, not hand-written. Regenerate it when new
sets are released:

```bash
dart run tool/gen_set_index.dart
```

See `CLAUDE.md` for the design decisions, the API quirks worth knowing, and
what is still unfinished.
