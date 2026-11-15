import Flutter
import UIKit
import GoogleMaps
import UserNotifications

// UIScene life cycle. An app built with the iOS 27 SDK that still uses the old
// app-delegate-only life cycle is refused at launch on iOS 27, which is what
// the first TestFlight builds did. Plugins are registered when the implicit
// engine is ready rather than in didFinishLaunching, as Flutter now requires.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK for iOS API key (dev key; rotate + restrict for prod)
    GMSServices.provideAPIKey("AIzaSyDHqos-W9V4xEohQJUmViexhuZ1eSX_vls")
    // Opening the app clears the red number on its icon. Nothing cleared it
    // before, so it stayed at 1 after the first push, for good.
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in
      if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(0)
      } else {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
