package com.bb.bb_app

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View

class WaterBodyView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private var waterLevel = 0f // 0.0 to 1.0
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.parseColor("#4A90E2") // Water blue outline
        style = Paint.Style.STROKE
        strokeWidth = 3f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    private val waterPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.FILL
        shader = null // Will be set in onSizeChanged
    }

    private val bodyPath = Path()
    private var viewWidth = 0f
    private var viewHeight = 0f

    fun setWaterLevel(level: Float) {
        waterLevel = level.coerceIn(0f, 1f)
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        super.onSizeChanged(w, h, oldw, oldh)
        viewWidth = w.toFloat()
        viewHeight = h.toFloat()

        // Create gradient for water (bottom to top, darker to lighter)
        waterPaint.shader = LinearGradient(
            0f, viewHeight,
            0f, 0f,
            Color.parseColor("#4A90E2"), // Darker blue at bottom
            Color.parseColor("#87CEEB"), // Sky blue at top
            Shader.TileMode.CLAMP
        )

        createBodyPath()
    }

    private fun createBodyPath() {
        bodyPath.reset()

        val centerX = viewWidth / 2f
        val padding = viewWidth * 0.15f

        // Scale factors for proportions
        val headRadius = viewWidth * 0.12f
        val shoulderWidth = viewWidth * 0.35f
        val waistWidth = viewWidth * 0.22f
        val hipWidth = viewWidth * 0.32f

        // Vertical positions (proportional to height)
        val headTop = padding
        val headBottom = headTop + headRadius * 2
        val neckBottom = headBottom + viewHeight * 0.03f
        val shoulderY = neckBottom + viewHeight * 0.02f
        val bustY = shoulderY + viewHeight * 0.12f
        val waistY = bustY + viewHeight * 0.15f
        val hipY = waistY + viewHeight * 0.12f
        val legBottom = viewHeight - padding
        val thighY = hipY + viewHeight * 0.15f
        val kneeY = thighY + viewHeight * 0.15f

        // Head (circle)
        bodyPath.addCircle(centerX, headTop + headRadius, headRadius, Path.Direction.CW)

        // Neck
        bodyPath.moveTo(centerX - viewWidth * 0.05f, neckBottom)
        bodyPath.lineTo(centerX - viewWidth * 0.05f, shoulderY)
        bodyPath.moveTo(centerX + viewWidth * 0.05f, neckBottom)
        bodyPath.lineTo(centerX + viewWidth * 0.05f, shoulderY)

        // Body outline - left side
        bodyPath.moveTo(centerX - shoulderWidth, shoulderY)

        // Left shoulder to bust
        bodyPath.cubicTo(
            centerX - shoulderWidth, shoulderY + viewHeight * 0.05f,
            centerX - shoulderWidth * 0.85f, bustY - viewHeight * 0.03f,
            centerX - shoulderWidth * 0.75f, bustY
        )

        // Left bust curve
        bodyPath.cubicTo(
            centerX - shoulderWidth * 0.75f, bustY + viewHeight * 0.03f,
            centerX - shoulderWidth * 0.7f, bustY + viewHeight * 0.06f,
            centerX - waistWidth, waistY
        )

        // Left waist to hip
        bodyPath.cubicTo(
            centerX - waistWidth * 0.9f, waistY + viewHeight * 0.05f,
            centerX - hipWidth * 0.85f, hipY - viewHeight * 0.03f,
            centerX - hipWidth, hipY
        )

        // Left hip to thigh
        bodyPath.cubicTo(
            centerX - hipWidth, hipY + viewHeight * 0.05f,
            centerX - hipWidth * 0.75f, thighY,
            centerX - hipWidth * 0.5f, kneeY
        )

        // Left knee to ankle
        bodyPath.cubicTo(
            centerX - hipWidth * 0.45f, kneeY + viewHeight * 0.05f,
            centerX - hipWidth * 0.35f, legBottom - viewHeight * 0.05f,
            centerX - viewWidth * 0.08f, legBottom
        )

        // Bottom (feet)
        bodyPath.lineTo(centerX + viewWidth * 0.08f, legBottom)

        // Right side (mirror)
        // Right ankle to knee
        bodyPath.cubicTo(
            centerX + hipWidth * 0.35f, legBottom - viewHeight * 0.05f,
            centerX + hipWidth * 0.45f, kneeY + viewHeight * 0.05f,
            centerX + hipWidth * 0.5f, kneeY
        )

        // Right knee to hip
        bodyPath.cubicTo(
            centerX + hipWidth * 0.75f, thighY,
            centerX + hipWidth, hipY + viewHeight * 0.05f,
            centerX + hipWidth, hipY
        )

        // Right hip to waist
        bodyPath.cubicTo(
            centerX + hipWidth * 0.85f, hipY - viewHeight * 0.03f,
            centerX + waistWidth * 0.9f, waistY + viewHeight * 0.05f,
            centerX + waistWidth, waistY
        )

        // Right waist to bust
        bodyPath.cubicTo(
            centerX + shoulderWidth * 0.7f, bustY + viewHeight * 0.06f,
            centerX + shoulderWidth * 0.75f, bustY + viewHeight * 0.03f,
            centerX + shoulderWidth * 0.75f, bustY
        )

        // Right bust to shoulder
        bodyPath.cubicTo(
            centerX + shoulderWidth * 0.85f, bustY - viewHeight * 0.03f,
            centerX + shoulderWidth, shoulderY + viewHeight * 0.05f,
            centerX + shoulderWidth, shoulderY
        )

        // Arms - simple lines for 1x1 widget
        // Left arm
        bodyPath.moveTo(centerX - shoulderWidth, shoulderY)
        bodyPath.cubicTo(
            centerX - shoulderWidth * 1.3f, shoulderY + viewHeight * 0.1f,
            centerX - shoulderWidth * 1.2f, bustY,
            centerX - shoulderWidth * 1.15f, waistY
        )

        // Right arm
        bodyPath.moveTo(centerX + shoulderWidth, shoulderY)
        bodyPath.cubicTo(
            centerX + shoulderWidth * 1.3f, shoulderY + viewHeight * 0.1f,
            centerX + shoulderWidth * 1.2f, bustY,
            centerX + shoulderWidth * 1.15f, waistY
        )
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (viewWidth == 0f || viewHeight == 0f) return

        // Draw water fill (clipped to body shape)
        if (waterLevel > 0) {
            canvas.save()

            // Create a filled body path for clipping
            val fillPath = Path()
            val centerX = viewWidth / 2f
            val padding = viewWidth * 0.15f
            val shoulderWidth = viewWidth * 0.35f
            val waistWidth = viewWidth * 0.22f
            val hipWidth = viewWidth * 0.32f
            val headRadius = viewWidth * 0.12f
            val headTop = padding
            val neckBottom = headTop + headRadius * 2 + viewHeight * 0.03f
            val shoulderY = neckBottom + viewHeight * 0.02f
            val bustY = shoulderY + viewHeight * 0.12f
            val waistY = bustY + viewHeight * 0.15f
            val hipY = waistY + viewHeight * 0.12f
            val thighY = hipY + viewHeight * 0.15f
            val kneeY = thighY + viewHeight * 0.15f
            val legBottom = viewHeight - padding

            // Create closed path for body fill
            fillPath.moveTo(centerX - shoulderWidth, shoulderY)
            fillPath.cubicTo(
                centerX - shoulderWidth, shoulderY + viewHeight * 0.05f,
                centerX - shoulderWidth * 0.85f, bustY - viewHeight * 0.03f,
                centerX - shoulderWidth * 0.75f, bustY
            )
            fillPath.cubicTo(
                centerX - shoulderWidth * 0.75f, bustY + viewHeight * 0.03f,
                centerX - shoulderWidth * 0.7f, bustY + viewHeight * 0.06f,
                centerX - waistWidth, waistY
            )
            fillPath.cubicTo(
                centerX - waistWidth * 0.9f, waistY + viewHeight * 0.05f,
                centerX - hipWidth * 0.85f, hipY - viewHeight * 0.03f,
                centerX - hipWidth, hipY
            )
            fillPath.cubicTo(
                centerX - hipWidth, hipY + viewHeight * 0.05f,
                centerX - hipWidth * 0.75f, thighY,
                centerX - hipWidth * 0.5f, kneeY
            )
            fillPath.cubicTo(
                centerX - hipWidth * 0.45f, kneeY + viewHeight * 0.05f,
                centerX - hipWidth * 0.35f, legBottom - viewHeight * 0.05f,
                centerX - viewWidth * 0.08f, legBottom
            )
            fillPath.lineTo(centerX + viewWidth * 0.08f, legBottom)
            fillPath.cubicTo(
                centerX + hipWidth * 0.35f, legBottom - viewHeight * 0.05f,
                centerX + hipWidth * 0.45f, kneeY + viewHeight * 0.05f,
                centerX + hipWidth * 0.5f, kneeY
            )
            fillPath.cubicTo(
                centerX + hipWidth * 0.75f, thighY,
                centerX + hipWidth, hipY + viewHeight * 0.05f,
                centerX + hipWidth, hipY
            )
            fillPath.cubicTo(
                centerX + hipWidth * 0.85f, hipY - viewHeight * 0.03f,
                centerX + waistWidth * 0.9f, waistY + viewHeight * 0.05f,
                centerX + waistWidth, waistY
            )
            fillPath.cubicTo(
                centerX + shoulderWidth * 0.7f, bustY + viewHeight * 0.06f,
                centerX + shoulderWidth * 0.75f, bustY + viewHeight * 0.03f,
                centerX + shoulderWidth * 0.75f, bustY
            )
            fillPath.cubicTo(
                centerX + shoulderWidth * 0.85f, bustY - viewHeight * 0.03f,
                centerX + shoulderWidth, shoulderY + viewHeight * 0.05f,
                centerX + shoulderWidth, shoulderY
            )
            fillPath.close()

            canvas.clipPath(fillPath)

            // Draw water from bottom up to waterLevel
            val waterTop = viewHeight * (1f - waterLevel)
            canvas.drawRect(
                0f,
                waterTop,
                viewWidth,
                viewHeight,
                waterPaint
            )

            canvas.restore()
        }

        // Draw body outline on top
        canvas.drawPath(bodyPath, bodyPaint)
    }
}
