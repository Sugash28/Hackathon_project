package com.example.on_device_app

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult

class HandLandmarkerHelper(
    private val context: Context,
    private val runningMode: RunningMode = RunningMode.IMAGE
) {

    private var handLandmarker: HandLandmarker? = null

    init {
        setupHandLandmarker()
    }

    private fun setupHandLandmarker() {
        val pathsToTry = listOf(
            "flutter_assets/assets/hand_landmarker.task",
            "assets/hand_landmarker.task",
            "hand_landmarker.task"
        )

        var error: String? = null
        for (path in pathsToTry) {
            try {
                // Test if asset exists
                context.assets.open(path).close()
                android.util.Log.d("HandLandmarkerHelper", "Trying model path: $path")

                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath(path)
                    .build()

                val options = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setRunningMode(runningMode)
                    .setNumHands(2)
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .build()

                handLandmarker = HandLandmarker.createFromOptions(context, options)
                android.util.Log.d("HandLandmarkerHelper", "HandLandmarker initialized with: $path")
                return 
            } catch (e: Exception) {
                error = e.message
                android.util.Log.w("HandLandmarkerHelper", "Failed path $path: $error")
            }
        }
        android.util.Log.e("HandLandmarkerHelper", "All paths failed. Last error: $error")
    }

    fun detect(bitmap: Bitmap): HandLandmarkerResult? {
        if (handLandmarker == null) return null
        val mpImage = BitmapImageBuilder(bitmap).build()
        return handLandmarker?.detect(mpImage)
    }

    fun close() {
        handLandmarker?.close()
        handLandmarker = null
    }
}
