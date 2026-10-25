package com.arturoc.fitstreak

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives text shared from other apps (WhatsApp → Share → FitStreak) and
 * passes it to Flutter, which opens "Importar rutina" with it. Published
 * routine links (fitstreak://r/7K2QXM) arrive as their code, "FS-7K2QXM", and
 * summary links (fitstreak://summary/week) as "SUMMARY:week".
 *
 * It is a [FlutterFragmentActivity] because Health Connect asks for
 * permissions with registerForActivityResult.
 */
class MainActivity : FlutterFragmentActivity() {
    /** Text waiting for Flutter to take it, or null. */
    private var sharedText: String? = null

    /** The `fitstreak/share` channel, once the engine is ready. */
    private var channel: MethodChannel? = null

    /** Registers the channel; Flutter calls `takeSharedText` to read and clear the text. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitstreak/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    result.success(sharedText)
                    sharedText = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    /** Captures the intent the app was launched with. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        capture(intent)
    }

    /** Captures a share or link arriving while running and tells Flutter. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (capture(intent)) channel?.invokeMethod("sharedTextAvailable", null)
    }

    /**
     * Stores the text of [intent] for Flutter.
     *
     * @return whether the intent carried something for the app.
     */
    private fun capture(intent: Intent?): Boolean {
        val link = intent?.data
        // Icon shortcuts and voice: fitstreak://summary/today or /week.
        if (intent?.action == Intent.ACTION_VIEW && link?.scheme == "fitstreak" && link.host == "summary") {
            sharedText = "SUMMARY:" + (link.lastPathSegment ?: "today")
            return true
        }
        if (intent?.action == Intent.ACTION_VIEW && link?.scheme == "fitstreak" && link.host == "r") {
            sharedText = "FS-" + (link.lastPathSegment ?: return false)
            return true
        }
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return false
        sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return false
        return true
    }
}
