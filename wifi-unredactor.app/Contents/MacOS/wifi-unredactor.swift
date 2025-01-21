import Cocoa
import CoreLocation
import CoreWLAN
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            if let interface = CWWiFiClient.shared().interface() {
                var jsonOutput: [String: String] = [:]

                jsonOutput["interface"] = interface.interfaceName

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.calendar = Calendar(identifier: .gregorian)
                jsonOutput["timestamp"] = dateFormatter.string(from: Date())

                if let ssid = interface.ssid() {
                    jsonOutput["ssid"] = ssid
                } else {
                    jsonOutput["ssid"] = "failed to retrieve SSID"
                }

                if let bssid = interface.bssid() {
                    jsonOutput["bssid"] = bssid
                } else {
                    jsonOutput["bssid"] = "failed to retrieve BSSID"
                }

                let phyMode = interface.activePHYMode()
                switch phyMode {
                case .mode11a: jsonOutput["phy_mode"] = "802.11a"
                case .mode11b: jsonOutput["phy_mode"] = "802.11b"
                case .mode11g: jsonOutput["phy_mode"] = "802.11g"
                case .mode11n: jsonOutput["phy_mode"] = "802.11n"
                case .mode11ac: jsonOutput["phy_mode"] = "802.11ac"
                case .mode11ax: jsonOutput["phy_mode"] = "802.11ax"
                case .modeNone: jsonOutput["phy_mode"] = "none"
                @unknown default: jsonOutput["phy_mode"] = "unknown"
                }

                let noise = interface.noiseMeasurement()
                jsonOutput["noise_dbm"] = "\(noise) dBm"

                let rssi = interface.rssiValue()
                jsonOutput["rssi_dbm"] = "\(rssi) dBm"

                let mode = interface.interfaceMode()
                switch mode {
                case .none: jsonOutput["interface_mode"] = "none"
                case .station: jsonOutput["interface_mode"] = "station"
                case .hostAP: jsonOutput["interface_mode"] = "hostAP"
                case .IBSS: jsonOutput["interface_mode"] = "ibss"
                @unknown default: jsonOutput["interface_mode"] = "unknown"
                }

                if let channel = interface.wlanChannel() {
                    jsonOutput["channel_number"] = String(channel.channelNumber)
                    jsonOutput["channel_band"] = channel.channelBand == .band2GHz ? "2.4GHz" : "5GHz"
                    switch channel.channelWidth {
                    case .width20MHz: jsonOutput["channel_width"] = "20MHz"
                    case .width40MHz: jsonOutput["channel_width"] = "40MHz"
                    case .width80MHz: jsonOutput["channel_width"] = "80MHz"
                    case .width160MHz: jsonOutput["channel_width"] = "160MHz"
                    case .widthUnknown: jsonOutput["channel_width"] = "unknown"
                    @unknown default: jsonOutput["channel_width"] = "unknown"
                    }
                } else {
                    jsonOutput["channel_info"] = "failed to retrieve channel information"
                }

                let security = interface.security()
                var securityTypes: [String] = []
                switch security {
                case .none: securityTypes.append("none")
                case .WEP: securityTypes.append("WEP")
                case .dynamicWEP: securityTypes.append("Dynamic WEP")
                case .wpaPersonal: securityTypes.append("WPA Personal")
                case .wpaPersonalMixed: securityTypes.append("WPA Personal Mixed")
                case .wpaEnterprise: securityTypes.append("WPA Enterprise")
                case .wpaEnterpriseMixed: securityTypes.append("WPA Enterprise Mixed")
                case .wpa2Personal: securityTypes.append("WPA2 Personal")
                case .wpa2Enterprise: securityTypes.append("WPA2 Enterprise")
                case .wpa3Personal: securityTypes.append("WPA3 Personal")
                case .wpa3Enterprise: securityTypes.append("WPA3 Enterprise")
                case .wpa3Transition: securityTypes.append("WPA3 Transition")
                case .personal: securityTypes.append("Personal")
                case .enterprise: securityTypes.append("Enterprise")
                case .OWE: securityTypes.append("OWE")
                case .oweTransition: securityTypes.append("OWE Transition")
                case .unknown: securityTypes.append("unknown")
                @unknown default: securityTypes.append("unknown")
                }
                jsonOutput["security"] = securityTypes.joined(separator: ", ")

                let power = interface.transmitPower()
                jsonOutput["transmit_power"] = "\(power) dBm"

                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("error: failed to create JSON")
                }
            }
            NSApp.terminate(nil)
        } else {
            let jsonOutput = ["error": "location services denied"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            } else {
                print("error: failed to create JSON")
            }
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
