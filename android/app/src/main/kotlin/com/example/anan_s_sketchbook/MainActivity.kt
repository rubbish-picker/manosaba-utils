package com.example.anan_s_sketchbook

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.ArrayList

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.anan_s_sketchbook/share"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareToWeChatOrQQ") {
                val path = call.argument<String>("path")
                if (path != null) {
                    shareFile(path)
                    result.success(null)
                } else {
                    result.error("INVALID_PATH", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun shareFile(path: String) {
        val file = File(path)
        // Ensure the file exists
        if (!file.exists()) {
            return
        }

        val uri = FileProvider.getUriForFile(this, "${context.packageName}.fileprovider", file)
        
        val shareIntent = Intent(Intent.ACTION_SEND)
        shareIntent.type = "image/*"
        shareIntent.putExtra(Intent.EXTRA_STREAM, uri)
        shareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        val targetedShareIntents: MutableList<Intent> = ArrayList()
        val resInfo = packageManager.queryIntentActivities(shareIntent, 0)
        
        if (resInfo.isNotEmpty()) {
            for (resolveInfo in resInfo) {
                val packageName = resolveInfo.activityInfo.packageName
                val activityName = resolveInfo.activityInfo.name
                
                var keep = false
                // Filter for WeChat (com.tencent.mm) and QQ (com.tencent.mobileqq)
                if (packageName == "com.tencent.mm") {
                    // 微信：只保留 ShareImgUI (发送给朋友)
                    if (activityName == "com.tencent.mm.ui.tools.ShareImgUI") {
                        keep = true
                    }
                } else if (packageName == "com.tencent.mobileqq") {
                    // QQ：保留 JumpActivity (发送给朋友)
                    // 使用完全匹配以避免匹配到其他包含 JumpActivity 的 Activity (如 qfileJumpActivity)
                    if (activityName == "com.tencent.mobileqq.activity.JumpActivity") {
                        keep = true
                    }
                }

                if (keep) {
                    val targetedShareIntent = Intent(Intent.ACTION_SEND)
                    targetedShareIntent.type = "image/*"
                    targetedShareIntent.putExtra(Intent.EXTRA_STREAM, uri)
                    targetedShareIntent.setClassName(packageName, activityName)
                    targetedShareIntent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    targetedShareIntents.add(targetedShareIntent)
                }
            }
            
            if (targetedShareIntents.isNotEmpty()) {
                // Sort to ensure consistent order if needed, or just use as is.
                // Create chooser with the first intent
                val chooserIntent = Intent.createChooser(targetedShareIntents.removeAt(0), "分享到")
                if (targetedShareIntents.isNotEmpty()) {
                    chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, targetedShareIntents.toTypedArray())
                }
                startActivity(chooserIntent)
            } else {
                startActivity(Intent.createChooser(shareIntent, "分享到"))
            }
        }
    }
}
