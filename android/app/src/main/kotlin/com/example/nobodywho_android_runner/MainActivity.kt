package com.example.nobodywho_android_runner

import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "nobodywho_android_runner/assets"
        ).setMethodCallHandler { call, result ->
            if (call.method != "copyAssetToFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val assetPath = call.argument<String>("assetPath")
                    ?: error("assetPath is required")
                val destinationPath = call.argument<String>("destinationPath")
                    ?: error("destinationPath is required")
                result.success(copyAssetToFile(assetPath, destinationPath))
            } catch (error: Throwable) {
                result.error("asset_copy_failed", error.message, null)
            }
        }
    }

    private fun copyAssetToFile(assetPath: String, destinationPath: String): Long {
        val destination = File(destinationPath)
        val existingBytes = destination.takeIf { it.exists() }?.length() ?: 0L
        if (existingBytes > 0L) {
            Log.i("NobodyWhoAsset", "already copied $destinationPath bytes=$existingBytes")
            return existingBytes
        }

        destination.parentFile?.mkdirs()
        val temp = File("$destinationPath.tmp")
        if (temp.exists()) temp.delete()

        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        val started = System.currentTimeMillis()
        var copied = 0L
        var nextLog = 256L * 1024L * 1024L
        val buffer = ByteArray(8 * 1024 * 1024)

        Log.i("NobodyWhoAsset", "copy start $assetPath -> $destinationPath key=$key")
        assets.open(key).use { input ->
            FileOutputStream(temp).use { output ->
                while (true) {
                    val read = input.read(buffer)
                    if (read < 0) break
                    output.write(buffer, 0, read)
                    copied += read
                    if (copied >= nextLog) {
                        Log.i("NobodyWhoAsset", "copy progress $assetPath bytes=$copied")
                        nextLog += 256L * 1024L * 1024L
                    }
                }
                output.fd.sync()
            }
        }

        if (!temp.renameTo(destination)) {
            temp.copyTo(destination, overwrite = true)
            temp.delete()
        }
        Log.i(
            "NobodyWhoAsset",
            "copy done $assetPath bytes=$copied elapsed_ms=${System.currentTimeMillis() - started}"
        )
        return copied
    }
}
