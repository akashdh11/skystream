package dev.akash.cs3engine

import android.content.Context
import com.lagradost.cloudstream3.HomePageResponse
import com.lagradost.cloudstream3.MainAPI
import com.lagradost.cloudstream3.MainPageRequest
import com.lagradost.cloudstream3.TvType
import com.lagradost.cloudstream3.mainPageOf
import com.lagradost.cloudstream3.newHomePageResponse
import com.lagradost.cloudstream3.newMovieSearchResponse
import com.lagradost.cloudstream3.plugins.Plugin
import kotlinx.coroutines.runBlocking
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlin.test.Test
import kotlin.test.assertEquals

/** mainPage pages one section at a time, as CloudStream's home rows do. */
class EngineMainPageTest {
    private object TestLoader : PluginLoader {
        override fun prepare(file: File) = PreparedPlugin(EngineMainPageTest::class.java.classLoader)
    }

    private fun cs3(className: String): File {
        val file = File.createTempFile("engine-main-page", ".cs3").apply { deleteOnExit() }
        ZipOutputStream(file.outputStream()).use { zip ->
            zip.putNextEntry(ZipEntry("manifest.json"))
            zip.write("""{"name":"Paged","pluginClassName":"$className","version":1}""".toByteArray())
            zip.closeEntry()
        }
        return file
    }

    @Suppress("UNCHECKED_CAST")
    private suspend fun Engine.sections(vararg pairs: Pair<String, Any?>) =
        (execute("mainPage", Json.mapper.valueToTree(mapOf(*pairs))) as Map<String, Any?>)["sections"] as List<Map<String, Any?>>

    @Suppress("UNCHECKED_CAST")
    private fun urls(section: Map<String, Any?>) = (section["items"] as List<Map<String, Any?>>).map { it["url"] }

    @Test
    fun `a section's page is the one asked for, and says whether another follows`() = runBlocking {
        val engine = Engine(TestLoader, { Context() }, "test")
        val file = cs3(PagedPlugin::class.java.name)
        engine.execute("loadPlugin", Json.mapper.valueToTree(mapOf("path" to file.path)))
        try {
            val first = engine.sections("provider" to "Paged", "section" to "Latest", "plugin" to file.path).single()
            assertEquals("Latest", first["name"])
            assertEquals(true, first["hasNext"])
            assertEquals(listOf("https://paged.invalid/Latest/1/0", "https://paged.invalid/Latest/1/1"), urls(first))

            val last = engine.sections("provider" to "Paged", "section" to "Latest", "page" to 3, "plugin" to file.path).single()
            assertEquals(false, last["hasNext"])
            assertEquals(listOf("https://paged.invalid/Latest/3/0", "https://paged.invalid/Latest/3/1"), urls(last))

            // Without a section, every section, each with its own answer's hasNext.
            val all = engine.sections("provider" to "Paged", "page" to 2, "plugin" to file.path)
            assertEquals(listOf("Latest", "Popular"), all.map { it["name"] })
            assertEquals(listOf(true, false), all.map { it["hasNext"] })
        } finally {
            engine.execute("unloadPlugin", Json.mapper.valueToTree(mapOf("path" to file.path)))
        }
        Unit
    }
}

class PagedPlugin : Plugin() {
    override fun load(context: Context) {
        registerMainAPI(PagedApi())
    }
}

/** Latest has three pages, Popular two; each page two titles. */
class PagedApi : MainAPI() {
    override var name = "Paged"
    override var mainUrl = "https://paged.invalid"
    override val hasMainPage = true
    override val mainPage = mainPageOf("latest" to "Latest", "popular" to "Popular")

    override suspend fun getMainPage(page: Int, request: MainPageRequest): HomePageResponse {
        val pages = if (request.name == "Latest") 3 else 2
        val items = (0..1).map { newMovieSearchResponse("${request.name} $page.$it", "$mainUrl/${request.name}/$page/$it", TvType.Movie) }
        return newHomePageResponse(request.name, items, hasNext = page < pages)
    }
}
