package org.globalsos.global_sos_ai

import android.app.Activity
import android.content.Intent
import android.location.Geocoder
import android.net.Uri
import android.speech.RecognizerIntent
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var speechResult: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        tts = TextToSpeech(this) { status -> ttsReady = status == TextToSpeech.SUCCESS }
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.globalsos/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "dial" -> {
                        val number = call.argument<String>("number") ?: ""
                        if (!Regex("\\+?[0-9]{2,18}").matches(number)) result.error("NUMBER", "Invalid number", null)
                        else { startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", number, null))); result.success(null) }
                    }
                    "listen" -> {
                        if (speechResult != null) result.error("BUSY", "Voice input already open", null)
                        else {
                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                                .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                                .putExtra(RecognizerIntent.EXTRA_LANGUAGE, call.argument<String>("language") ?: "en-IN")
                                .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                                .putExtra(RecognizerIntent.EXTRA_PROMPT, "Describe the help you need")
                            speechResult = result
                            try { startActivityForResult(intent, 701) } catch (e: Exception) { speechResult = null; throw e }
                        }
                    }
                    "speak" -> {
                        if (!ttsReady) result.error("VOICE", "Speech engine unavailable", null)
                        else {
                            val lang = tts!!.setLanguage(Locale.forLanguageTag(call.argument<String>("language") ?: "en-IN"))
                            if (lang < 0) result.error("LANGUAGE", "Install this language in Android text-to-speech settings", null)
                            else { tts!!.speak(call.argument<String>("text") ?: "", TextToSpeech.QUEUE_FLUSH, null, "sos"); result.success(null) }
                        }
                    }
                    "address" -> {
                        val lat = call.argument<Double>("lat") ?: 0.0
                        val lng = call.argument<Double>("lng") ?: 0.0
                        Thread {
                            try {
                                @Suppress("DEPRECATION")
                                val address = Geocoder(this, Locale.getDefault()).getFromLocation(lat, lng, 1)?.firstOrNull()
                                runOnUiThread { result.success(address?.let { mapOf("country" to it.countryCode, "region" to it.adminArea, "city" to it.locality) }) }
                            } catch (e: Exception) { runOnUiThread { result.error("ADDRESS", "Address lookup unavailable; use offline suggestion", null) } }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("DEVICE", "No compatible device application available", null) }
        }
    }
    @Deprecated("Legacy speech activity result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == 701) {
            speechResult?.success(if (resultCode == Activity.RESULT_OK) data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
            speechResult = null
        } else super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() { tts?.shutdown(); speechResult?.success(null); speechResult = null; super.onDestroy() }
}
