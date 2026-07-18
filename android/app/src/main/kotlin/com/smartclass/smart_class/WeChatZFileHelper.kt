package com.smartclass.smart_class

import android.widget.ImageView
import androidx.collection.ArrayMap
import androidx.fragment.app.FragmentActivity
import com.bumptech.glide.Glide
import com.bumptech.glide.request.RequestOptions
import com.zp.z_file.content.ZFILE_QW_DOCUMENT
import com.zp.z_file.content.ZFILE_QW_MEDIA
import com.zp.z_file.content.ZFILE_QW_OTHER
import com.zp.z_file.content.ZFILE_QW_PIC
import com.zp.z_file.content.ZFileBean
import com.zp.z_file.content.ZFileConfiguration
import com.zp.z_file.content.ZFileQWData
import com.zp.z_file.content.getZFileHelp
import com.zp.z_file.dsl.result
import com.zp.z_file.listener.ZFileImageListener
import java.io.File

/**
 * 接入开源 [ZFileManager](https://github.com/zippo88888888/ZFileManager)：
 * setFilePath(WECHAT) → 微信文件分类页 → 勾选 → 确认返回。
 */
object WeChatZFileHelper {
    @Volatile
    private var initialized = false

    fun ensureInit() {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            getZFileHelp().init(object : ZFileImageListener() {
                override fun loadImage(imageView: ImageView, file: File) {
                    Glide.with(imageView.context)
                        .load(file)
                        .apply(
                            RequestOptions()
                                .placeholder(com.zp.z_file.R.drawable.ic_zfile_other)
                                .error(com.zp.z_file.R.drawable.ic_zfile_other),
                        )
                        .into(imageView)
                }
            })
            initialized = true
        }
    }

    fun pick(
        activity: FragmentActivity,
        onResult: (List<ZFileBean>?) -> Unit,
    ) {
        ensureInit()
        val config = ZFileConfiguration().apply {
            filePath = ZFileConfiguration.WECHAT
            boxStyle = ZFileConfiguration.STYLE2
            sortordBy = ZFileConfiguration.BY_DATE
            sortord = ZFileConfiguration.DESC
            maxLength = 9
            // 覆盖默认路径：新版微信文件多在 Android/data/.../Download
            qwData = ZFileQWData().apply {
                wechatFilePathArrayMap = defaultWeChatPaths()
            }
        }
        getZFileHelp()
            .setConfiguration(config)
            .result(activity) {
                // DSL：receiver 为选中列表
                onResult(this)
            }
    }

    private fun defaultWeChatPaths(): ArrayMap<Int, MutableList<String>> {
        val pic = mutableListOf(
            "/storage/emulated/0/tencent/MicroMsg/WeiXin/",
            "/storage/emulated/0/Pictures/WeiXin/",
            "/storage/emulated/0/Pictures/WeChat/",
        )
        val media = mutableListOf(
            "/storage/emulated/0/tencent/MicroMsg/WeiXin/",
            "/storage/emulated/0/Pictures/WeiXin/",
        )
        val doc = mutableListOf(
            "/storage/emulated/0/tencent/MicroMsg/Download/",
            "/storage/emulated/0/Android/data/com.tencent.mm/MicroMsg/Download/",
            "/storage/emulated/0/Download/WeiXin/",
            "/storage/emulated/0/Download/WeChat/",
        )
        return ArrayMap<Int, MutableList<String>>().apply {
            put(ZFILE_QW_PIC, pic)
            put(ZFILE_QW_MEDIA, media)
            put(ZFILE_QW_DOCUMENT, doc)
            put(ZFILE_QW_OTHER, ArrayList(doc))
        }
    }
}
