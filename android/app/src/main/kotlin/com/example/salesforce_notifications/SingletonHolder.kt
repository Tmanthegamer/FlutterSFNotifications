package com.example.salesforce_notifications

open class SingletonHolder<out T: Any, in A>(creator: (A) -> T) {

    private var creator: ((A) -> T)? = creator
    @Volatile private var instance: T? = null

    fun getInstance() : T? {
        if(instance == null) {
            throw SingletonNotInitiatedException()
        }
        return instance
    }

    fun getInstance(arg: A) : T {
        val checkInstance = instance
        if(checkInstance != null) {
            return checkInstance
        }

        return synchronized(this) {
            val checkInstanceAgain = instance
            if (checkInstanceAgain != null) {
                checkInstanceAgain
            } else {
                val created = creator!!(arg)
                instance = created
                creator = null
                created
            }
        }
    }
    class SingletonNotInitiatedException : Exception(message = "Singleton was not initialized before usage.") {}
}