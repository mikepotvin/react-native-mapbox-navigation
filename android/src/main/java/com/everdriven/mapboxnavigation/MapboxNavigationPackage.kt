package com.everdriven.mapboxnavigation

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.mapbox.navigation.core.lifecycle.MapboxNavigationApp
import com.mapbox.navigation.base.options.NavigationOptions

class MapboxNavigationPackage : ReactPackage {
  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
    if (!MapboxNavigationApp.isSetup()) {
      MapboxNavigationApp.setup {
          NavigationOptions.Builder(reactContext)
              // additional options
              .build()
      }
    }
    return emptyList()
  }

  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
    return listOf(MapboxNavigationManager(reactContext))
  }
}