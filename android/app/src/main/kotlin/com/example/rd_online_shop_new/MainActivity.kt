package com.example.rd_online_shop_new

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val SHARE_CHANNEL = "rd_online_shop/shared_text"
    }

    private var shareChannel: MethodChannel? = null
    private var pendingSharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingSharedText = extractSharedText(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        shareChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHARE_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeSharedText" -> {
                        val text = pendingSharedText
                        pendingSharedText = null
                        result.success(text)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val text = extractSharedText(intent) ?: return
        val channel = shareChannel

        if (channel == null) {
            pendingSharedText = text
            return
        }

        pendingSharedText = text
        channel.invokeMethod("sharedText", text)
        pendingSharedText = null
    }

    private fun extractSharedText(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND) {
            return null
        }

        val mimeType = intent.type.orEmpty()
        if (!mimeType.startsWith("text/")) {
            return null
        }

        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)
            ?.toString()
            .orEmpty()
            .trim()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT).orEmpty().trim()

        val combined = listOf(subject, text)
            .filter { it.isNotEmpty() }
            .distinct()
            .joinToString("\n")
            .trim()

        return combined.ifEmpty { null }
    }
}
