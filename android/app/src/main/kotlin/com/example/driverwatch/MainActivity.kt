package com.example.driverwatch

import android.content.Intent
import android.telephony.SmsManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.driverwatch/emergency"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "bringToFront") {
                val intent = Intent(this, MainActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            } else if (call.method == "sendSms") {
                val number = call.argument<String>("number")
                val message = call.argument<String>("message")
                
                if (number != null && message != null) {
                    try {
                        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            getSystemService(SmsManager::class.java)
                        } else {
                            SmsManager.getDefault()
                        }
                        
                        // 👇 SOLUÇÃO: Divide a mensagem longa/com emojis em várias partes para o Android não bloquear
                        val parts = smsManager.divideMessage(message)
                        smsManager.sendMultipartTextMessage(number, null, parts, null, null)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SMS_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "Número ou mensagem vazios", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}