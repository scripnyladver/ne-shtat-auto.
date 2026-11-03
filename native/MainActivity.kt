package com.neshtat.autocockpit

import android.content.ComponentName
import android.content.Intent
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "ru.neshtat.autocockpit/media"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "openAccess" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(true) }
                    "openMusic" -> { val launch = packageManager.getLaunchIntentForPackage("ru.yandex.music"); if (launch != null) { startActivity(launch); result.success(true) } else { result.error("APP_NOT_FOUND", "Яндекс Музыка не установлена", null) } }
                    "state" -> {
                        val c = activeController()
                        val m = c?.metadata
                        val state = c?.playbackState?.state
                        result.success(mapOf("title" to (m?.getString("android.media.metadata.TITLE") ?: ""), "artist" to (m?.getString("android.media.metadata.ARTIST") ?: ""), "playing" to (state == android.media.session.PlaybackState.STATE_PLAYING)))
                    }
                    "playPause", "next", "previous" -> {
                        val c = activeController()
                        if (c == null) result.error("NO_SESSION", "Нет активной медиасессии", null)
                        else {
                            when (call.method) {
                                "playPause" -> if (c.playbackState?.state == android.media.session.PlaybackState.STATE_PLAYING) c.transportControls.pause() else c.transportControls.play()
                                "next" -> c.transportControls.skipToNext()
                                "previous" -> c.transportControls.skipToPrevious()
                            }
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) { result.error("NO_PERMISSION", "Разреши доступ к уведомлениям НЕ ШТАТ", null) }
            catch (e: Exception) { result.error("MEDIA_ERROR", e.message, null) }
        }
    }
    private fun activeController(): MediaController? {
        val manager = getSystemService(MEDIA_SESSION_SERVICE) as MediaSessionManager
        return manager.getActiveSessions(ComponentName(this, CockpitNotificationListener::class.java)).firstOrNull()
    }
}
