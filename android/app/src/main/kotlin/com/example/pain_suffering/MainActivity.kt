package com.example.pain_suffering

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.telephony.SmsMessage
import android.content.pm.PackageManager 
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.gson.Gson 
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "app/native-code"
    private val eventChannel = "app/native-code-event" 
    private val SMS_PERMISSION_REQUEST_CODE = 101
    private val SEND_SMS_PERMISSION_REQUEST_CODE = 102 

    private lateinit var eventSink: EventChannel.EventSink 
    private lateinit var smsReceiver: BroadcastReceiver 

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for handling method calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInboxMessages" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
                        val messages = getInboxMessages()
                        if (messages.isNotEmpty()) {
                            result.success(messages)
                        } else {
                            result.error("UNAVAILABLE", "No messages found in inbox", null)
                        }
                    } else {
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), SMS_PERMISSION_REQUEST_CODE)
                        result.error("PERMISSION_DENIED", "SMS read permission not granted", null)
                    }
                }
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    sendSms(phoneNumber, message, result)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for listening to incoming messages
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events ?: return
                registerSmsReceiver() // Register receiver for new SMS
            }

            override fun onCancel(arguments: Any?) {
                // Handle cancellation of the stream if needed
                unregisterReceiver(smsReceiver) // Unregister the receiver when canceled
            }
        })
    }

    private fun registerSmsReceiver() {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    if (bundle != null) {
                        val pdus = bundle.get("pdus") as Array<*>
                        if (pdus.isNotEmpty()) {
                            val smsMessage = SmsMessage.createFromPdu(pdus[0] as ByteArray)
                            val from = smsMessage.displayOriginatingAddress
                            val messageBody = smsMessage.messageBody

                            // Create an instance of SmsMessageData
                            val latestMessageData = SmsMessageData(from, messageBody)

                            // Serialize the object to JSON
                            val gson = Gson()
                            val jsonMessage = gson.toJson(latestMessageData)

                            eventSink.success(jsonMessage) // Send the JSON object to Flutter
                        }
                    }
                }
            }
        }
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        registerReceiver(smsReceiver, filter) // Register the receiver
    }

    private fun getInboxMessages(): String {
        val smsUri = Uri.parse("content://sms/inbox")
        val cursor: Cursor? = contentResolver.query(smsUri, null, null, null, null)
        val messages = StringBuilder()

        cursor?.use {
            val indexBody = it.getColumnIndex("body")
            val indexAddress = it.getColumnIndex("address")

            while (it.moveToNext()) {
                val address = it.getString(indexAddress) ?: "Unknown"
                val body = it.getString(indexBody) ?: "No content"
                messages.append("From: $address\nMessage: $body\n\n")
            }
        }

        return messages.toString()
    }

    private fun sendSms(phoneNumber: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
            try {
                val smsManager = SmsManager.getDefault()
                smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                result.success("SMS sent successfully")
            } catch (e: Exception) {
                result.error("ERROR", "Failed to send SMS: ${e.message}", null)
            }
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), SEND_SMS_PERMISSION_REQUEST_CODE)
            result.error("PERMISSION_DENIED", "SMS send permission not granted", null)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // Permission granted for reading SMS
                } else {
                    // Permission denied, handle accordingly
                }
            }
            SEND_SMS_PERMISSION_REQUEST_CODE -> {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    // Permission granted for sending SMS
                } else {
                    // Permission denied, handle accordingly
                }
            }
        }
    }
}

// Data class to hold SMS message data
data class SmsMessageData(val from: String, val message: String)
