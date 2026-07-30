# AGENTS.md

Working notes for AI agents on Lemonade Launcher. Read this before touching anything.

Lemonade Launcher is an Android TV launcher written in Flutter/Dart, forked from Arc Launcher
(which descends from LTvLauncher and FLauncher). `docs/PRD.md` is the source of truth for product
decisions and is kept current — read the relevant section before proposing a change, and update it
when a decision changes.

## The single most important fact

**This launcher is the device's only home screen.** On the reference device the native launcher is
disabled via ADB. If the app fails to start, the television has no home screen and recovering it
needs a computer and a cable.

That is why, throughout this codebase:

- Nothing kills the process. No `exit()`, no `SystemNavigator.pop()`.
- A database that cannot be opened is the worst possible bug. Migrations get literal SQL and tests.
- Native code returns `false` rather than throwing across the platform channel.
- An unhandled section type is skipped deliberately rather than falling through to a cast.

## Environment

`flutter` and `dart` are **not** on the PATH. They are pinned by `mise.toml` in the repo (Flutter
3.41.9, Temurin JDK 21). Every command needs the activation prefix:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && flutter test
```

Codegen (Drift tables and mockito mocks):

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && dart run build_runner build --delete-conflicting-outputs
```

Localizations are driven by `l10n.yaml`:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && flutter gen-l10n
```

**Building an APK requires a flavour** — the `store` dimension (`play` / `github`) is mandatory:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && flutter build apk --debug --flavor github
```

Debug builds carry `applicationIdSuffix '.debug'`, so they install as `com.omeda.arc.debug`, a
separate app that does not replace a working launcher. That is the safe way to test on a real box.

## Definition of done

Both of these, actually run, with their real output reported:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && flutter analyze
eval "$(/opt/homebrew/bin/mise env -s bash)" && flutter test
```

`flutter analyze` must report **0 errors**. There is a standing count of pre-existing
`deprecated_member_use` infos in tests; adding to it needs a reason, and never a new error.
`flutter test` must have **0 failing**.

Never weaken or delete an assertion to make a suite pass. If something cannot be made to work, say
so plainly instead.

## Conventions

- **Generated artifacts are in English**: code, identifiers, comments, doc comments, test names,
  commit messages. The exceptions are `lib/l10n/app_es.arb` (Spanish values) and `docs/PRD.md`
  (written in Spanish, the project's own convention).
- **Conventional commits**, and never an AI attribution or `Co-Authored-By` trailer.
- The app's default locale is **es-ES**. Every user-visible string lives in **both** `.arb` files at
  exact key parity.
- Comments explain **why**, not what. The codebase is dense with rationale for decisions that look
  arbitrary; keep that up rather than stripping it.

## Architecture

- `lib/flauncher.dart` — the home screen: sections, dock, wallpaper layers.
- `lib/providers/` — `ChangeNotifier` services registered in a `MultiProvider` inside
  `LauncherRoot` (`lib/main.dart`). Order matters: `ScenesService` before `SettingsService`, which
  composes the active scene's overrides into its own getters.
- `lib/database.dart` — Drift/SQLite: apps, categories, memberships, spacers, content shortcuts.
- `lib/widgets/settings/` — one page per settings screen, routed from `settings_panel.dart`.
- `android/app/src/main/java/com/leanbitlab/ltvL/` — the **live** native code, all of it declaring
  `package com.omeda.arc`, matching gradle's namespace. The directory name not matching the package
  is confusing but harmless.

`ConfigurationReloader` rebuilds the whole provider tree in place (a generation counter keying the
`MultiProvider`). It exists because a backup restore replaces the store underneath services that
read it once, at construction. Restarting the process is not an option here.

## Traps — all of these have caused or nearly caused a real bug

**Never translate the category names** `'All Apps'` and `'Favorites'`. They are compared by equality
against stored data and inside a database migration, and the dock finds its row by literally
searching for `'Favorites'`. Translating them empties the dock in silence.

**`shared_preferences` getters are hard casts.** A value of the wrong type under a key throws
`TypeError`. Stored values are **untrusted input** — the backup feature imports user-supplied JSON
straight into the store. Guard every read.

**Flutter's `ImageCache` keys on path plus scale, not on contents.** Wallpaper files and shortcut
artwork have stable names, so overwriting one paints the old image from cache. Wallpaper save paths
carry a `force` contract; shortcut artwork uses the bytes as the cache identity.

**`CachedBlurBackdrop` snapshots are screen-sized**, not widget-sized, and shared by reference count
across consumers keyed on `(revision, gradient id, sigma, size, dpr)`. Reusing an existing sigma is
free; introducing a **new** sigma allocates another full-screen image.

**`GridView` and `ListView` build children lazily**, so `autofocus` on an item below the fold fails
silently. And `autofocus` only fires when nothing in the scope holds focus — a list that appears
*because* a text field was submitted needs an explicit `focusNode` and `requestFocus`.

**The hidden top bar is reached by a programmatic intent**, not by directional traversal, and that
works at zero height. Never make its reachability depend on geometry, or a collapsed bar traps the
user with no way into Settings.

**Migrations are stepped and gated on both `from` and `to`**, with literal SQL pinned to the schema
as it was at that version — never the live Dart tables. `test/generated_migrations/` holds snapshots
for v1–v5 and the current version only; v6–v9 cannot be reconstructed honestly and are not covered
as starting points.

**mockito mocks use `throwOnMissingStub`.** Every non-void member a test touches needs a stub, and
adding a member to a mocked service breaks every test file that renders it. Changing a signature
means regenerating `test/mocks.mocks.dart`.

**Test files run in parallel.** Any test pointing a directory somewhere needs its own unique path.

**Tests run in `en_US`** and assert the English `.arb` values.

**`dart:io` futures do not advance inside the fake-async zone `testWidgets` runs in.** A
`pumpAndSettle` over real filesystem or socket work deadlocks. Inject a seam.

**No spinners.** An indeterminate progress indicator never stops scheduling frames and hangs every
`pumpAndSettle`. Use a static line of text.

**Do not bump the scenes payload version without need.** The decoder rejects a version it does not
know and falls back to defaults, so installing an older APK would silently erase every scene.

## Licence

GPLv3, inherited. The About dialog and `aboutLegalese` name the upstream projects this forked from:
that is a **licence obligation**, not decoration. Add authorship above it, never in its place. The
same obligation is why distributing binaries requires the source to be available.

## Verifying on a real device

Wireless ADB on Android 11+ needs pairing first, from a **different port** than the connect one:

```shell
adb pair <ip>:<pairing-port> <6-digit-code>   # code expires when the dialog closes
adb connect <ip>:<connect-port>
```

After pairing there are usually **two transports** to the same device (the explicit one and an mDNS
one), so every command needs `-s <ip>:<port>` or it fails with "more than one device".

Pushing a file to `/sdcard` does **not** index it in MediaStore, so a pushed image never appears in
the wallpaper picker. `adb shell content call --uri content://media/external --method scan_file
--arg <path>` does index it; `cmd media rescan` does not exist on this device.

The UI renders at 1920×1080 on the reference box and the panel is 4K, so everything is upscaled —
that is a device setting, identical under the stock launcher, and not a regression to chase.
