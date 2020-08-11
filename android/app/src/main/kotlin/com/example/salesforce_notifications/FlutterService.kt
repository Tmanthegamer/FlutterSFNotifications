package com.example.salesforce_notifications

import android.content.Context
import android.content.Intent
import com.salesforce.androidsdk.app.SalesforceSDKManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterService constructor(val messagingChannel: MethodChannel) : MethodChannel.MethodCallHandler {
    var initialized : Boolean = false

    init {
        messagingChannel.setMethodCallHandler(this)
    }

    fun sendMessage(data: Map<String, String>) {
        MainActivity.instance.runOnUiThread(java.lang.Runnable {
            messagingChannel.invokeMethod(AndroidNotifications.CHANNEL_ID, data)
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        var success : String = ""
        try {
            if(call.method == "login") {
                if(!LoginSingleton.isLoggedIn()) {
                    val loginIntent = Intent(MainActivity.getContext(), SalesforceLoginActivity::class.java)
                    loginIntent.addCategory(Intent.CATEGORY_DEFAULT)
                    MainActivity.getContext().startActivity(loginIntent)
                    success = "Rerouting to Salesforce Login"
                }
                else {
                    success = "Already logged in"
                }
            } else if(call.method == "logout") {
                LoginSingleton.logout()
                success = "Successfully logged out"
            } else {
                result.notImplemented()
            }
        } catch (e : Exception) {
            result.error(e.cause.toString(), e.message, e.stackTrace)
        }
        if(success.isNotBlank()) {
            result.success(success)
        }
    }
}