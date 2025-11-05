package com.bb.bb_app

import android.graphics.*

object WaterBodyDrawable {

    fun createBitmap(width: Int, height: Int, waterLevel: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.TRANSPARENT)

        val centerX = width / 2f
        val bodyWidth = width * 0.55f
        val bodyHeight = height * 0.75f  // Leave more margin
        val startY = height * 0.05f

        // Body outline path (simple female silhouette)
        val bodyPath = Path()

        // Head
        val headRadius = bodyWidth * 0.16f
        bodyPath.addCircle(centerX, startY + headRadius, headRadius, Path.Direction.CW)

        // Body measurements
        val neckY = startY + headRadius * 2
        val shoulderY = neckY + bodyHeight * 0.02f
        val shoulderWidth = bodyWidth * 0.28f
        val torsoLength = bodyHeight * 0.5f  // Torso takes 50% of body height
        val legLength = bodyHeight * 0.48f   // Legs take 48% of body height
        val footY = shoulderY + torsoLength + legLength

        // Left side of body
        bodyPath.moveTo(centerX - shoulderWidth, shoulderY)

        // Left shoulder -> bust -> waist -> hip
        bodyPath.lineTo(centerX - bodyWidth * 0.36f, shoulderY + bodyHeight * 0.12f) // bust
        bodyPath.lineTo(centerX - bodyWidth * 0.24f, shoulderY + bodyHeight * 0.28f) // waist
        bodyPath.lineTo(centerX - bodyWidth * 0.30f, shoulderY + torsoLength) // hip

        // Left leg
        val legGap = bodyWidth * 0.10f  // Gap between legs
        bodyPath.lineTo(centerX - legGap, footY) // left foot

        // Bottom (space between feet)
        bodyPath.lineTo(centerX + legGap, footY) // right foot

        // Right leg going back up
        bodyPath.lineTo(centerX + bodyWidth * 0.30f, shoulderY + torsoLength) // hip
        bodyPath.lineTo(centerX + bodyWidth * 0.24f, shoulderY + bodyHeight * 0.28f) // waist
        bodyPath.lineTo(centerX + bodyWidth * 0.36f, shoulderY + bodyHeight * 0.12f) // bust
        bodyPath.lineTo(centerX + shoulderWidth, shoulderY) // shoulder

        bodyPath.close()

        // Draw water fill if level > 0
        if (waterLevel > 0f) {
            canvas.save()
            canvas.clipPath(bodyPath)

            // Water gradient - green if goal reached, blue otherwise
            val waterTop = height * (1f - waterLevel)
            val waterPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = if (waterLevel >= 1f) {
                    // Green gradient when goal reached
                    LinearGradient(
                        0f, height.toFloat(),
                        0f, waterTop,
                        Color.parseColor("#66BB6A"),
                        Color.parseColor("#A5D6A7"),
                        Shader.TileMode.CLAMP
                    )
                } else {
                    // Blue gradient when still working toward goal
                    LinearGradient(
                        0f, height.toFloat(),
                        0f, waterTop,
                        Color.parseColor("#4A90E2"),
                        Color.parseColor("#87CEEB"),
                        Shader.TileMode.CLAMP
                    )
                }
            }

            canvas.drawRect(0f, waterTop, width.toFloat(), height.toFloat(), waterPaint)
            canvas.restore()
        }

        // Draw body outline - green if goal reached, blue otherwise
        val outlineColor = if (waterLevel >= 1f) "#4CAF50" else "#4A90E2"  // Green when 100%, blue otherwise
        val outlinePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor(outlineColor)
            style = Paint.Style.STROKE
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(bodyPath, outlinePaint)

        return bitmap
    }
}
