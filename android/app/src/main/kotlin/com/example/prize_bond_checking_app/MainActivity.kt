package com.example.prize_bond_checking_app

import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pinKeys: PinKeyStoreChannel? = null
    private var bulkPicker: BulkImportPickerChannel? = null
    private var notificationChannels: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        pinKeys = PinKeyStoreChannel(messenger)
        bulkPicker = BulkImportPickerChannel(this, messenger)
        notificationChannels = MethodChannel(messenger, "prize_bond/android_notifications").also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "isDrawChannelEnabled") {
                    result.success(isDrawChannelEnabled())
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    @Deprecated("FlutterActivity forwards Android activity results through this callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bulkPicker?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun isDrawChannelEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val manager = getSystemService(NotificationManager::class.java)
        val channel = manager.getNotificationChannel("draw_channel") ?: return false
        if (channel.importance == NotificationManager.IMPORTANCE_NONE) return false
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.P ||
            channel.group == null || manager.getNotificationChannelGroup(channel.group)?.isBlocked != true
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pinKeys?.close()
        pinKeys = null
        bulkPicker?.close()
        bulkPicker = null
        notificationChannels?.setMethodCallHandler(null)
        notificationChannels = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
