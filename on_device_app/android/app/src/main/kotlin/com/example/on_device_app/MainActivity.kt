package com.example.on_device_app

import android.graphics.Bitmap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.on_device_app/mediapipe"
    private var helper: HandLandmarkerHelper? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        helper = HandLandmarkerHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "detect") {
                val planes = call.argument<List<Map<String, Any>>>("planes")
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val format = call.argument<String>("format")

                if (planes != null && width > 0 && height > 0) {
                    try {
                        val bitmap = if (format == "yuv420") {
                            yuvToBitmap(planes, width, height)
                        } else {
                            // Assume BGRA/RGBA if not yuv420
                            val bytes = planes[0]["bytes"] as ByteArray
                            val bytesPerRow = planes[0]["bytesPerRow"] as Int
                            bytesToBitmap(bytes, width, height, bytesPerRow)
                        }

                        val detectionResult = helper?.detect(bitmap)
                        
                        if (detectionResult == null) {
                            result.error("INIT_ERROR", "HandLandmarker not initialized", null)
                            return@setMethodCallHandler
                        }
                        
                        val response = mutableListOf<List<Map<String, Float>>>()
                        detectionResult?.landmarks()?.let { allHands ->
                            for (hand in allHands) {
                                val handData = mutableListOf<Map<String, Float>>()
                                for (point in hand) {
                                    handData.add(mapOf(
                                        "x" to point.x(),
                                        "y" to point.y(),
                                        "z" to point.z()
                                    ))
                                }
                                response.add(handData)
                            }
                        }
                        result.success(response)
                    } catch (e: Exception) {
                        result.error("DETECTION_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing bytes, width, or height", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun yuvToBitmap(planes: List<Map<String, Any>>, width: Int, height: Int): Bitmap {
        val yBuffer = ByteBuffer.wrap(planes[0]["bytes"] as ByteArray)
        val uBuffer = ByteBuffer.wrap(planes[1]["bytes"] as ByteArray)
        val vBuffer = ByteBuffer.wrap(planes[2]["bytes"] as ByteArray)

        val yRowStride = planes[0]["bytesPerRow"] as Int
        val uvRowStride = planes[1]["bytesPerRow"] as Int
        val uvPixelStride = planes[1]["bytesPerPixel"] as Int

        val out = IntArray(width * height)
        var i = 0
        for (y in 0 until height) {
            val pY = y * yRowStride
            val pUV = (y shr 1) * uvRowStride
            for (x in 0 until width) {
                val uvOffset = pUV + (x shr 1) * uvPixelStride
                
                val yc = yBuffer[pY + x].toInt() and 0xFF
                val uc = uBuffer[uvOffset].toInt() and 0xFF
                val vc = vBuffer[uvOffset].toInt() and 0xFF

                var r = (yc + 1.370705 * (vc - 128)).toInt()
                var g = (yc - 0.337633 * (uc - 128) - 0.698001 * (vc - 128)).toInt()
                var b = (yc + 1.732446 * (uc - 128)).toInt()

                r = r.coerceIn(0, 255)
                g = g.coerceIn(0, 255)
                b = b.coerceIn(0, 255)

                out[i++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return Bitmap.createBitmap(out, width, height, Bitmap.Config.ARGB_8888)
    }

    private fun bytesToBitmap(bytes: ByteArray, width: Int, height: Int, bytesPerRow: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val buffer = ByteBuffer.wrap(bytes)
        
        if (bytesPerRow == width * 4) {
            bitmap.copyPixelsFromBuffer(buffer)
        } else {
            val rowBytes = width * 4
            val rowBuffer = ByteArray(rowBytes)
            for (i in 0 until height) {
                buffer.position(i * bytesPerRow)
                buffer.get(rowBuffer, 0, rowBytes)
                bitmap.setPixels(
                    IntArray(width) { j ->
                        val base = j * 4
                        val b = rowBuffer[base].toInt() and 0xFF
                        val g = rowBuffer[base + 1].toInt() and 0xFF
                        val r = rowBuffer[base + 2].toInt() and 0xFF
                        val a = rowBuffer[base + 3].toInt() and 0xFF
                        (a shl 24) or (r shl 16) or (g shl 8) or b
                    },
                    0, width, 0, i, width, 1
                )
            }
        }
        return bitmap
    }

    override fun onDestroy() {
        helper?.close()
        super.onDestroy()
    }
}
