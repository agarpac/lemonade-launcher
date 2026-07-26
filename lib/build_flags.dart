/// Build-time configuration for the self-updater.
///
/// The updater pulls release metadata from the GitHub Releases API of
/// [kUpdateRepoOwner]/[kUpdateRepoName]. Both default to empty so that a build
/// which has not been pointed at a repository can never offer an APK from
/// somebody else's project — see [kSelfUpdaterAvailable].
///
/// Enable it at build time:
///   flutter build apk --release \
///     --dart-define=ENABLE_SELF_UPDATER=true \
///     --dart-define=UPDATE_REPO_OWNER=<github-user> \
///     --dart-define=UPDATE_REPO_NAME=<github-repo>
const bool kEnableSelfUpdater = bool.fromEnvironment(
  'ENABLE_SELF_UPDATER',
  defaultValue: false,
);

const String kUpdateRepoOwner = String.fromEnvironment(
  'UPDATE_REPO_OWNER',
  defaultValue: '',
);

const String kUpdateRepoName = String.fromEnvironment(
  'UPDATE_REPO_NAME',
  defaultValue: '',
);

/// The updater is only reachable when it is both enabled and pointed at a
/// repository. Without this guard, enabling the flag alone would resolve to the
/// GitHub API path `/repos//releases` and fail at runtime instead of at build
/// time.
const bool kSelfUpdaterAvailable =
    kEnableSelfUpdater && kUpdateRepoOwner != '' && kUpdateRepoName != '';

/// Slug used in the updater's User-Agent header and in downloaded APK names.
const String kUpdaterUserAgent = 'LemonadeLauncher-Updater';
const String kApkNamePrefix = 'lemonade-launcher';
