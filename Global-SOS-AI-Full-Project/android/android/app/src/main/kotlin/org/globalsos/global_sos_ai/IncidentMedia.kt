package org.globalsos.global_sos_ai

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class IncidentMedia(private val activity: Activity) {
    private val folder get() = File(activity.filesDir, "incidents").apply { mkdirs() }
    private val limit = 100L * 1024 * 1024
    private val totalLimit = 500L * 1024 * 1024
    private val extensions = mapOf("image/jpeg" to "jpg", "image/png" to "png", "image/webp" to "webp",
        "image/heic" to "heic", "image/heif" to "heif", "video/mp4" to "mp4", "video/webm" to "webm",
        "video/quicktime" to "mov", "video/3gpp" to "3gp")
    private data class Pending(val result: MethodChannel.Result, val action: String,
        val file: File? = null, val ids: List<String> = emptyList(), val text: String = "")
    private var pending: Pending? = null

    private fun file(id: String): File {
        require(Regex("[a-f0-9-]{36}\\.(jpg|png|webp|heic|heif|mp4|webm|mov|3gp)").matches(id))
        return File(folder, id)
    }
    private fun uri(file: File) = FileProvider.getUriForFile(activity, activity.packageName + ".incidents", file)
    private fun type(file: File) = extensions.entries.firstOrNull { it.value == file.extension }?.key ?: "application/octet-stream"
    private fun info(file: File, name: String = file.name): Map<String, Any> = mapOf(
        "id" to file.name, "path" to file.absolutePath, "name" to name.take(150),
        "type" to type(file), "size" to file.length())
    private fun totalSize() = folder.listFiles()?.sumOf { it.length() } ?: 0L

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (!call.method.startsWith("incident")) return false
        try {
            when (call.method) {
                "incidentCapture", "incidentPick", "incidentExport" -> {
                    check(pending == null) { "Finish the current media action first" }
                    if (call.method == "incidentExport") {
                        val ids = call.argument<List<String>>("ids") ?: emptyList()
                        require(ids.size <= 10)
                        ids.forEach { require(file(it).isFile) { "An attachment is missing" } }
                        val text = call.argument<String>("text") ?: ""
                        require(text.length <= 7000)
                        pending = Pending(result, "export", ids = ids, text = text)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("application/zip").putExtra(Intent.EXTRA_TITLE, "global-sos-incident.zip")
                        activity.startActivityForResult(intent, 709)
                    } else if (call.method == "incidentPick") {
                        pending = Pending(result, "pick")
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType("*/*").putExtra(Intent.EXTRA_MIME_TYPES, extensions.keys.toTypedArray())
                        activity.startActivityForResult(intent, 708)
                    } else {
                        check(totalSize() < totalLimit) { "Free some journal space before recording" }
                        val video = call.argument<Boolean>("video") == true
                        val target = File(folder, UUID.randomUUID().toString() + if (video) ".mp4" else ".jpg")
                        pending = Pending(result, "capture", target)
                        val output = uri(target)
                        val intent = Intent(if (video) MediaStore.ACTION_VIDEO_CAPTURE else MediaStore.ACTION_IMAGE_CAPTURE)
                            .putExtra(MediaStore.EXTRA_OUTPUT, output)
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        intent.clipData = ClipData.newRawUri("Incident recording", output)
                        if (video) intent.putExtra(MediaStore.EXTRA_DURATION_LIMIT, 60).putExtra(MediaStore.EXTRA_SIZE_LIMIT, limit)
                        activity.startActivityForResult(intent, 707)
                    }
                }
                "incidentInfo" -> {
                    val target = file(call.argument<String>("id") ?: "")
                    result.success(if (target.isFile) info(target) else null)
                }
                "incidentDelete" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    require(ids.size <= 500)
                    val files = ids.map(::file)
                    files.forEach { check(!it.exists() || it.delete()) { "Could not delete attachment" } }
                    result.success(null)
                }
                "incidentCleanup" -> {
                    val keep = (call.argument<List<String>>("ids") ?: emptyList()).toSet()
                    val before = System.currentTimeMillis() - 86400000L
                    folder.listFiles()?.filter { it.name !in keep && it.lastModified() < before }?.forEach { it.delete() }
                    result.success(null)
                }
                "incidentView" -> {
                    val target = file(call.argument<String>("id") ?: "")
                    require(target.isFile) { "Attachment is unavailable" }
                    val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri(target), type(target))
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    activity.startActivity(intent)
                    result.success(null)
                }
                "incidentShare" -> {
                    val ids = call.argument<List<String>>("ids") ?: emptyList()
                    require(ids.size <= 10)
                    val files = ids.map(::file)
                    require(files.all { it.isFile }) { "An attachment is unavailable" }
                    val text = call.argument<String>("text") ?: ""
                    require(text.length <= 7000)
                    val streams = ArrayList(files.map(::uri))
                    val intent = Intent(if (streams.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND)
                        .setType(if (streams.isEmpty()) "text/plain" else "*/*")
                        .putExtra(Intent.EXTRA_TEXT, text).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    if (streams.size > 1) intent.putParcelableArrayListExtra(Intent.EXTRA_STREAM, streams)
                    else if (streams.size == 1) intent.putExtra(Intent.EXTRA_STREAM, streams[0])
                    if (streams.isNotEmpty()) {
                        val clip = ClipData.newRawUri("Incident attachment", streams[0])
                        streams.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
                        intent.clipData = clip
                    }
                    activity.startActivity(Intent.createChooser(intent, "Share incident"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            if (pending?.result === result) { pending?.file?.delete(); pending = null }
            result.error("INCIDENT", error.message ?: "Media action unavailable", null)
        }
        return true
    }

    fun onActivityResult(code: Int, status: Int, data: Intent?): Boolean {
        if (code !in 707..709) return false
        val action = pending ?: return true
        if (status != Activity.RESULT_OK) {
            action.file?.delete(); pending = null; action.result.success(null); return true
        }
        Thread {
            var created: File? = action.file
            try {
                val response: Any? = when (action.action) {
                    "export" -> {
                        val destination = data?.data ?: error("Choose a destination")
                        val stream = activity.contentResolver.openOutputStream(destination) ?: error("Cannot open the document")
                        ZipOutputStream(stream).use { zip ->
                            zip.putNextEntry(ZipEntry("notes.txt")); zip.write(action.text.toByteArray(Charsets.UTF_8)); zip.closeEntry()
                            action.ids.forEach { id ->
                                zip.putNextEntry(ZipEntry(id)); file(id).inputStream().use { it.copyTo(zip) }; zip.closeEntry()
                            }
                        }
                        true
                    }
                    else -> {
                        var originalName: String? = null
                        if (action.action == "pick" || created?.length() == 0L) {
                            val selected = data?.data ?: error("The camera did not return a recording. Try choosing an existing file.")
                            val mime = activity.contentResolver.getType(selected)?.substringBefore(';') ?: error("Unknown media format")
                            val extension = extensions[mime] ?: error("Choose a supported photo or video")
                            created?.delete()
                            created = File(folder, UUID.randomUUID().toString() + "." + extension)
                            activity.contentResolver.query(selected, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                                if (cursor.moveToFirst()) originalName = cursor.getString(0)
                            }
                            val input = activity.contentResolver.openInputStream(selected) ?: error("Cannot open the selected file")
                            input.use { source -> created!!.outputStream().use { target ->
                                val buffer = ByteArray(65536); var size = 0L
                                while (true) {
                                    val count = source.read(buffer); if (count < 0) break
                                    size += count; check(size <= limit) { "Each attachment must be 100 MB or smaller" }
                                    target.write(buffer, 0, count)
                                }
                            } }
                        }
                        val target = created ?: error("Recording unavailable")
                        check(target.length() in 1..limit) { "Recording is empty or larger than 100 MB" }
                        check(totalSize() <= totalLimit) { "Journal storage limit reached (500 MB)" }
                        info(target, originalName ?: target.name)
                    }
                }
                activity.runOnUiThread {
                    if (pending !== action) { created?.delete(); return@runOnUiThread }
                    pending = null; action.result.success(response)
                }
            } catch (error: Exception) {
                created?.delete()
                activity.runOnUiThread {
                    if (pending === action) { pending = null; action.result.error("INCIDENT", error.message ?: "Could not save the media", null) }
                }
            }
        }.start()
        return true
    }

    fun close() {
        pending?.result?.success(null)
        pending?.file?.delete()
        pending = null
    }
}
