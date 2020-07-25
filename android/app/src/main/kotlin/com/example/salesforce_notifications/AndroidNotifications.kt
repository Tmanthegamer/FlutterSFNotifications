package com.example.salesforce_notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.content.ContextCompat.getSystemService
import com.example.salesforce_notifications.MainActivity
import com.example.salesforce_notifications.R
import com.salesforce.androidsdk.push.PushNotificationInterface
import io.flutter.plugin.common.MethodChannel


class AndroidNotifications : PushNotificationInterface {

    companion object {
        lateinit var CHANNEL_ID : String
    }

    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel
            var context = MainActivity.getContext()
            CHANNEL_ID = context.getString(R.string.channel_name)

            val name = MainActivity.getContext().getString(R.string.channel_name)
            val descriptionText = R.string.channel_description
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val mChannel = NotificationChannel(CHANNEL_ID, name, importance)
            mChannel.description = MainActivity.getContext().getString(descriptionText)
            // Register the channel with the system; you can't change the importance
            // or other notification behaviors after this
            val notificationManager: NotificationManager? = getSystemService(MainActivity.getContext(), NotificationManager::class.java)

            notificationManager!!.createNotificationChannel(mChannel)
        }
    }

    override fun onPushMessageReceived(data: Map<String, String>) {
        FlutterService.getInstance()!!.sendMessage(data)
    }
}