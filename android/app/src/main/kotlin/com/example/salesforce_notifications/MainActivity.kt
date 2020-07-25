package com.example.salesforce_notifications

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.salesforce.androidsdk.mobilesync.app.MobileSyncSDKManager

class MainActivity: FlutterActivity() {

  private val FEATURE_APP_USES_KOTLIN = "KT"

  companion object {
    private val NOTIFICATION_CHANNEL = "flutter.module.com/channelcommunication"
    lateinit var instance : MainActivity

    private lateinit var message_channel : MethodChannel
    private lateinit var theContext : Context

    fun getContext() : Context {
      return theContext
    }
  }

  override fun onCreate(savedInstanceBundle: Bundle?) {
    super.onCreate(savedInstanceBundle)

    MobileSyncSDKManager.getInstance().setViewNavigationVisibility(this)
  }

  override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Initialize static members
    instance = this
    theContext = applicationContext
    
    // Initialize the Flutter Service for platform messages
    FlutterService.getInstance(MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL))

    MobileSyncSDKManager.initNative(applicationContext, MainActivity::class.java)
    MobileSyncSDKManager.getInstance().registerUsedAppFeature(FEATURE_APP_USES_KOTLIN)

    /*
      * Uncomment the following line to enable IDP login flow. This will allow the user to
      * either authenticate using the current app or use a designated IDP app for login.
      * Replace 'idpAppURIScheme' with the URI scheme of the IDP app meant to be used.
      */
    //MobileSyncSDKManager.getInstance().idpAppURIScheme = idpAppURIScheme

    /*
      * Un-comment the line below to enable push notifications in this app.
      * Replace 'pnInterface' with your implementation of 'PushNotificationInterface'.
      * Add your Google package ID in 'bootconfig.xml', as the value
      * for the key 'androidPushNotificationClientId'.
		 */
    MobileSyncSDKManager.getInstance().pushNotificationReceiver = AndroidNotifications()
  }
}
