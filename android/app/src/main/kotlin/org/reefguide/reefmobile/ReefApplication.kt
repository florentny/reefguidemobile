package org.reefguide.reefmobile

import android.content.Context
import io.flutter.FlutterInjector
import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager
import com.google.android.play.core.splitcompat.SplitCompat

class ReefApplication : FlutterApplication() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        SplitCompat.install(this)
    }

    override fun onCreate() {
        super.onCreate()
        // FlutterInjector doesn't auto-register a DeferredComponentManager unless
        // the app extends FlutterPlayStoreSplitApplication. Without this, our
        // DeferredAssetsPlugin.registerAssets call finds a null manager and the
        // engine's AssetManager never gets refreshed after splits install, so
        // Image.asset() for pix1..pix4 assets fails silently.
        FlutterInjector.setInstance(
            FlutterInjector.Builder()
                .setDeferredComponentManager(
                    PlayStoreDeferredComponentManager(this, null)
                )
                .build()
        )
    }
}
