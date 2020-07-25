package com.example.salesforce_notifications

import com.salesforce.androidsdk.rest.RestClient
import android.content.Context
import com.salesforce.androidsdk.app.SalesforceSDKManager

object LoginSingleton {
    var client: RestClient? = null

    fun isLoggedIn() : Boolean {
        return this.client != null
    }

    fun logout() {
        SalesforceSDKManager.getInstance().logout(MainActivity.instance)
    }
}