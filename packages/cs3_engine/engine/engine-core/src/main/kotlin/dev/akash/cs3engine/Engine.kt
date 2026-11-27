package dev.akash.cs3engine

import android.content.Context
import android.content.res.Resources
import com.fasterxml.jackson.databind.JsonNode
import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.MainPageRequest
import com.lagradost.cloudstream3.network.WebViewResolverHost
import com.lagradost.cloudstream3.plugins.Plugin
import com.lagradost.cloudstream3.plugins.RepositoryManager
import com.lagradost.cloudstream3.ui.settings.extensions.RepositoryData
import dev.akash.cs3engine.host.BrokerClock
import dev.akash.cs3engine.host.ClearanceInterceptor
import dev.akash.cs3engine.host.HostHooks
import dev.akash.cs3engine.host.NewPipeDownloader
import dev.akash.cs3engine.host.PageResolver
import dev.akash.cs3engine.host.RemoteWebViewHost
import dev.akash.cs3engine.host.WebClearance
import dev.akash.cs3engine.host.WebClearanceStore
import dev.akash.cs3engine.ui.ExtensionUi
import dev.akash.cs3engine.ui.ExtensionUiHost
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.File
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeoutException

/**
 * The CS3 engine. One JSON request in, one JSON response out:
 *
 *     {"id": 1, "method": "search", "params": {"provider": "Internet Archive", "query": "..."}}
 *     {"id": 1, "result": {...}}   or   {"id": 1, "error": {"type": ..., "message": ..., "trace": ...}}
 *
 * Methods: hello, loadPlugin{path,url?}, unloadPlugin{path}, providers, mainPage{provider,page?,section?},
 * search{provider,query,page?}, load{provider,url}, loadLinks{provider,data,timeoutMs?},
 * setRepositories{repositories}, setClearances{sites: [{site, cookies: {name: value}, userAgent, browserOnly?}],
 * moves?: {host: origin}},
 * webReply{rid, ...the answer}, webCaptured{rid, url, method?}, webScript{rid, result}, webPage{rid, type, ...}.
 * openSettings{path} (an open session, or an error: no screen, it threw, nothing showed in 3 s),
 * uiAction{session, node, action, value?} (action: click, longClick, check, text, submit, select, slide,
 * close; and focus (forward) and blur on a page node: Android's lent WebView, not counted as the person's),
 * closeUi{session, force?}, reloadPlugin{path, url?} (unload, then load: load() runs anew).
 * openPopups{path} (the extension's kept pop-ups as a screen, as its Support button opens them).
 * setLanguage{language} (the app's language: extensions' resources loaded from then on use it).
 * loadPlugin's and reloadPlugin's answers carry hasSettings.
 * mainPage's answer: sections [{name, items, hasNext}] (hasNext: the extension has a page after [page]), or
 * [{name, error}] for a section that failed.
 * loadPlugin's url is where the extension was downloaded from; extensions can look it up.
 * Provider calls also take plugin? (the extension's path) to tell same-named providers apart.
 * loadLinks's answer: links, subtitles, completed, error, and fullScreen: true when it ended with a full-screen window of
 * its extension, one that showed during it and still shows or went within [QUIET_END_MS] (a game: the app ends a Play
 * with no links quietly; a check the extension went on from doesn't count).
 * load's answer: the title (name, url, type, plot, posterUrl, backgroundPosterUrl, year, tags, duration), its score
 * (out of 10; none under 0.1), contentRating, logoUrl, posterHeaders, comingSoon, actors, trailers, recommendations
 * and syncIds (mal, anilist, kitsu, simkl, imdb, tmdb); a show's showStatus, nextAiring (unixTime in seconds) and
 * seasonNames; and per episode its score, date (epoch ms) and runTime (minutes).
 *
 * Events go out unprompted, through [HostHooks.event], as they happen:
 *
 *     {"event": "repositoryAdded", "url": ..., "name": ..., "iconUrl": ..., "plugin": <the adding extension's path>}
 *     {"event": "webRequest", "rid": ..., "op": ..., "url": ..., ...}   an extension needs the app's browser:
 *         op "solve" (failed?: {name: value}, the clearance the request met the check with, which has lapsed):
 *             a bot check to clear. webReply{rid, cookies, userAgent, earned?} (earned: the browser got it in this
 *             solve or moments before, not held from before; false only when said). A held one that meets the
 *             check again is named in a second solve.
 *         op "fetch" (method, headers, body): a request to send from inside one of the site's pages (one that
 *             lets only the browser through, or a refusal with no check marks, to learn whether it does).
 *             webReply{rid, status, url, headers, body}
 *         op "resolve" (headers, script, timeoutMs): a page to load hidden. Each request it makes
 *             goes to webCaptured (true: done, close the page), each script result to webScript,
 *             and webReply{rid} when the app is done with the page.
 *         op "page" (session, node, url, headers, userAgent, interfaces: {name: [one-way methods]}, answering?: {name:
 *             [methods that answer]}, fullScreen?: in a full-screen window, serve?: {name, folder, path, file}: the app
 *             serves `folder` under an address of its own named for `name`, loads `path` below it, and reports the
 *             page's addresses back under `file`): a page shown at a node of an open screen (a web view of an
 *             extension screen on the JVM), loaded with the extension's agent. Its events come back as
 *             webPage{rid, type, ...}: started, finished (title), failed (code, text, mainFrame), message (a script's
 *             one-way call of an interface), request (method, headers), closed; each carries url and cookies
 *             [{name, value, domain}] where it has them. Two wait for their answer, which the webPage request returns:
 *             call (message: an answering call, with its id) answers {value}, {error} (it threw: Android's message),
 *             or {} (undefined; also after 30 s); dialog (kind: alert, confirm or prompt; message, defaultText, url:
 *             the page's own dialog) answers {accept, text?} (the extension's chrome client's, or cancel with none) or
 *             {show: true} (the client left it to the app). No webReply.
 *         op "navigate" (url, headers, serve?), "closePage": the page with this rid loads again, or goes.
 *         op "eval" (page, script): runs script in page `page`; webReply{rid, result} (JSON text).
 *     A webReply without the answer's fields means the app couldn't.
 *     {"event": "siteMoved", "from": ..., "to": ...}   a request reached another host through permanent
 *         redirects that kept its path and query: the site may have moved (the app decides). From is the
 *         address the extension asked for, even when its request went where it had moved before.
 *     {"event": "siteMoveDropped", "from": ...}   a moved host's new domain didn't answer: the move is
 *         dropped, and the request went to the extension's address instead.
 *     {"event": "siteBrowserOnly", "url": ...}   the site lets only the browser through: a clearance its browser
 *         earned met the check again, or its page got past a refusal the engine's request didn't. The engine
 *         sends its later requests from the site's pages first; the app keeps it for the engine's later runs.
 *     {"event": "ui", "session", "plugin", "windows": [...]}   an open screen's windows, bottom to top, after
 *         each change (the spec's tree: windows {id, kind, title?, cancelable, hidden?, fullScreen?, keepScreenOn?,
 *         orientation?, root}).
 *     {"event": "uiClosed", "session", "plugin", "reason", "actions", "error"?}   reason: closed, restart,
 *         replaced, nothing, error (the extension crashed on the main thread; "error" says how).
 *     {"event": "restartRequested", "plugin"}   an extension asked to restart the app; the app reloads it.
 *     {"event": "uiOpened", "session", "plugin", "why": "waiting"}   a screen the engine opened by itself: the
 *         extension showed a window while the person waits on it (load, loadLinks, or 5 s after). Its ui events
 *         follow; the app shows it, and reloads nothing after. While it's open, calls' clocks stand still.
 *     {"event": "popups", "plugin", "titles"}   the extension's kept pop-ups, newest first, whenever they change
 *         (its Support button). {"event": "popupKept", "plugin", "title"} says one was kept,
 *         {"event": "popupDropped", "plugin", "reason"} that one was dismissed as if closed (reason: page), and
 *         {"event": "popupEscaped", "plugin", "why"} that one showed as Android draws it (why: thread).
 *     {"event": "pageFocusExit", "session", "node", "direction"}   focus left a page Android lent the sheet, towards
 *         forward, backward, up, down, left or right: the app moves its focus on.
 *     {"event": "toast", "text", "plugin"?, "session"?}   the JVM only (Android shows its own): an extension's
 *         toast. Likewise "copy" {text} (put on the clipboard, or shared) and "openUrl" {url} (a link it
 *         opened). Plugin is the extension whose code asked; session, the screen it has open.
 */
