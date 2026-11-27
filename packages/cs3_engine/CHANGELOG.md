## Unreleased

- **mainPage says whether a section has another page:** each section carries its answer's
  `hasNext`, so the app can ask for the `page` after it, one section at a time. The engine also sets
  the system property `cs3engine.homePaging=true`, so extensions can tell and skip their own
  workarounds.
- **A site counts as letting only the browser through on proof only:** a clearance the browser
  earned in that solve (or moments before) meeting the check again. Behind `CloudflareKiller`, a 403
  with none of a check's marks counts only when one of the site's pages gets past it. A 503 with
  none is the origin's own answer, no longer a refusal: it costs no solve. Each mark is reported
  (`siteBrowserOnly {url}`), so the app keeps it.
- **A clearance a check refused isn't handed back.** The `solve` op names it (`failed`: its
  cookies); the app solves again when that's the one it holds, however fresh it looked, unless it
  was solved moments ago. `webReply` says whether the browser earned the clearance (`earned`). One
  the app held that meets the check again (or, behind `CloudflareKiller`, a 403 its page gets past)
  is named in a second solve. On a host already marked, a check names nothing: it says nothing of
  the clearance's age.
- **Android:** a resolve sets CloudStream's `WebViewResolver.webViewUserAgent` from the device's
  WebView again, as CloudStream's own resolver did.
- **`load` answers with everything CloudStream's details page shows:** `score` (out of 10, none
  under 0.1), `contentRating`, `logoUrl`, `posterHeaders`, `comingSoon`, `actors` (with voice
  actors), `trailers`, `recommendations` (search items) and `syncIds` (`mal`, `anilist`, `kitsu`,
  `simkl`, `imdb`, `tmdb`); for shows, `showStatus`, `nextAiring` (`unixTime` in seconds) and
  `seasonNames`; per episode, `score`, `date` (epoch ms) and `runTime` (minutes). Search items
  carry `apiName`, `score` and `quality`.
- **CloudStream's id keys are named at start-up** (`mal`, `kitsu`, `anilist`, `simkl`), as its app
  does. Every `addMalId`, `addAniListId`, `addImdbId` and `addTMDbId` used to write the one key
  `""`, each overwriting the last.

## 0.5.0

- **More of the CloudStream app for extensions** (`app-shims`, Android and the JVM alike). Eight of
  the 485 surveyed extensions didn't load on any platform because they reach into the app itself:
  - Accounts and sync (`AccountManager`, `SyncRepo`, `SyncAPI`, AniList and Simkl): nobody is signed
    in, so lists come back empty. AniList's data classes are there for extensions that parse
    AniList's answers into them.
  - The app's watch history (`DataStoreHelper`, `WatchType`, `SyncWatchType`, `VideoWatchState`):
    nothing is bookmarked or resumed. A `when` over a watch state reads every constant the first
    time it runs, so they're needed even without sync.
  - Older plugins' account settings (`InAppAuthAPIManager`, from before the app's 2025 account
    rework), source priorities (`QualityDataHelper`), `UiText`, `VideoClickAction`s (accepted, not
    shown) and the `Chillx` extractor the library dropped (registers, finds no links).
- **`loadPlugin` takes `url`,** where the plugin was downloaded from: extensions read it back from
  `PluginManager` (ViStream registers nothing unless it came from its own repository). Without
  one, a plugin is a local file, as upstream.
- **The JVM's placeholders for missing Android exceptions are throwables.** DEX 035 plugins
  convert to Java 6 classes, and the JVM's older verifier rejected a `catch` of a placeholder
  (StreamCenter catches `ActivityNotFoundException`).
- **On Linux the `java` sidecar starts detached,** not as the app's child. Dart collected libVLC's
  `proxy` helper while it waited on the engine, and VLC then waited for it forever: the player
  froze opening a stream. Its end is now told by its output closing, and `dispose` still ends it.
- **Sites that move.** `setClearances` takes the app's moves (`{host: origin}`), and extensions'
  requests to a moved host go straight to its new domain. A request that reaches another host
  through permanent redirects (301, 308) keeping its path and query, and meets a bot check there, is
  reported as `siteMoved`, from the address the extension asked for. Without a check it's no move:
  hosts redirect for good for their own reasons (GitHub's raw host to github.com). A move whose new domain doesn't answer is dropped and
  reported as `siteMoveDropped`, and the request goes to its own address.
- **A bot check is solved where the request ended,** after any redirect, and the request the site
  answered is sent again, as the redirect made it (a POST a redirect turned into a GET stays a
  GET): a moved site's check and clearance are on its new domain.

## 0.4.0

- **The app's browser, for extensions.** Besides solving bot checks, the engine asks the app for
  two more things:
  - A request sent from inside one of a site's pages (`webRequest` op `fetch`), when the site
    refuses a fresh clearance from the engine.
  - A page loaded hidden for CloudStream's `WebViewResolver` (op `resolve`), on every platform.
    Its requests come back one at a time (`webCaptured`, `webScript`) to be matched with the
    extension's own patterns.
- CloudStream's library is built with a patch (`tool/patches/`): its `WebViewResolver` asks the
  engine's resolver first. On the JVM that replaces a `TODO()`. On Android it replaces CloudStream's
  own WebView, which took the app down when its renderer ended (low memory, a WebView update), and
  kept its pages out of the app's page budget.
- `CloudflareKiller` does what the shared clients' interceptor does, triaging as the app does:
  - block pages never ask for a solve;
  - DDoS-Guard's check is solved too;
  - a request both handle makes one solve.

## 0.3.0

- Part of SkyStream's repository (`packages/cs3_engine`): the engine's sources (`engine/`),
  CloudStream's library (`m2/`) and the build tools (`tool/`) came along, so the app builds on its
  own. The Android plugin adds its repositories to the build itself.
- Desktop builds carry a trimmed Java runtime (`tool/build_runtime.dart`), unpacked on first use;
  without one the engine uses the machine's Java 17+, Android Studio's included.

## 0.2.0

- Events from the engine (`Cs3Engine.events`), such as `repositoryAdded` when a plugin like
  MegaRepo's adds repositories; `setRepositories` hands the engine the app's list.
- `isRunning`, and a `dispose` that waits for the desktop engine to exit.
- An optional `java` executable for the desktop engine; a clear error when there is none.
- Faster conversion on desktop and iOS: several threads, and plugins convert side by side.
- iOS: requests no longer hold a thread while they run; an arm64 device slice for the runtime.
- Calls give up on plugins that block their thread; partial links survive a failing plugin;
  a plugin that fails to load leaves nothing behind.
- Android builds leave out the engine jars, and carry the R8 rules extensions need.

## 0.1.0

- First version: load, search, details and links for CloudStream extensions on Android, iOS,
  macOS, Windows and Linux.
