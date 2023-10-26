package com.everdriven.mapboxnavigation

import android.content.Context
import android.util.AttributeSet
import android.view.MotionEvent
import com.mapbox.maps.MapView
import com.mapbox.maps.MapInitOptions


open class CustomMapView : MapView {

    @JvmOverloads
    constructor(context: Context, mapInitOptions: MapInitOptions = MapInitOptions(context)) : super(context, mapInitOptions)

    /**
     * Build a [MapView] with [Context] and [AttributeSet] objects.
     */
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    /**
     * Build a [MapView] with a [Context] object, a [AttributeSet] object, and
     * an [Int] which represents a style resource file.
     */
    constructor(context: Context, attrs: AttributeSet?, defStyleAttr: Int) : super(
        context,
        attrs,
        defStyleAttr
    )

    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_MOVE, MotionEvent.ACTION_DOWN -> this.getParent().requestDisallowInterceptTouchEvent(true)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> this.getParent().requestDisallowInterceptTouchEvent(
                false
            )
        }
        return super.onTouchEvent(event)
    }
}