class Engine(
    loader: PluginLoader,
    private val context: () -> Context,
    private val platform: String,
    uiHost: ExtensionUiHost? = null,
    /** How long a screen the person waits on holds every call's clock: shorter only in tests. */
    waitingHoldLimitMs: Long = ExtensionUi.WAITING_HOLD_LIMIT_MS,
    /** How soon after its full-screen window a links call's end still ends a Play quietly: shorter only in tests. */
    private val quietEndMs: Long = QUIET_END_MS,
) {
    private val registry = PluginRegistry(loader, context)
    private val ui = ExtensionUi(uiHost, ::emit, holdLimitMs = waitingHoldLimitMs)
    private val startedAt = System.nanoTime()
    private val loadLock = Mutex()
    private val plugins = ConcurrentHashMap<String, LoadedPlugin>()
    private val providers = ConcurrentHashMap<String, MainAPI>()

    // Plugin code runs here, apart from the caller, so a call can give up on a plugin that blocks
    // its thread: a timeout only interrupts code that suspends.
    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        // CloudStream's app does this at startup; the library's YouTube extractors need it.
        NewPipeDownloader.install()
        // CloudStream's app names its id keys at startup too; extensions' addMalId and the like write under them.
        Mappers.nameSyncKeys()
        // Bot checks: the app's browser clears them, and its clearances go with every request on
        // CloudStream's shared clients.
        HostHooks.webView = RemoteWebViewHost
        // CloudStream's WebViewResolver loads its pages there too, on every platform.
        WebViewResolverHost.resolver = PageResolver
        com.lagradost.cloudstream3.app.baseClient =
            com.lagradost.cloudstream3.app.baseClient.newBuilder().addInterceptor(ClearanceInterceptor).build()
        com.lagradost.cloudstream3.insecureApp.baseClient =
            com.lagradost.cloudstream3.insecureApp.baseClient.newBuilder().addInterceptor(ClearanceInterceptor).build()
        RepositoryManager.onAdded = { repository, caller ->
            emit(
                "repositoryAdded",
                mapOf(
                    "url" to repository.url,
                    "name" to repository.name,
                    "iconUrl" to repository.iconUrl,
                    "plugin" to registry.pluginIn(caller)?.absolutePath,
                ),
            )
        }
        // An extension's restart caught outside an engine call (Android's crash guard) reloads it too.
        HostHooks.restartRequested = { error -> ui.restartRequested(registry.pluginIn(error)) }
        HostHooks.pluginCrashed = { error ->
            val cause = Json.rootCause(error)
            ui.pluginCrashed(registry.pluginIn(error), cause.message?.let { "${cause.javaClass.simpleName}: $it" } ?: cause.javaClass.simpleName)
        }
    }

    /** The plugin an uncaught [error] came from, if any (its file name); hosts use it to keep the app alive. */
    fun pluginIn(error: Throwable): String? = registry.pluginIn(error)?.name

    /** The extension whose code [error]'s stack passes through, if any. */
    fun pluginFileIn(error: Throwable): File? = registry.pluginIn(error)

    /** The extension that loaded [type], if any. */
    fun pluginFileOf(type: Class<*>): File? = registry.pluginOf(type)

    /** [file]'s own resources, when it's loaded and asked for them (its manifest's requiresResources). */
    fun pluginResources(file: File): Resources? = (plugins[file.absolutePath]?.plugin as? Plugin)?.resources

    /**
     * Tells the app what an extension asked the system for, which the app shows itself (the JVM's toasts,
     * copies and links): with the extension's path, and the session of the screen it has open.
     */
    fun notice(type: String, plugin: File?, fields: Map<String, Any?>) {
        val about = LinkedHashMap(fields)
        if (plugin != null) {
            about["plugin"] = plugin.absolutePath
            ui.sessionOf(plugin)?.let { about["session"] = it }
        }
        emit(type, about)
    }

    suspend fun respond(requestJson: String): String {
        val request = try {
            Json.mapper.readTree(requestJson)
        } catch (e: Exception) {
            return Json.error(null, e)
        }
        val id = request.get("id")
        return try {
            Json.result(id, execute(request.path("method").asText(""), request.path("params")))
        } catch (t: Throwable) {
            Json.error(id, t)
        }
    }

    suspend fun execute(method: String, params: JsonNode): Any? = when (method) {
        "hello" -> hello()
        "loadPlugin" -> loadPlugin(File(params.text("path")), params.optText("url"))
        "unloadPlugin" -> unloadPlugin(File(params.text("path")))
        "providers" -> providers.values.sortedBy { it.name }.map(::describe)
        "mainPage" -> timed {
            val api = provider(params)
            ui.call(pluginFile(api)) { mainPage(api, params.int("page", 1), params.optText("section")) }
        }
        "search" -> timed {
            val api = provider(params)
            ui.call(pluginFile(api)) { search(api, params.text("query"), params.int("page", 1)) }
        }
        "load" -> timed {
            val api = provider(params)
            val plugin = pluginFile(api)
            ui.call(plugin) { ui.personCall(plugin) { load(api, params.text("url"), plugin) } }
        }
        "loadLinks" -> timed {
            val api = provider(params)
            val plugin = pluginFile(api)
            ui.call(plugin) {
                ui.personCall(plugin) { loadLinks(api, params.text("data"), params.long("timeoutMs", 30_000), plugin) }
            }
        }
        "setRepositories" -> setRepositories(params.path("repositories"))
        "setLanguage" -> setLanguage(params.text("language"))
        "setClearances" -> setClearances(params.path("sites"), params.path("moves"))
        "webReply" -> {
            RemoteWebViewHost.reply(params.path("rid").asLong(), params)
            true
        }
        "webCaptured" -> RemoteWebViewHost.captured(params.path("rid").asLong(), params.text("url"), params.optText("method"))
        "webScript" -> {
            RemoteWebViewHost.scriptResult(params.path("rid").asLong(), params.path("result").asText(""))
            true
        }
        // Most events answer true at once; a page's answering call and its own dialogs wait (Phase 7c).
        "webPage" -> RemoteWebViewHost.pageEvent(params.path("rid").asLong(), params)
        "openSettings" -> openSettings(File(params.text("path")))
        "openPopups" -> ui.openPopups(File(params.text("path")))
        "uiAction" -> ui.act(params.int("session", -1), params.int("node", -1), params.text("action"), params.value("value"))
        "closeUi" -> ui.close(params.int("session", -1), params.path("force").asBoolean(false))
        "reloadPlugin" -> reloadPlugin(File(params.text("path")), params.optText("url"))
        else -> throw IllegalArgumentException("unknown method '$method'")
    }

    private fun setClearances(sites: JsonNode, moves: JsonNode): Int {
        val clearances = sites.mapNotNull { site ->
            val name = site.path("site").asText("").ifEmpty { null } ?: return@mapNotNull null
            val agent = site.path("userAgent").asText("").ifEmpty { null } ?: return@mapNotNull null
            name to WebClearance(cookieMap(site.path("cookies")), agent, site.path("browserOnly").asBoolean(false))
        }.toMap()
        WebClearanceStore.setSites(clearances)
        WebClearanceStore.setMoves(moves.fields().asSequence().associate { it.key to it.value.asText() })
        return clearances.size
    }

    private fun cookieMap(node: JsonNode): Map<String, String> =
        node.fields().asSequence().associate { it.key to it.value.asText() }

    private fun hello(): Map<String, Any?> = mapOf(
        "engine" to VERSION,
        "platform" to platform,
        // java.version and java.vm.info are absent on Android; java.vm.version exists everywhere.
        "vm" to listOfNotNull(System.getProperty("java.vm.name"), System.getProperty("java.vm.version")).joinToString(" ") +
            (System.getProperty("java.vm.info")?.let { " ($it)" } ?: ""),
        "uptimeMs" to elapsedMs(startedAt),
        "plugins" to plugins.size,
        "providers" to providers.size,
    )

    private fun provider(params: JsonNode): MainAPI {
        val name = params.text("provider")
        // Extensions (forks, mostly) can register providers with the same name; `plugin` picks one.
        val api = when (val plugin = params.optText("plugin")) {
            null -> providers[name]
            else -> plugins[File(plugin).absolutePath]?.providers?.firstOrNull { it.name == name }
        }
        return api ?: throw IllegalArgumentException("no loaded provider named '$name'")
    }

    /** The extension [api] came from: its calls are counted, and a person waiting on one waits on the extension. */
    private fun pluginFile(api: MainAPI): File? = api.sourcePlugin?.let(::File)

    /** A provider as the app sees it. A plugin's property can throw; that must not hide its other providers. */
    private fun describe(api: MainAPI): Map<String, Any?> = try {
        Mappers.provider(api)
    } catch (t: Throwable) {
        mapOf("name" to runCatching { api.name }.getOrDefault("?"), "error" to (Json.rootCause(t).message ?: t.toString()))
    }

    // Plugins register providers into a global list, so loads must not overlap. Converting a
    // plugin's code (desktop and iOS) is most of a load and can, so it happens first.
    private suspend fun loadPlugin(file: File, url: String?): Map<String, Any?> {
        val started = System.nanoTime()
        if (plugins[file.absolutePath]?.fingerprint != registry.fingerprint(file)) {
            withContext(Dispatchers.IO) { registry.convert(file) }
        }
        return loadLock.withLock { register(file, url, started) }
    }

    private suspend fun register(file: File, url: String?, started: Long): Map<String, Any?> {
        val current = plugins[file.absolutePath]
        val loaded = if (current != null && current.fingerprint == registry.fingerprint(file)) {
            current
        } else {
            // A changed file at a loaded path is an update: drop the old version first.
            if (current != null) dropPlugin(current)
            loadBounded(file, url).also {
                plugins[file.absolutePath] = it
                it.providers.forEach { api -> providers[api.name] = api }
            }
        }
        return mapOf(
            "plugin" to loaded.manifest.name,
            "version" to loaded.manifest.version,
            "providers" to loaded.providers.map(::describe),
            "extractors" to loaded.extractors,
            "hasSettings" to ((loaded.plugin as? Plugin)?.openSettings != null),
            "notes" to loaded.notes,
            "ms" to elapsedMs(started),
        )
    }

    /**
     * Loads [file], giving up after [LOAD_TIMEOUT_MS]: loads hold [loadLock], and a plugin stuck in
     * its own load() would otherwise stop every other plugin loading. Should it ever finish, what
     * it registered is removed again.
     */
    @OptIn(ExperimentalCoroutinesApi::class)
    private suspend fun loadBounded(file: File, url: String?): LoadedPlugin {
        // A call of the plugin's, as its searches are: a page its load() shows in the background and waits on is
        // dropped (the spec's §7), not kept as a promotion while the load waits out its time.
        val loading = pluginScope.async { ui.call(file) { registry.load(file, url) } }
        return try {
            withTimeout(LOAD_TIMEOUT_MS) { loading.await() }
        } catch (e: TimeoutCancellationException) {
            loading.invokeOnCompletion { cause -> if (cause == null) registry.unload(loading.getCompleted()) }
            loading.cancel()
            throw TimeoutException("${file.name} did not finish loading in ${LOAD_TIMEOUT_MS / 1000} s")
        }
    }

    private suspend fun unloadPlugin(file: File): Map<String, Any?> = loadLock.withLock {
        val current = plugins[file.absolutePath]
        if (current != null) dropPlugin(current)
        mapOf("unloaded" to (current != null))
    }

    /** Unloads [file] and loads it again, so its load() runs anew: what its settings screen saved applies. */
    private suspend fun reloadPlugin(file: File, url: String?): Map<String, Any?> {
        val started = System.nanoTime()
        return loadLock.withLock {
            plugins[file.absolutePath]?.let { dropPlugin(it) }
            register(file, url, started)
        }
    }

    /** Opens [file]'s own settings screen with the app's context (the activity, on Android). */
    private suspend fun openSettings(file: File): Map<String, Any?> {
        val loaded = plugins[file.absolutePath] ?: throw IllegalStateException("${file.name} isn't loaded")
        val settings = (loaded.plugin as? Plugin)?.openSettings
            ?: throw IllegalStateException("${file.name} has no settings screen")
        val context = context()
        return ui.openSettings(file) { settings(context) }
    }

    /** Unloads [loaded]; a provider it shadowed by name (another extension's) takes its place again. */
    private suspend fun dropPlugin(loaded: LoadedPlugin) {
        // Its open screen first: once unloaded, its code can't run what the screen still asks of it.
        ui.pluginUnloaded(loaded.file)
        plugins.remove(loaded.file.absolutePath)
        registry.unload(loaded)
        for (api in loaded.providers) {
            if (!providers.remove(api.name, api)) continue
            plugins.values.flatMap { it.providers }.lastOrNull { it.name == api.name }?.let { providers[api.name] = it }
        }
    }

    /** The app's repositories, each {url, name, iconUrl?}: what plugins see as CloudStream's list. */
    private fun setRepositories(list: JsonNode): Map<String, Any?> {
        RepositoryManager.setRepositories(
            list.map { RepositoryData(it.optText("iconUrl"), it.optText("name") ?: it.text("url"), it.text("url")) },
        )
        return mapOf("repositories" to list.size())
    }

    /**
     * The app's language (a code such as "hi"): extensions' resources loaded from now on pick their strings
     * in it where they ship them (the JVM's stand-ins; Android's own resources follow the app already).
     */
    private fun setLanguage(language: String): Map<String, Any?> {
        System.setProperty("cs3.language", language)
        return mapOf("language" to language)
    }

    /** Sends the app an event (see the class comment); one that cannot be sent must not fail the plugin. */
    private fun emit(type: String, fields: Map<String, Any?>) {
        try {
            HostHooks.event(Json.mapper.writeValueAsString(mapOf("event" to type) + fields))
        } catch (t: Throwable) {
            HostHooks.log("could not send the $type event: $t")
        }
    }

    private suspend fun mainPage(api: MainAPI, page: Int, section: String?): Map<String, Any?> {
        val sections = mutableListOf<Map<String, Any?>>()
        for (data in api.mainPage.filter { section == null || it.name == section }) {
            try {
                val response = pluginCall(MAIN_PAGE_TIMEOUT_MS) {
                    api.getMainPage(page, MainPageRequest(data.name, data.data, data.horizontalImages))
                }
                // hasNext is the response's, so each of its lists carries it: the app pages one section at a time.
                response?.items?.forEach { list ->
                    sections += mapOf(
                        "name" to list.name,
                        "items" to list.list.map(Mappers::searchItem),
                        "hasNext" to response.hasNext,
                    )
                }
            } catch (e: Exception) {
                sections += mapOf("name" to data.name, "error" to (Json.rootCause(e).message ?: e.toString()))
            }
        }
        return mapOf("sections" to sections)
    }

    private suspend fun search(api: MainAPI, query: String, page: Int): Map<String, Any?> = pluginCall(CALL_TIMEOUT_MS) {
        // The paged overload falls back to the one-argument search for older plugins.
        val result = api.search(query, page)
        mapOf("items" to result?.items.orEmpty().map(Mappers::searchItem), "hasNext" to (result?.hasNext ?: false))
    }

    private suspend fun load(api: MainAPI, url: String, plugin: File?): Map<String, Any?> = pluginCall(CALL_TIMEOUT_MS, plugin) {
        Mappers.loadResponse(api.load(url) ?: error("${api.name} returned nothing for $url"))
    }

    /**
     * Links arrive through callbacks; whatever arrived before [timeoutMs], or before the plugin failed, is returned. A
     * failure with no links is an error. While [plugin]'s full-screen window shows, the call's time stands still, and an
     * answer that came as such a window went (`fullScreen`: within [quietEndMs]) ends a Play with no links quietly in the
     * app (Phase 7c's §4): the window was the call, a game. One the extension went on from, a check before its links,
     * leaves "No streams found" to say so.
     */
    private suspend fun loadLinks(api: MainAPI, data: String, timeoutMs: Long, plugin: File?): Map<String, Any?> {
        val since = ui.now()
        val links = Collections.synchronizedList(mutableListOf<Map<String, Any?>>())
        val subtitles = Collections.synchronizedList(mutableListOf<Map<String, Any?>>())
        val call = pluginScope.async {
            api.loadLinks(data, false, { subtitles += Mappers.subtitle(it) }, { links += Mappers.link(it) })
        }
        var failure: Throwable? = null
        val finished = try {
            BrokerClock.shared.await(call, timeoutMs, standStill = standStill(plugin)).also { finished -> if (finished) call.await() }
        } catch (e: CancellationException) {
            throw e
        } catch (t: Throwable) {
            failure = t
            false
        } finally {
            call.cancel()
        }
        val found = synchronized(links) { links.toList() }
        if (failure != null && found.isEmpty()) throw failure
        val answer = mutableMapOf<String, Any?>(
            "links" to found,
            "subtitles" to synchronized(subtitles) { subtitles.distinctBy { it["url"] } },
            "completed" to finished,
            "error" to failure?.let { Json.rootCause(it).message ?: it.toString() },
        )
        if (plugin != null && ui.fullScreenEndedWith(plugin, since, quietEndMs)) answer["fullScreen"] = true
        return answer
    }

    /**
     * Runs plugin code, giving up after [timeoutMs] even if it blocks its thread. Time the plugin spends waiting on the
     * app's browser doesn't count ([BrokerClock]), nor, for a call the person waits on of [plugin]'s, the time its
     * full-screen window shows (Phase 7c's §4).
     */
    private suspend fun <T> pluginCall(timeoutMs: Long, plugin: File? = null, block: suspend () -> T): T {
        val call: Deferred<T> = pluginScope.async { block() }
        return try {
            if (!BrokerClock.shared.await(call, timeoutMs, standStill = standStill(plugin))) throw TimeoutException("Timed out waiting for $timeoutMs ms")
            call.await()
        } finally {
            call.cancel()
        }
    }

    /** While [plugin]'s full-screen window shows, the call that waits on it doesn't time out. */
    private fun standStill(plugin: File?): () -> Boolean = { plugin != null && ui.fullScreenShowing(plugin) }

    private inline fun timed(block: () -> Map<String, Any?>): Map<String, Any?> {
        val started = System.nanoTime()
        val result = block()
        return result + ("ms" to elapsedMs(started))
    }

    private fun elapsedMs(since: Long): Long = (System.nanoTime() - since) / 1_000_000

    companion object {
        const val VERSION = "0.3.0"
        private const val CALL_TIMEOUT_MS = 60_000L
        private const val MAIN_PAGE_TIMEOUT_MS = 30_000L
        private const val LOAD_TIMEOUT_MS = 120_000L

        /** See [quietEndMs]. */
        const val QUIET_END_MS = 2_000L
    }
}
