package com.smartclass.smart_class

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import android.speech.RecognizerIntent
import androidx.core.content.FileProvider
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private val mediaOpenChannel = "smart_class/media_open"
    private val voiceChannel = "smart_class/voice_record"
    private val shareChannel = "smart_class/share_receive"
    private val shareEvents = "smart_class/share_receive_events"

    private var recorder: MediaRecorder? = null
    private var recordPath: String? = null
    private var shareEventSink: EventChannel.EventSink? = null
    private val pendingShares = mutableListOf<Map<String, String>>()
    private var pickPendingResult: MethodChannel.Result? = null
    private var speechPendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_PICK_WECHAT = 0x57C1
        private const val REQ_SPEECH = 0x57C2
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        handleIncomingShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingShare(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, shareEvents)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                    flushPendingShares()
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePending" -> {
                        val copy = ArrayList(pendingShares)
                        pendingShares.clear()
                        result.success(copy)
                    }
                    "pickFromWeChat" -> {
                        // 兼容旧调用：走系统选择器
                        startPickFromWeChat(result)
                    }
                    "pickWeChatFiles" -> {
                        // 开源 ZFileManager：微信分类页 → 选文件 → 确认返回
                        startZFileWeChatPick(result)
                    }
                    "listWeChatFiles" -> {
                        try {
                            result.success(listWeChatFiles())
                        } catch (e: Exception) {
                            result.error("list_failed", e.message, null)
                        }
                    }
                    "importWeChatPaths" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        try {
                            result.success(importWeChatPaths(paths))
                        } catch (e: Exception) {
                            result.error("import_failed", e.message, null)
                        }
                    }
                    "hasAllFilesAccess" -> {
                        result.success(hasAllFilesAccess())
                    }
                    "openAllFilesSettings" -> {
                        result.success(openAllFilesSettings())
                    }
                    "openWeChat" -> {
                        result.success(openWeChat())
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaOpenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openWithChooser" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "*/*"
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openWithChooser(path, mime)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("open_failed", e.message, null)
                        }
                    }
                    "shareWithChooser" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "*/*"
                        val title = call.argument<String>("title") ?: "分享到微信等"
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "path required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareWithChooser(path, mime, title)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, voiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            result.success(startRecording())
                        } catch (e: Exception) {
                            result.error("record_start", e.message, null)
                        }
                    }
                    "stop" -> {
                        try {
                            result.success(stopRecording())
                        } catch (e: Exception) {
                            result.error("record_stop", e.message, null)
                        }
                    }
                    "cancel" -> {
                        try {
                            cancelRecording()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("record_cancel", e.message, null)
                        }
                    }
                    "recognizeSpeech" -> {
                        startSpeechRecognize(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQ_SPEECH) {
            val pending = speechPendingResult
            speechPendingResult = null
            if (pending == null) {
                @Suppress("DEPRECATION")
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data == null) {
                pending.success("")
                return
            }
            val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            pending.success(matches?.firstOrNull()?.trim().orEmpty())
            return
        }
        if (requestCode == REQ_PICK_WECHAT) {
            val pending = pickPendingResult
            pickPendingResult = null
            if (pending == null) {
                @Suppress("DEPRECATION")
                super.onActivityResult(requestCode, resultCode, data)
                return
            }
            if (resultCode != Activity.RESULT_OK || data == null) {
                pending.success(emptyList<Map<String, String>>())
                return
            }
            val uris = linkedSetOf<Uri>()
            data.data?.let { uris.add(it) }
            data.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) {
                    clip.getItemAt(i).uri?.let { uris.add(it) }
                }
            }
            val out = ArrayList<Map<String, String>>()
            for (uri in uris) {
                try {
                    copyUriToCache(uri)?.let { out.add(it) }
                } catch (_: Exception) {
                }
            }
            pending.success(out)
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        try {
            cancelRecording()
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    private fun openAllFilesSettings(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val uri = Uri.parse("package:$packageName")
                startActivity(
                    Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, uri)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } else {
                startActivity(
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.parse("package:$packageName"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            }
            true
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun weChatDownloadDirs(): List<File> {
        val out = linkedSetOf<File>()
        val bases = mutableListOf<File>()
        Environment.getExternalStorageDirectory()?.let { bases.add(it) }
        bases.add(File("/storage/emulated/0"))
        bases.add(File("/sdcard"))
        for (base in bases) {
            out.add(File(base, "Android/data/com.tencent.mm/MicroMsg/Download"))
            out.add(File(base, "tencent/MicroMsg/Download"))
            out.add(File(base, "Tencent/MicroMsg/Download"))
            out.add(File(base, "Download/WeiXin"))
            out.add(File(base, "Download/WeChat"))
            val micro = File(base, "Android/data/com.tencent.mm/MicroMsg")
            if (micro.isDirectory) {
                micro.listFiles()?.forEach { child ->
                    if (child.isDirectory && child.name.equals("Download", ignoreCase = true)) {
                        out.add(child)
                    }
                }
            }
        }
        return out.filter { it.exists() && it.isDirectory }
    }

    private fun listWeChatFiles(): List<Map<String, Any>> {
        val files = mutableListOf<File>()
        for (dir in weChatDownloadDirs()) {
            dir.listFiles()?.forEach { f ->
                if (f.isFile && f.canRead() && f.length() > 0L) {
                    files.add(f)
                }
            }
        }
        files.sortByDescending { it.lastModified() }
        return files.take(400).map { f ->
            mapOf(
                "path" to f.absolutePath,
                "name" to f.name,
                "size" to f.length(),
                "modified" to f.lastModified(),
            )
        }
    }

    private fun importWeChatPaths(paths: List<String>): List<Map<String, String>> {
        val out = ArrayList<Map<String, String>>()
        val dir = File(cacheDir, "shared_inbox")
        if (!dir.exists()) dir.mkdirs()
        for (raw in paths) {
            val src = File(raw)
            if (!src.isFile || !src.canRead()) continue
            val safe = src.name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            val dest = File(dir, "${System.currentTimeMillis()}_$safe")
            try {
                FileInputStream(src).use { input ->
                    FileOutputStream(dest).use { output -> input.copyTo(output) }
                }
                out.add(mapOf("path" to dest.absolutePath, "name" to safe))
            } catch (_: Exception) {
            }
        }
        return out
    }

    private fun startZFileWeChatPick(result: MethodChannel.Result) {
        if (pickPendingResult != null) {
            result.error("busy", "picker already open", null)
            return
        }
        pickPendingResult = result
        try {
            WeChatZFileHelper.pick(this) { list ->
                val pending = pickPendingResult
                pickPendingResult = null
                if (pending == null) return@pick
                if (list.isNullOrEmpty()) {
                    pending.success(emptyList<Map<String, String>>())
                    return@pick
                }
                val paths = list.mapNotNull { bean ->
                    bean.filePath.takeIf { it.isNotBlank() }
                }
                pending.success(importWeChatPaths(paths))
            }
        } catch (e: Exception) {
            pickPendingResult = null
            result.error("pick_failed", e.message, null)
        }
    }

    /** 备用：系统/华为文件选择器（微信本身不提供 GET_CONTENT）。 */
    private fun startPickFromWeChat(result: MethodChannel.Result) {
        if (pickPendingResult != null) {
            result.error("busy", "picker already open", null)
            return
        }
        pickPendingResult = result
        try {
            val base = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                putExtra(Intent.EXTRA_LOCAL_ONLY, true)
            }
            val flags = PackageManager.MATCH_DEFAULT_ONLY
            val wechat = Intent(base).setPackage("com.tencent.mm")
            if (packageManager.resolveActivity(wechat, flags) != null) {
                @Suppress("DEPRECATION")
                startActivityForResult(wechat, REQ_PICK_WECHAT)
                return
            }
            val chooser = Intent.createChooser(base, "从微信选择文件")
            // 若微信已安装，尽量把微信放到选择面板前列
            if (isWeChatInstalled()) {
                chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(wechat))
            }
            @Suppress("DEPRECATION")
            startActivityForResult(chooser, REQ_PICK_WECHAT)
        } catch (e: Exception) {
            pickPendingResult = null
            result.error("pick_failed", e.message, null)
        }
    }

    private fun isWeChatInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo("com.tencent.mm", 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openWeChat(): Boolean {
        return try {
            val launch = packageManager.getLaunchIntentForPackage("com.tencent.mm")
            if (launch != null) {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launch)
                true
            } else {
                val uri = Uri.parse("weixin://")
                startActivity(Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun handleIncomingShare(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        val uris = mutableListOf<Uri>()
        when (action) {
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                if (uri != null) uris.add(uri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                if (list != null) uris.addAll(list)
            }
            Intent.ACTION_VIEW -> {
                intent.data?.let { uris.add(it) }
            }
            else -> return
        }
        for (uri in uris) {
            try {
                val copied = copyUriToCache(uri) ?: continue
                emitShare(copied)
            } catch (_: Exception) {
            }
        }
        // Avoid re-processing the same intent after rotation.
        intent.action = null
        intent.removeExtra(Intent.EXTRA_STREAM)
    }

    private fun copyUriToCache(uri: Uri): Map<String, String>? {
        val name = queryDisplayName(uri) ?: "wechat_${System.currentTimeMillis()}"
        val safe = name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
        val dir = File(cacheDir, "shared_inbox")
        if (!dir.exists()) dir.mkdirs()
        val out = File(dir, "${System.currentTimeMillis()}_$safe")
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(out).use { output -> input.copyTo(output) }
        } ?: return null
        return mapOf("path" to out.absolutePath, "name" to safe)
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, null, null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) cursor.getString(idx) else null
            } else {
                null
            }
        } catch (_: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun emitShare(item: Map<String, String>) {
        val sink = shareEventSink
        if (sink != null) {
            sink.success(item)
        } else {
            pendingShares.add(item)
        }
    }

    private fun flushPendingShares() {
        val sink = shareEventSink ?: return
        val copy = ArrayList(pendingShares)
        pendingShares.clear()
        for (item in copy) {
            sink.success(item)
        }
    }

    private fun startSpeechRecognize(result: MethodChannel.Result) {
        if (speechPendingResult != null) {
            result.error("busy", "speech already in progress", null)
            return
        }
        speechPendingResult = result
        try {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(
                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                )
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
                putExtra(RecognizerIntent.EXTRA_PROMPT, "请说出你的待办")
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQ_SPEECH)
        } catch (_: ActivityNotFoundException) {
            speechPendingResult = null
            result.error("unavailable", "设备不支持语音识别，请安装谷歌语音服务", null)
        } catch (e: Exception) {
            speechPendingResult = null
            result.error("speech_failed", e.message, null)
        }
    }

    private fun startRecording(): String {
        if (recorder != null) {
            throw IllegalStateException("already recording")
        }
        val dir = File(cacheDir, "voice_records")
        if (!dir.exists()) dir.mkdirs()
        val file = File(dir, "work_log_${System.currentTimeMillis()}.m4a")
        val path = file.absolutePath

        @Suppress("DEPRECATION")
        val mr = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            MediaRecorder()
        }
        try {
            mr.setAudioSource(MediaRecorder.AudioSource.MIC)
            mr.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mr.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mr.setAudioSamplingRate(16000)
            mr.setAudioEncodingBitRate(64000)
            mr.setOutputFile(path)
            mr.prepare()
            mr.start()
        } catch (e: Exception) {
            try {
                mr.release()
            } catch (_: Exception) {
            }
            throw e
        }
        recorder = mr
        recordPath = path
        return path
    }

    private fun stopRecording(): String {
        val mr = recorder ?: throw IllegalStateException("not recording")
        val path = recordPath ?: throw IllegalStateException("no path")
        try {
            mr.stop()
        } finally {
            try {
                mr.release()
            } catch (_: Exception) {
            }
            recorder = null
            recordPath = null
        }
        return path
    }

    private fun cancelRecording() {
        val mr = recorder ?: return
        try {
            mr.stop()
        } catch (_: Exception) {
        }
        try {
            mr.release()
        } catch (_: Exception) {
        }
        recorder = null
        val path = recordPath
        recordPath = null
        if (path != null) {
            try {
                File(path).delete()
            } catch (_: Exception) {
            }
        }
    }

    private fun openWithChooser(path: String, mime: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("file does not exist: $path")
        }
        val authority = "$packageName.fileProvider.com.crazecoder.openfile"
        val uri = FileProvider.getUriForFile(this, authority, file)
        val view = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mime)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val flags = PackageManager.MATCH_DEFAULT_ONLY
        val matches = packageManager.queryIntentActivities(view, flags)
        for (info in matches) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }

        val chooser = Intent.createChooser(view, "选择应用打开").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(chooser)
    }

    private fun shareWithChooser(path: String, mime: String, title: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("file does not exist: $path")
        }
        val authority = "$packageName.fileProvider.com.crazecoder.openfile"
        val uri = FileProvider.getUriForFile(this, authority, file)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(contentResolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        for (pkg in listOf("com.tencent.mm", "com.tencent.mobileqq")) {
            try {
                grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {
            }
        }

        val flags = PackageManager.MATCH_DEFAULT_ONLY
        val matches = packageManager.queryIntentActivities(send, flags)
        for (info in matches) {
            grantUriPermission(
                info.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        }

        val chooser = Intent.createChooser(send, title).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        val wechat = Intent(Intent.ACTION_SEND).apply {
            setPackage("com.tencent.mm")
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            clipData = ClipData.newUri(contentResolver, file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        if (packageManager.resolveActivity(wechat, flags) != null) {
            chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(wechat))
        }

        startActivity(chooser)
    }
}
