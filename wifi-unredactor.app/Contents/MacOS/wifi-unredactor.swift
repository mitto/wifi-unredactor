import Cocoa
import CoreLocation
import CoreWLAN
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?

    // 固定されたJSONキーの順序を定義
    let jsonKeys = [
        "interface",
        "timestamp",
        "ssid",
        "bssid",
        "phy_mode",
        "noise_dbm",
        "rssi_dbm",
        "interface_mode",
        "channel_number",
        "channel_band",
        "channel_width",
        "channel_info",
        "security",
        "transmit_power",
        "transmit_rate"
    ]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            if let interface = CWWiFiClient.shared().interface() {
                var tempOutput: [String: String] = [:]

                tempOutput["interface"] = interface.interfaceName

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                dateFormatter.calendar = Calendar(identifier: .gregorian)
                tempOutput["timestamp"] = dateFormatter.string(from: Date())

                if let ssid = interface.ssid() {
                    tempOutput["ssid"] = ssid
                } else {
                    tempOutput["ssid"] = "failed to retrieve SSID"
                }

                if let bssid = interface.bssid() {
                    tempOutput["bssid"] = bssid
                } else {
                    tempOutput["bssid"] = "failed to retrieve BSSID"
                }

                let phyMode = interface.activePHYMode()
                switch phyMode {
                case .mode11a: tempOutput["phy_mode"] = "802.11a"
                case .mode11b: tempOutput["phy_mode"] = "802.11b"
                case .mode11g: tempOutput["phy_mode"] = "802.11g"
                case .mode11n: tempOutput["phy_mode"] = "802.11n"
                case .mode11ac: tempOutput["phy_mode"] = "802.11ac"
                case .mode11ax: tempOutput["phy_mode"] = "802.11ax"
                case .modeNone: tempOutput["phy_mode"] = "none"
                @unknown default: tempOutput["phy_mode"] = "unknown"
                }

                let noise = interface.noiseMeasurement()
                tempOutput["noise_dbm"] = "\(noise) dBm"

                let rssi = interface.rssiValue()
                tempOutput["rssi_dbm"] = "\(rssi) dBm"

                let mode = interface.interfaceMode()
                switch mode {
                case .none: tempOutput["interface_mode"] = "none"
                case .station: tempOutput["interface_mode"] = "station"
                case .hostAP: tempOutput["interface_mode"] = "hostAP"
                case .IBSS: tempOutput["interface_mode"] = "ibss"
                @unknown default: tempOutput["interface_mode"] = "unknown"
                }

                if let channel = interface.wlanChannel() {
                    tempOutput["channel_number"] = String(channel.channelNumber)
                    tempOutput["channel_band"] = channel.channelBand == .band2GHz ? "2.4GHz" : "5GHz"
                    switch channel.channelWidth {
                    case .width20MHz: tempOutput["channel_width"] = "20MHz"
                    case .width40MHz: tempOutput["channel_width"] = "40MHz"
                    case .width80MHz: tempOutput["channel_width"] = "80MHz"
                    case .width160MHz: tempOutput["channel_width"] = "160MHz"
                    case .widthUnknown: tempOutput["channel_width"] = "unknown"
                    @unknown default: tempOutput["channel_width"] = "unknown"
                    }
                } else {
                    tempOutput["channel_info"] = "failed to retrieve channel information"
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
                tempOutput["security"] = securityTypes.joined(separator: ", ")

                let power = interface.transmitPower()
                tempOutput["transmit_power"] = "\(power) dBm"

                let rate = interface.transmitRate()
                tempOutput["transmit_rate"] = "\(rate) Mbps"

                // 順序付きの出力を作成
                var orderedOutput: [String: String] = [:]
                for key in jsonKeys {
                    if let value = tempOutput[key] {
                        orderedOutput[key] = value
                    }
                }

                if let jsonData = try? JSONSerialization.data(withJSONObject: orderedOutput, options: [.prettyPrinted, .sortedKeys]),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("error: failed to create JSON")
                }
            }
            NSApp.terminate(nil)
        } else {
            let jsonOutput = ["error": "location services denied"]
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
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
