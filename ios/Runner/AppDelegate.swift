import UIKit
import Flutter
import GoogleMaps  // <- 新增這行

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GMSServices.provideAPIKey("AIzaSyBtRu7jKjkf2yy3VhNMrnTocDbPQO98MxU")  // <- 在這裡加入你的 Google Maps 金鑰

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}