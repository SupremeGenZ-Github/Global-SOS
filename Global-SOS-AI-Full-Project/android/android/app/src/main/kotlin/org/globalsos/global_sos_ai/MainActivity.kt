package org.globalsos.global_sos_ai

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
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
    private var fileResult: MethodChannel.Result? = null
    private var fileText: String? = null
    private var contactResult: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private var speechResult: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        tts = TextToSpeech(this) { status -> ttsReady = status == TextToSpeech.SUCCESS }
        MethodChannel(engine.dartExecutor.binaryMessenger, "org.globalsos/device").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "shareText" -> {
                        val share = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text") ?: "")
                        }
                        startActivity(Intent.createChooser(share, "Share with"))
                        result.success(null)
                    }
                    "saveTextFile" -> {
                        val name = call.argument<String>("name") ?: ""
                        val mime = call.argument<String>("mime") ?: ""
                        val text = call.argument<String>("text") ?: ""
                        require(name in setOf("global-sos-trip-plan.txt", "global-sos-check-in.ics", "global-sos-contact.vcf"))
                        require(mime in setOf("text/plain", "text/calendar", "text/vcard"))
                        require(text.isNotEmpty() && text.length <= 16000)
                        if (fileResult != null) {
                            result.error("BUSY", "File picker already open", null)
                        } else {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                                .addCategory(Intent.CATEGORY_OPENABLE)
                                .setType(mime)
                                .putExtra(Intent.EXTRA_TITLE, name)
                            fileResult = result
                            fileText = text
                            try {
                                startActivityForResult(intent, 704)
                            } catch (e: Exception) {
                                fileResult = null
                                fileText = null
                                throw e
                            }
                        }
                    }
                    "pickContact" -> {
                        if (contactResult != null) result.error("BUSY", "Contact picker already open", null)
                        else {
                            contactResult = result
                            try { startActivityForResult(Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI), 702) }
                            catch (e: Exception) { contactResult = null; throw e }
                        }
                    }
                    "requestSmsPermission" -> {
                        if (checkSelfPermission(Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) result.success(true)
                        else if (permissionResult != null) result.error("BUSY", "Permission request in progress", null)
                        else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.SEND_SMS), 703)
                        }
                    }
                    "sendSms" -> {
                        val recipient = call.argument<String>("recipient") ?: ""
                        val message = call.argument<String>("message") ?: ""
                        require(Regex("\\+[1-9][0-9]{7,14}").matches(recipient)) { "Use an international trusted-contact number" }
                        require(message.isNotBlank() && message.length <= 1000) { "Invalid message" }
                        if (checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) result.error("PERMISSION", "SMS permission denied", null)
                        else {
                            @Suppress("DEPRECATION")
                            val manager = if (Build.VERSION.SDK_INT >= 31) getSystemService(SmsManager::class.java) else SmsManager.getDefault()
                            manager.sendMultipartTextMessage(recipient, null, manager.divideMessage(message), null, null)
                            result.success(null)
                        }
                    }
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
        if (requestCode == 704) {
            val pending = fileResult
            val text = fileText
            fileResult = null
            fileText = null
            val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
            if (uri == null || pending == null || text == null) {
                pending?.success(false)
                return
            }
            Thread {
                try {
                    val stream = contentResolver.openOutputStream(uri)
                        ?: throw IllegalStateException("Document could not be opened")
                    stream.bufferedWriter(Charsets.UTF_8).use { it.write(text) }
                    runOnUiThread { pending.success(true) }
                } catch (e: Exception) {
                    runOnUiThread { pending.error("FILE", "Unable to save selected document", null) }
                }
            }.start()
        } else if (requestCode == 702) {
            try {
                val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
                val contact = uri?.let {
                    contentResolver.query(it, arrayOf(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME, ContactsContract.CommonDataKinds.Phone.NUMBER), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) mapOf("name" to cursor.getString(0), "phone" to cursor.getString(1)) else null
                    }
                }
                contactResult?.success(contact)
            } catch (e: Exception) { contactResult?.error("CONTACT", "Unable to read selected contact", null) }
            finally { contactResult = null }
        } else if (requestCode == 701) {
            speechResult?.success(if (resultCode == Activity.RESULT_OK) data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull() else null)
            speechResult = null
        } else super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 703) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
    override fun onDestroy() { fileResult?.success(false); fileResult = null; fileText = null; contactResult?.success(null); contactResult = null; permissionResult?.success(false); permissionResult = null; tts?.shutdown(); speechResult?.success(null); speechResult = null; super.onDestroy() }
}
