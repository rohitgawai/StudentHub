package com.example.student_hub

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "student_hub/security"
    private val CHANNEL_MEDIA = "student_hub/mediastore"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disableSecure" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_MEDIA)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "insertDownload" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                            result.error(
                                "API_TOO_LOW",
                                "MediaStore.Downloads requires Android 10 (API 29)",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val name = call.argument<String>("name")
                                ?: throw IllegalArgumentException("name missing")
                            val bytes = call.argument<ByteArray>("bytes")
                                ?: throw IllegalArgumentException("bytes missing")
                            val resolver = applicationContext.contentResolver
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, name)
                                put(
                                    MediaStore.Downloads.MIME_TYPE,
                                    if (name.endsWith(".pdf", ignoreCase = true)) "application/pdf" else "text/csv"
                                )
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                                ?: throw IllegalStateException("MediaStore insert returned null")
                            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                                ?: throw IllegalStateException("Could not open output stream")
                            values.clear()
                            values.put(MediaStore.Downloads.IS_PENDING, 0)
                            resolver.update(uri, values, null, null)
                            result.success(uri.toString())
                        } catch (e: Exception) {
                            result.error("INSERT_FAILED", e.message, null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}