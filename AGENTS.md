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

Debug builds carry `applicationIdSuffix '.debug'`, so they install as
`io.github.agarpac.lemonade.debug`, a separate app that does not replace a working launcher. That is
the safe way to test on a real box.

### Release builds

Signing reads `android/local.properties` — **not** `key.properties`, which nothing looks at — for
`storeFile`, `storePassword`, `keyAlias` and `keyPassword`, or failing that the environment
variables `SIGNING_KEYSTORE_PASSWORD` / `SIGNING_KEY_ALIAS` / `SIGNING_KEY_PASSWORD` when
`android/app/upload-keystore.jks` exists. Both the keystore and that properties file are
gitignored. Without them a release build comes out **unsigned**, which is the same as having no
release at all.

A release build produces **one APK**, universal, about 60 MB — most of it `libflutter.so` and
`libapp.so` repeated once per architecture.

Per-ABI splitting was **removed from `android/app/build.gradle`** on 31/07/2026. The block was not
gated on `--split-per-abi`: it enabled itself on *any* `assembleRelease`, so every release build
quietly emitted four extra APKs into the output directory, one of them an x86 shell with no native
libraries at all that installs and then crashes. Worse, Flutter offsets each split's `versionCode`
(armeabi-v7a +1000, arm64-v8a +2000, x86_64 +4000) while `pickReleaseApk` prefers the universal, so
anyone who installed a split could never be updated — the next universal reads as a downgrade and
Android refuses it. See `docs/PRD.md` section 13.9.

If splitting is ever reintroduced, all three of those have to be answered first, and the release
process has to stop attaching both kinds at once.

**Name the artifact before attaching it to a release.** `UpdateService.isAbiSplitApk` treats a
`-arm64-v8a.apk`, `-armeabi-v7a.apk`, `-armeabi.apk`, `-x86_64.apk` or `-x86.apk` suffix as a per-ABI
build, and `pickReleaseApk` prefers the asset without one. Gradle's own name ends in
`-github-release.apk`; rename it:

```
lemonade-launcher-<version>.apk
```

**`gh` resolves the wrong repository in this checkout.** There are two remotes, and `gh` picks
`upstream` — so `gh release list` shows the upstream project's releases and `gh release create` tries
to publish *there*, failing on permissions. Always pass `--repo agarpac/lemonade-launcher`
explicitly, or run `gh repo set-default agarpac/lemonade-launcher` first.

A release the updater will actually offer must be **neither a draft nor a prerelease**, must carry a
semver tag greater than `pubspec.yaml`'s `version`, and must have at least one `.apk` attached. And
the self-updater only exists in a build that was given its `--dart-define`s:

```shell
flutter build apk --release --flavor github \
  --dart-define=ENABLE_SELF_UPDATER=true \
  --dart-define=UPDATE_REPO_OWNER=agarpac \
  --dart-define=UPDATE_REPO_NAME=lemonade-launcher
```

Pass those flags **literally**, never through a shell variable: this environment runs zsh, which does
not word-split an unquoted parameter, so `$DEFS` arrives as a single argument and
`bool.fromEnvironment` quietly reads false. The build succeeds and the updater is simply absent.
Verify it landed rather than assuming — the API URL is a compile-time constant and shows up in the
binary:

```shell
unzip -p <apk> lib/arm64-v8a/libapp.so | strings | grep api.github.com
```

**Every JDK tool needs the mise prefix too, not just flutter.** `apksigner`, `keytool` and `jarsigner`
live in the Android SDK or the JDK, and without the activation they fail with "Unable to locate a
Java Runtime" — which reads like a broken SDK rather than a missing PATH:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && \
  ~/Library/Android/sdk/build-tools/35.0.0/apksigner verify --print-certs <apk>
```

**Generating a keystore: pass `-dname` and skip the interview.** `keytool`'s interactive prompt ends
with a confirmation whose default is **no**, so pressing ENTER answers "not correct" and it loops
forever. Worse, answering a question with `no` sets that field's literal value to the string "no" —
the way to leave a field empty is a single dot. The certificate's distinguished name is embedded
permanently and visible to anyone inspecting the signature, and changing it means a new key, which
after the first release breaks the update path for everyone. So get it right in one shot:

```shell
eval "$(/opt/homebrew/bin/mise env -s bash)" && keytool -genkeypair -v \
  -keystore android/app/upload-keystore.jks \
  -storetype PKCS12 -alias lemonade \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=agarpac, O=Lemonade Launcher, C=ES"
```

PKCS12 does not support a key password distinct from the store password, which is why
`storePassword` and `keyPassword` in `android/local.properties` are the same value.

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
- **Keep this file current — in the same change that earns it.** When a development alters the build,
  the release process, the architecture, a workflow a future agent must follow, or uncovers a new
  trap, record it here as part of that change, not as a later chore. Keep the boundary clean:
  AGENTS.md holds what an agent needs to work the code safely (build, traps, conventions, workflow);
  `docs/PRD.md` holds product decisions. Each fact lives in exactly one of them — never mirror the
  same information across both. This file is the fork's institutional memory: a trap left unwritten
  here has already cost real bugs, and the next agent starts blind.

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

**A focused `TextField` swallows the D-pad's up/down** — the arrows move the caret, not the focus —
so on a remote the user cannot leave the field to reach the buttons below it. To let them out,
intercept arrow up/down on the enclosing `FocusScopeNode.onKeyEvent` while the field holds focus and
call `previousFocus()`/`nextFocus()` yourself, guarding against the key firing on both key-down and
key-up (which would move two steps). `LauncherSectionPanelPage` and `ContentShortcutPanelPage` both
do this; a settings page with a text field above its buttons needs it, or the buttons are
unreachable — this is what made an existing content shortcut impossible to delete.

**A shared `FocusNode` reassigned to a different widget during a rebuild drops the focus instead of
moving it.** In a reorderable list, keying the initial-focus node to "whichever item sits at index 0"
tears the node away from the item the remote is actually on the moment the order changes. Capture the
initial-focus target once, by stable id, so the node keeps the same widget identity for the widget's
whole lifetime. This cost a real bug fixing PRD 13.6.

**The hidden top bar is reached by a programmatic intent**, not by directional traversal, and that
works at zero height. Never make its reachability depend on geometry, or a collapsed bar traps the
user with no way into Settings.

**The scenes master switch must stay reachable when scenes are off.** `scenesEnabled == false` hides
the scenes icon from the home bar, but the switch that turns it back on lives on the Scenes settings
page. Gate the home icon on the flag, never the Interface-menu tile that reaches that page — gate
both and the user can never re-enable scenes.

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
