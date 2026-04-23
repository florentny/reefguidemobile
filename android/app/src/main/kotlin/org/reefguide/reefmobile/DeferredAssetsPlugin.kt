package org.reefguide.reefmobile

import android.content.Context
import com.google.android.play.core.splitinstall.SplitInstallManager
import com.google.android.play.core.splitinstall.SplitInstallManagerFactory
import com.google.android.play.core.splitinstall.SplitInstallRequest
import com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
import com.google.android.play.core.splitinstall.model.SplitInstallSessionStatus
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DeferredAssetsPlugin(context: Context, flutterEngine: FlutterEngine) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val splitInstallManager: SplitInstallManager =
        SplitInstallManagerFactory.create(context.applicationContext)
    private val sessionIdToModules = mutableMapOf<Int, List<String>>()
    private var eventSink: EventChannel.EventSink? = null

    private val listener = SplitInstallStateUpdatedListener { state ->
        val modules = sessionIdToModules[state.sessionId()]
            ?: state.moduleNames()?.toList()
            ?: return@SplitInstallStateUpdatedListener
        emit(
            modules = modules,
            status = statusName(state.status()),
            bytesDownloaded = state.bytesDownloaded(),
            totalBytes = state.totalBytesToDownload(),
            errorCode = state.errorCode(),
        )
        when (state.status()) {
            SplitInstallSessionStatus.INSTALLED,
            SplitInstallSessionStatus.FAILED,
            SplitInstallSessionStatus.CANCELED -> sessionIdToModules.remove(state.sessionId())
        }
    }

    init {
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
        splitInstallManager.registerListener(listener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installedModules" -> result.success(splitInstallManager.installedModules.toList())
            "installAll" -> handleInstallAll(call, result)
            "registerAssets" -> handleRegisterAssets(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Wires newly-installed asset modules into the Flutter engine's AssetManager
     * so rootBundle / Image.asset can see them. Flutter's built-in
     * DeferredComponent.installDeferredComponent() path for already-installed
     * modules is unreliable: startInstall() can fail with SplitInstallException
     * and the Dart future never completes (the failure listener omits
     * channel.completeInstallError). loadAssets() is the authoritative public
     * hook — it calls flutterJNI.updateJavaAssetManager(...) directly.
     */
    private fun handleRegisterAssets(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val names = (call.argument<List<Any?>>("names") ?: emptyList<Any?>())
            .filterIsInstance<String>()
        val manager = FlutterInjector.instance().deferredComponentManager()
        if (manager == null) {
            result.error("NO_MANAGER", "DeferredComponentManager not available", null)
            return
        }
        try {
            for (name in names) {
                manager.loadAssets(-1, name)
            }
            result.success(true)
        } catch (e: Throwable) {
            result.error("REGISTER_FAILED", e.message, null)
        }
    }

    private fun handleInstallAll(call: MethodCall, result: MethodChannel.Result) {
        @Suppress("UNCHECKED_CAST")
        val names = (call.argument<List<Any?>>("names") ?: emptyList<Any?>())
            .filterIsInstance<String>()
        if (names.isEmpty()) {
            result.error("ARG", "missing or empty names", null)
            return
        }
        val installed = splitInstallManager.installedModules
        val toInstall = names.filter { it !in installed }
        if (toInstall.isEmpty()) {
            emit(
                modules = names,
                status = "INSTALLED",
                bytesDownloaded = 0,
                totalBytes = 0,
                errorCode = 0,
            )
            result.success(true)
            return
        }
        val request = SplitInstallRequest.newBuilder()
            .apply { toInstall.forEach { addModule(it) } }
            .build()
        splitInstallManager.startInstall(request)
            .addOnSuccessListener { sessionId ->
                sessionIdToModules[sessionId] = toInstall
                result.success(true)
            }
            .addOnFailureListener { e ->
                emit(
                    modules = toInstall,
                    status = "FAILED",
                    bytesDownloaded = 0,
                    totalBytes = 0,
                    errorCode = -1,
                    error = e.message,
                )
                result.error("INSTALL_FAILED", e.message, null)
            }
    }

    private fun emit(
        modules: List<String>,
        status: String,
        bytesDownloaded: Long,
        totalBytes: Long,
        errorCode: Int,
        error: String? = null,
    ) {
        val payload = mapOf(
            "modules" to modules,
            "status" to status,
            "bytesDownloaded" to bytesDownloaded,
            "totalBytesToDownload" to totalBytes,
            "errorCode" to errorCode,
            "error" to error,
            "installedModules" to splitInstallManager.installedModules.toList(),
        )
        eventSink?.success(payload)
    }

    private fun statusName(code: Int): String = when (code) {
        SplitInstallSessionStatus.PENDING -> "PENDING"
        SplitInstallSessionStatus.REQUIRES_USER_CONFIRMATION -> "REQUIRES_USER_CONFIRMATION"
        SplitInstallSessionStatus.DOWNLOADING -> "DOWNLOADING"
        SplitInstallSessionStatus.DOWNLOADED -> "DOWNLOADED"
        SplitInstallSessionStatus.INSTALLING -> "INSTALLING"
        SplitInstallSessionStatus.INSTALLED -> "INSTALLED"
        SplitInstallSessionStatus.FAILED -> "FAILED"
        SplitInstallSessionStatus.CANCELING -> "CANCELING"
        SplitInstallSessionStatus.CANCELED -> "CANCELED"
        else -> "UNKNOWN"
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    companion object {
        private const val METHOD_CHANNEL = "reefguide/deferred"
        private const val EVENT_CHANNEL = "reefguide/deferred/progress"
    }
}
