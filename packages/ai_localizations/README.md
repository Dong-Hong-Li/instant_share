# ai_localizations Integration Guide

[中文版](./README.zh-CN.md)

Lightweight Flutter localization SDK with a Go toolchain: **maintain primary-locale strings → AI translates to target locales → generate ARB and Dart code**.

The primary locale is defined by `source_locale` in `config.yaml` — **not limited to Chinese**. As long as `translations.json` matches `source_locale` and `locales` is configured correctly, any language can be the source.

## Design origins

This package builds on Flutter's official **ARB + gen-l10n** i18n system. It aligns on resource format and integration patterns, with custom extensions for translation and code generation.

| Layer | Inspiration | What we kept | What we changed |
|-------|-------------|--------------|-----------------|
| Resource format | [ICU/Google ARB](https://github.com/google/app-resource-bundle) (Application Resource Bundle) | `.arb` files with `@@locale`, key/value pairs | Primary strings live in `translations.json`; ARB is synced by tools |
| Flutter integration | [Flutter internationalization](https://docs.flutter.dev/ui/internationalization) — `gen-l10n`, `intl`, `flutter_localizations` | Multi-locale ARB, typed string accessors, `LocalizationsDelegate` | No `l10n.yaml` / `flutter gen-l10n`; custom Go + Dart generators |
| Runtime | Official `AppLocalizations` pattern | Load locale data at runtime, expose via extension/getter | `LocalizationsSdk` loads ARB from `assets/translations/` |
| Translation workflow | Manual per-locale ARB editing (official default) | Human-maintained primary locale | AI batch translation for target locales |

---

## Prerequisites: SDK integration

### 1. Add dependency

In your Flutter project `pubspec.yaml`:

```yaml
dependencies:
  ai_localizations:
    path: packages/ai_localizations   # adjust to your path

flutter:
  assets:
    - assets/translations/
```

### 2. Register delegate

Register localizations in `MaterialApp` (see `lib/l10n/app_localizations.dart` in this repo):

```dart
import 'package:flutter_template/l10n/app_localizations.dart';

MaterialApp(
  localizationsDelegates: [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales(),
  // ...
)
```

### 3. Use strings in widgets

```dart
import 'package:flutter_template/core/ui/extension/localizations_extension.dart';

Text(context.l10n.app.home)
```

---

## Step 1: Install Go SDK and dependencies

### 1.1 Install Go

Requires **Go 1.21+** (this repo's `tools/go.mod` uses 1.25.6).

- Official site: https://go.dev/dl/
- macOS (Homebrew): `brew install go`

Verify:

```bash
go version
```

### 1.2 Download Go modules

From your Flutter project root:

```bash
cd packages/ai_localizations/tools
go mod download
```

Running `ailoc.sh` will also fetch dependencies on first run, but downloading ahead of time helps catch network issues early.

---

## Step 2: Create translations.json and add strings

### 2.1 Create source file

Create at your Flutter project root:

```
assets/translations/translations.json
```

### 2.2 File format

Each **key** in `source_data` maps to a **sid** in generated code; each **value** is the **primary locale** string and must match `source_locale` in `config.yaml`:

**When primary locale is Chinese (`source_locale: zh`):**

```json
{
  "source_data": {
    "appstrings_appTitle": "我的应用",
    "appstrings_welcome": "欢迎使用",
    "appstrings_home": "首页"
  }
}
```

**When primary locale is English (`source_locale: en`):**

```json
{
  "source_data": {
    "appstrings_appTitle": "My App",
    "appstrings_welcome": "Welcome",
    "appstrings_home": "Home"
  }
}
```

The tool uses `source_locale` as the source and AI-translates into **all other locales** in `locales`. For example, with `locales: [en, zh, ja]` and `source_locale: en`, it generates `zh` and `ja` ARB files but skips `en`.

### 2.3 Naming conventions

| Rule | Example |
|------|---------|
| Lowercase keys with underscores | `appstrings_setting` |
| Module prefix recommended | `appstrings_`, `basestrings_` |
| Preserve placeholders | `"Hello, {name}"` / `"你好，{name}"` |

### 2.4 Workflow for new strings

1. Add key/value pairs to `source_data` in `translations.json`
2. Run `./ailoc.sh` (see Step 3)
3. Tool updates ARB files and generates `lib/l10n/strings/*.dart`
4. Use in widgets via `context.l10n.app.xxx`

---

## Step 3: Copy config files and script, then run

Copy **two config files** and **one shell script** from `packages/ai_localizations/` to your **Flutter project root**.

### 3.1 Copy config.yaml

```bash
cp packages/ai_localizations/config.yaml.example config.yaml
```

Edit as needed (paths are relative to **Flutter project root**):

```yaml
locales:
  - zh
  - en
  - ja
  - ko

# Primary locale: source_data values in translations.json must use this language
source_locale: zh

arb_dir: assets/translations
source_json_file: assets/translations/translations.json
custom_i18n_output_dir: lib/l10n
diff_file: custom/translations/diff.json
```

If your team uses English as the primary locale, set `source_locale: en` and write English strings in `translations.json`.

| Field | Description |
|-------|-------------|
| `locales` | All supported languages — **must use BCP-47 format** (see table below) |
| `source_locale` | Primary locale (manually maintained); must be in `locales`; `translations.json` values must match |
| `arb_dir` | ARB output directory |
| `source_json_file` | Primary locale source JSON path |
| `custom_i18n_output_dir` | Generated Dart code directory |
| `diff_file` | AI translation cache (optional gitignore) |

#### BCP-47 locale format (required)

`locales` and `source_locale` must follow [BCP-47 / RFC 5646](https://www.rfc-editor.org/rfc/rfc5646) language tags, separated by **hyphens `-`**. Underscores `_` are not allowed:

| Format | Examples | ARB filename |
|--------|----------|--------------|
| Language only (ISO 639-1) | `zh`, `en`, `ja` | `app_zh.arb` |
| Language + region (ISO 3166-1) | `en-US`, `pt-BR` | `app_en_US.arb` |
| Language + script + region | `zh-Hans-CN`, `zh-Hant-HK` | `app_zh_Hant_HK.arb` |

> **config vs ARB naming**: `config.yaml` uses BCP-47 **hyphens** (`zh-Hant-HK`). ARB filenames and `@@locale` follow Flutter conventions with **underscores** (`app_zh_Hant_HK.arb`, `"@@locale": "zh_Hant_HK"`). The toolchain converts automatically.

Rules:

- **Language**: 2–3 lowercase letters, e.g. `zh`, `en`
- **Script** (optional): 4-letter ISO 15924, title case, e.g. `Hans`, `Hant`
- **Region** (optional): 2 uppercase letters, e.g. `CN`, `HK`, `US`
- **Invalid**: `zh_Hant_HK` (underscores), `zh-hant-hk` (wrong casing)

The toolchain validates locale tags when loading `config.yaml`; invalid values fail fast.

### 3.2 Copy .env

```bash
cp packages/ai_localizations/.env.example .env
```

Fill in at least `AILOC_CONFIG` and **AI settings** (use any provider — not tied to a specific vendor):

```bash
# Relative to ai_localizations package root, pointing to project-root config.yaml
AILOC_CONFIG=../../config.yaml

# OpenAI-compatible API (required)
AILOC_AI_PROVIDER=your_provider    # e.g. openai / deepseek / moonshot
AILOC_API_KEY=your_api_key
AILOC_BASE_URL=your_api_base_url   # must support /chat/completions
AILOC_MODEL=your_model
AILOC_TEMPERATURE=0.2              # adjust per model docs
```

The tool calls `{AILOC_BASE_URL}/chat/completions`, so **any OpenAI-compatible** Chat Completions API works.

**Example configurations (pick one):**

| Provider | `AILOC_BASE_URL` | Example `AILOC_MODEL` |
|----------|------------------|-----------------------|
| OpenAI | `https://api.openai.com/v1` | `gpt-4o-mini` |
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Moonshot / Kimi (China) | `https://api.moonshot.cn/v1` | `kimi-k2.6` |

More examples are in the commented block of `packages/ai_localizations/.env.example`.

> `.env` contains secrets — do not commit it. The script auto-creates a symlink at `packages/ai_localizations/.env` pointing to the project-root `.env`.

### 3.3 Copy and run ailoc.sh

```bash
cp packages/ai_localizations/ailoc.sh .
chmod +x ailoc.sh
./ailoc.sh
```

### 3.4 Pipeline output

`ailoc.sh` runs four steps. Terminal output looks like this:

#### Step 1: Sync ARB

Checks or creates ARB files (e.g. `app_zh_Hant_HK.arb`) for each locale. On first run, creates ARB files with only `@@locale`.

![Step 1: Check and create ARB files](image/1.png)

#### Step 2: Diff collection

Compares `translations.json` (primary locale) against target-locale ARB files and lists keys needing translation.

![Step 2: Compare translations.json with ARB](image/2.png)

#### Step 3: AI translation

Translates from `source_locale` into all other `locales` in batches; writes results to `custom/translations/diff.json`.

![Step 3: AI batch translation](image/3.png)

#### Step 4: Code generation

Writes back ARB files and generates `lib/l10n/strings/*.dart`, `app_localizations.dart`, and related Dart files.

![Step 4: Generate Dart code](image/4.png)

Run `flutter analyze` afterward to confirm no errors.

---

## Directory layout

After integration, your Flutter project should look like:

```
flutter_project/
├── ailoc.sh                          # copied from packages/ai_localizations
├── config.yaml                       # copied from config.yaml.example
├── .env                              # copied from .env.example (do not commit)
├── assets/translations/
│   ├── translations.json             # manually maintained primary-locale strings
│   ├── app_zh.arb                    # tool-generated
│   ├── app_en.arb
│   └── ...
├── custom/translations/
│   └── diff.json                     # AI translation cache (optional gitignore)
├── lib/l10n/
│   ├── app_localizations.dart        # delegate (hand-written / from template)
│   └── strings/                      # tool-generated
└── packages/ai_localizations/        # SDK + Go toolchain
```

---

## Example project

Runnable demo with **pre-built BCP-47 locales (zh-Hans-CN / zh-Hant-HK / en-US / ja / ko) — no API key required**:

```bash
cd packages/ai_localizations/example
flutter pub get
flutter run
```

See [example/README.md](./example/README.md).

## Related files

| File | Purpose |
|------|---------|
| `example/` | Complete demo app (pre-translated ARB + locale switcher) |
| `config.yaml.example` | Project paths and locale config template |
| `.env.example` | AI and environment variable template |
| `ailoc.sh` | One-command Go toolchain launcher |
| `tools/cmd/main.go` | Four-step pipeline entry point |
| `tools/dart/generate.dart` | Dart-only code generation |
