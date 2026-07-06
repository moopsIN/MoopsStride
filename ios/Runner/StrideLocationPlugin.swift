import Flutter
import UIKit
import CoreLocation

public class StrideLocationPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate, FlutterStreamHandler {
    private var locationManager: CLLocationManager!
    private var eventSink: FlutterEventSink?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = StrideLocationPlugin()
        
        let methodChannel = FlutterMethodChannel(name: "stride/location/methods", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        
        let eventChannel = FlutterEventChannel(name: "stride/location/events", binaryMessenger: registrar.messenger())
        eventChannel.setStreamHandler(instance)
    }

    public override init() {
        super.init()
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 0
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            locationManager.startUpdatingLocation()
            result(true)
        case "stop":
            locationManager.stopUpdatingLocation()
            result(true)
        case "isIgnoringBatteryOptimizations":
            // Not applicable to iOS
            result(true)
        case "requestIgnoreBatteryOptimizations":
            // Not applicable to iOS
            result(true)
        case "getCurrentPosition":
            if let location = locationManager.location {
                let locationMap: [String: Any] = [
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "accuracy": location.horizontalAccuracy,
                    "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)
                ]
                result(locationMap)
            } else {
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let sink = eventSink else { return }
        
        for location in locations {
            let locationMap: [String: Any] = [
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "accuracy": location.horizontalAccuracy,
                "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)
            ]
            sink(locationMap)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("StrideLocationPlugin error: \(error.localizedDescription)")
    }
}
