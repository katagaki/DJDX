package com.tsubuzaki.djdxgo

import android.app.Application

class DJDXApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
