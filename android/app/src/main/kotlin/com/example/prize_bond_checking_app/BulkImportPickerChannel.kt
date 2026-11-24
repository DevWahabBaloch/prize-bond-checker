package com.example.prize_bond_checking_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.AtomicFile
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors

internal class BulkImportPickerChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "prize_bond/android_bulk_import")
    private val directory = File(activity.noBackupFilesDir, "bulk_import")
    private val requests = activity.getSharedPreferences("bulk_import_requests", Activity.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private var closed = false

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                val owner = call.argument<String>("owner")
                require(owner != null && accountId.matches(owner))
                when (call.method) {
                    "denomination" -> result.success(read(owner)?.getString("denomination"))
                    "open" -> {
                        val draft = requireNotNull(call.argument<Map<String, String>>("draft"))
                        val code = open(owner, draft)
                        result.success(code)
                    }
                    "load" -> load(owner, result)
                    "clear" -> {
                        val code = requireNotNull(call.argument<Int>("request"))
                        val current = read(owner)
                        if (current != null && current.getInt("request") == code) {
                            receipt(owner).delete()
                            if (read(owner) != null) throw IOException("Could not remove import receipt")
                            releaseUnusedUri(current)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                Log.w(TAG, "Bulk import operation failed: ${error.javaClass.simpleName}")
                result.error("bulk_import", "Could not access the saved file selection.", null)
            }
        }
    }

    private fun open(owner: String, draft: Map<String, String>): Int {
        val previous = read(owner)
        val code = requests.getInt("last", FIRST_REQUEST) + 1
        check(code > FIRST_REQUEST && requests.edit().putInt("last", code).commit())

        val row = JSONObject()
            .put("request", code)
            .put("status", "picking")
            .put("denomination", requireNotNull(draft["denomination"]))
            .put("paste", bounded(draft["paste"]))
            .put("fileName", draft["fileName"]?.take(MAX_NAME))
            .put("fileContent", bounded(draft["fileContent"]))
        write(owner, row)
        if (previous != null) releaseUnusedUri(previous)

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            // Some local providers label CSV downloads as generic binary data.
            // Validate the extension and bounded UTF-8 content when we read the document.
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf(
                "text/*", "application/csv", "application/x-csv",
                "application/vnd.ms-excel", "application/octet-stream",
            ))
            putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, code)
        } catch (error: Exception) {
            Log.w(TAG, "Could not open document picker: ${error.javaClass.simpleName}")
            write(owner, row.put("status", "failed"))
        }
        return code
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode <= FIRST_REQUEST) return false
        val entry = owners().firstNotNullOfOrNull { owner ->
            runCatching { read(owner) }.getOrNull()
                ?.takeIf { it.optInt("request") == requestCode }
                ?.let { owner to it }
        } ?: return false
        val (owner, row) = entry
        if (row.optString("status") != "picking") return true
        try {
            val uri = data?.data
            when {
                resultCode == Activity.RESULT_CANCELED -> write(owner, row.put("status", "cancelled"))
                resultCode != Activity.RESULT_OK || uri?.scheme != "content" ->
                    write(owner, row.put("status", "failed"))
                else -> {
                    // Record the grant's owner before retaining it. Android can recreate
                    // the Flutter activity while the system document picker is still open.
                    write(owner, row.put("status", "selected").put("uri", uri.toString()))
                    try {
                        activity.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    } catch (_: SecurityException) {
                        row.remove("uri")
                        write(owner, row.put("status", "failed"))
                    }
                }
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not save picker result: ${error.javaClass.simpleName}")
        }
        channel.invokeMethod("changed", requestCode)
        return true
    }

    private fun load(owner: String, result: MethodChannel.Result) {
        val row = read(owner)
        if (row == null) {
            result.success(null)
            return
        }
        val reply = mutableMapOf<String, Any?>(
            "request" to row.getInt("request"),
            "status" to row.getString("status"),
            "paste" to row.optional("paste"),
            "fileName" to row.optional("fileName"),
            "fileContent" to row.optional("fileContent"),
        )
        if (row.getString("status") != "selected") {
            result.success(reply)
            return
        }
        val uri = Uri.parse(row.getString("uri"))
        worker.execute {
            try {
                readDocument(uri, reply)
            } catch (error: Exception) {
                Log.w(TAG, "Could not read selected document: ${error.javaClass.simpleName}")
                reply["error"] = "Could not read the selected file. Choose a local TXT or CSV file and try again."
            }
            activity.runOnUiThread {
                if (!closed) result.success(reply)
            }
        }
    }

    private fun readDocument(uri: Uri, reply: MutableMap<String, Any?>) {
        val resolver = activity.contentResolver
        val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else null
        }
        if (name.isNullOrBlank() || name.substringAfterLast('.', "").lowercase() !in setOf("txt", "csv")) {
            reply["error"] = "Choose a local TXT or CSV file."
            return
        }
        val output = ByteArrayOutputStream()
        val buffer = ByteArray(8192)
        val stream = resolver.openInputStream(uri) ?: throw IOException("No document stream")
        stream.use {
            while (true) {
                val count = it.read(buffer)
                if (count < 0) break
                if (count > MAX_BYTES - output.size()) {
                    reply["error"] = "Use at most 256 KiB of TXT, CSV, or pasted input per batch."
                    return
                }
                output.write(buffer, 0, count)
            }
        }
        reply["selectedName"] = name.take(MAX_NAME)
        reply["selectedBytes"] = output.toByteArray()
    }

    private fun owners() = directory.listFiles().orEmpty()
        .map { it.name.removeSuffix(".json") }
        .filter { accountId.matches(it) }

    private fun receipt(owner: String) = AtomicFile(File(directory, "$owner.json"))

    private fun read(owner: String): JSONObject? = try {
        JSONObject(receipt(owner).readFully().toString(Charsets.UTF_8))
    } catch (_: FileNotFoundException) {
        null
    }

    private fun write(owner: String, row: JSONObject) {
        val file = receipt(owner)
        val output = file.startWrite()
        try {
            output.write(row.toString().toByteArray())
            output.fd.sync()
            file.finishWrite(output)
        } catch (error: Exception) {
            file.failWrite(output)
            throw error
        }
    }

    private fun releaseUnusedUri(row: JSONObject) {
        val uri = row.optional("uri") ?: return
        try {
            if (owners().none { read(it)?.optional("uri") == uri }) {
                activity.contentResolver.releasePersistableUriPermission(Uri.parse(uri), Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not release import grant: ${error.javaClass.simpleName}")
        }
    }

    private fun JSONObject.optional(key: String): String? = if (isNull(key)) null else getString(key)

    private fun bounded(value: String?): String? {
        require(value == null || value.toByteArray().size <= MAX_BYTES)
        return value
    }

    fun close() {
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
    }

    private companion object {
        const val TAG = "BulkImportPicker"
        const val FIRST_REQUEST = 0x425000
        const val MAX_BYTES = 256 * 1024
        const val MAX_NAME = 255
        val accountId = Regex("[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}")
    }
}
