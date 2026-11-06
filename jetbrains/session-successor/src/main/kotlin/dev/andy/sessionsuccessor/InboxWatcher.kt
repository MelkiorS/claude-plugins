package dev.andy.sessionsuccessor

import com.intellij.openapi.application.EDT
import com.intellij.openapi.diagnostic.logger
import com.intellij.openapi.project.Project
import com.intellij.openapi.startup.ProjectActivity
import com.intellij.openapi.wm.ToolWindowManager
import com.intellij.terminal.frontend.toolwindow.TerminalToolWindowTabsManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.withContext
import java.nio.file.Files
import java.nio.file.NoSuchFileException
import java.nio.file.Path
import java.time.Instant
import kotlin.io.path.extension
import kotlin.io.path.listDirectoryEntries

private val LOG = logger<InboxWatcher>()
private val INBOX: Path = Path.of(System.getProperty("user.home"), ".claude", "session-successor", "inbox")
private val SAFE_NAME = Regex("^[A-Za-z0-9._-]{1,64}$")
private const val POLL_MS = 1_000L
private const val TERMINAL_TOOL_WINDOW_ID = "Terminal"

class InboxWatcher : ProjectActivity {
    override suspend fun execute(project: Project) {
        val base = project.basePath?.let { Path.of(it).normalize() } ?: return
        LOG.info("watching $INBOX for $base")
        while (currentCoroutineContext().isActive && !project.isDisposed) {
            runCatching { scan(project, base) }.onFailure { LOG.warn("inbox scan failed", it) }
            delay(POLL_MS)
        }
    }

    private suspend fun scan(project: Project, base: Path) {
        if (!Files.isDirectory(INBOX)) return
        for (file in INBOX.listDirectoryEntries().filter { it.extension == "json" }) {
            val text = Files.readString(file)
            val name = jsonField(text, "name")
            val cwd = jsonField(text, "cwd")
            if (name == null || !SAFE_NAME.matches(name) || cwd == null) {
                LOG.warn("discarding bad order $file")
                Files.deleteIfExists(file)
                continue
            }
            // The note's folder only routes it to the right window; the tab opens at this project's root.
            if (!Path.of(cwd).normalize().startsWith(base)) continue
            // A note can outlive its session (a reboot, a stopped session): don't open a dead tab.
            val pid = jsonNumber(text, "pid")
            if (pid != null && !successorRunning(pid, Files.getLastModifiedTime(file).toInstant())) {
                LOG.info("discarding note for $name: its session (pid $pid) is no longer running")
                Files.deleteIfExists(file)
                continue
            }
            // Deleting first claims the order, so a second window on the same project can't open it twice.
            try {
                Files.delete(file)
            } catch (_: NoSuchFileException) {
                continue
            }
            withContext(Dispatchers.EDT) { openTab(project, base, name) }
        }
    }

    private fun openTab(project: Project, base: Path, name: String) {
        ToolWindowManager.getInstance(project).getToolWindow(TERMINAL_TOOL_WINDOW_ID)?.show()
        val tab = TerminalToolWindowTabsManager.getInstance(project)
            .createTabBuilder()
            .workingDirectory(base.toString())
            .tabName(name)
            .requestFocus(false)
            .createTab()
        tab.view.createSendTextBuilder().shouldExecute().send("claude attach $name")
        LOG.info("opened tab $name in $base")
    }
}

// The successor's process must exist and have started before its note was written; a later start
// means the pid was recycled by an unrelated process.
private fun successorRunning(pid: Long, noteWrittenAt: Instant): Boolean {
    val process = ProcessHandle.of(pid).orElse(null) ?: return false
    if (!process.isAlive) return false
    val started = process.info().startInstant().orElse(null) ?: return true
    return !started.isAfter(noteWrittenAt)
}

// Minimal parsing of the flat note `successor start` writes: {"name": "...", "cwd": "...", "pid": 123}.
private fun jsonField(json: String, key: String): String? =
    Regex("\"$key\"\\s*:\\s*\"([^\"]*)\"").find(json)?.groupValues?.get(1)

private fun jsonNumber(json: String, key: String): Long? =
    Regex("\"$key\"\\s*:\\s*(\\d+)").find(json)?.groupValues?.get(1)?.toLongOrNull()
