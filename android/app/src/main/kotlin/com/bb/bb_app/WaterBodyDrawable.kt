package com.bb.bb_app

import android.graphics.*

object WaterBodyDrawable {

    fun createBitmap(width: Int, height: Int, waterLevel: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.TRANSPARENT)

        val centerX = width / 2f
        val bodyWidth = width * 0.45f  // Keep narrow width
        val bodyHeight = height * 0.96f  // Maximum height
        val startY = height * 0.005f  // Absolute minimal top margin

        // Body outline path (simple female silhouette)
        val bodyPath = Path()

        // Head (proportional but ensure it fits with margin for outline stroke)
        val headRadius = bodyWidth * 0.18f
        val headCenterY = startY + headRadius + 4f  // +4f to ensure outline doesn't clip at top
        bodyPath.addCircle(centerX, headCenterY, headRadius, Path.Direction.CW)

        // Body measurements
        val neckY = headCenterY + headRadius
        val shoulderY = neckY + bodyHeight * 0.015f
        val hipWidth = bodyWidth * 0.28f  // Hip width
        val shoulderWidth = hipWidth  // Same as hips
        val torsoLength = bodyHeight * 0.32f  // Even shorter torso
        val legLength = bodyHeight * 0.66f   // Even longer legs
        val footY = (shoulderY + torsoLength + legLength).coerceAtMost(height - 4f)  // Ensure bottom margin for stroke

        // Left side of body
        bodyPath.moveTo(centerX - shoulderWidth, shoulderY)

        // Left shoulder with rounded curve
        bodyPath.cubicTo(
            centerX - shoulderWidth * 1.1f, shoulderY + torsoLength * 0.1f,
            centerX - shoulderWidth, shoulderY + torsoLength * 0.2f,
            centerX - shoulderWidth, shoulderY + torsoLength * 0.3f
        ) // rounded shoulder

        // Waist (narrowest point in the middle of torso)
        val waistWidth = bodyWidth * 0.18f
        bodyPath.cubicTo(
            centerX - shoulderWidth * 0.95f, shoulderY + torsoLength * 0.45f,
            centerX - waistWidth, shoulderY + torsoLength * 0.55f,
            centerX - waistWidth, shoulderY + torsoLength * 0.65f
        ) // curve to waist

        // Hip curve (widen back out)
        bodyPath.cubicTo(
            centerX - waistWidth, shoulderY + torsoLength * 0.75f,
            centerX - hipWidth * 0.9f, shoulderY + torsoLength * 0.9f,
            centerX - hipWidth, shoulderY + torsoLength
        ) // hip curve (rounder)

        // Left leg
        val legGap = bodyWidth * 0.10f  // Gap between legs
        bodyPath.lineTo(centerX - legGap, footY) // left foot

        // Bottom (space between feet)
        bodyPath.lineTo(centerX + legGap, footY) // right foot

        // Right leg going back up
        bodyPath.lineTo(centerX + hipWidth, shoulderY + torsoLength) // hip

        // Hip curve (narrow back in)
        bodyPath.cubicTo(
            centerX + hipWidth * 0.9f, shoulderY + torsoLength * 0.9f,
            centerX + waistWidth, shoulderY + torsoLength * 0.75f,
            centerX + waistWidth, shoulderY + torsoLength * 0.65f
        ) // hip curve (rounder)

        // Waist to shoulder
        bodyPath.cubicTo(
            centerX + waistWidth, shoulderY + torsoLength * 0.55f,
            centerX + shoulderWidth * 0.95f, shoulderY + torsoLength * 0.45f,
            centerX + shoulderWidth, shoulderY + torsoLength * 0.3f
        ) // curve to shoulder

        // Right shoulder with rounded curve
        bodyPath.cubicTo(
            centerX + shoulderWidth, shoulderY + torsoLength * 0.2f,
            centerX + shoulderWidth * 1.1f, shoulderY + torsoLength * 0.1f,
            centerX + shoulderWidth, shoulderY
        ) // rounded shoulder

        bodyPath.close()

        // Draw water fill if level > 0
        if (waterLevel > 0f) {
            canvas.save()
            canvas.clipPath(bodyPath)

            // Water gradient - green if goal reached, blue otherwise
            val waterTop = height * (1f - waterLevel)
            val waterPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = if (waterLevel >= 1f) {
                    // Green gradient when goal reached - matching routine widget
                    LinearGradient(
                        0f, height.toFloat(),
                        0f, waterTop,
                        Color.parseColor("#4CAF50"),
                        Color.parseColor("#81C784"),
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

        // Draw explicit bottom line between feet for visibility
        val legGap = bodyWidth * 0.10f
        canvas.drawLine(
            centerX - legGap, footY,
            centerX + legGap, footY,
            outlinePaint
        )

        return bitmap
    }
}
