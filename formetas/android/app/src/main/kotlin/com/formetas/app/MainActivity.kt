package com.formetas.app

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.view.ViewCompat
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private val handler = Handler(Looper.getMainLooper())
    private val hideNavRunnable = Runnable { hideNavigationBar() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupNavigationBarAutoHide()
        hideNavigationBar()
    }

    override fun onResume() {
        super.onResume()
        hideNavigationBar()
    }

    override fun onDestroy() {
        handler.removeCallbacks(hideNavRunnable)
        super.onDestroy()
    }

    private fun setupNavigationBarAutoHide() {
        ViewCompat.setOnApplyWindowInsetsListener(window.decorView) { view, insets ->
            if (insets.isVisible(WindowInsetsCompat.Type.navigationBars())) {
                scheduleHideNavigationBar()
            }
            ViewCompat.onApplyWindowInsets(view, insets)
        }
    }

    private fun scheduleHideNavigationBar(delayMs: Long = 2500) {
        handler.removeCallbacks(hideNavRunnable)
        handler.postDelayed(hideNavRunnable, delayMs)
    }

    private fun hideNavigationBar() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.navigationBars())
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }
}
