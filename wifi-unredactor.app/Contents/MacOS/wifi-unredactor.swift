import Cocoa
import CoreLocation
import CoreWLAN
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    var locationManager: CLLocationManager?
    var outputFormat: String = "json"  // デフォルトはJSON形式
    var showCSVHeader: Bool = true     // デフォルトはヘッダーを表示
    var selectedFields: [String]?      // 選択されたフィールド
    var showUnits: Bool = true        // デフォルトは単位を表示
    var bssidToApName: [String: String] = [:] // BSSIDとAP名のマッピング

    // 固定されたJSONキーの順序を定義
    let jsonKeys = [
        "timestamp",
        "bssid",
        "ap_name",
        "channel_band",
        "channel_info",
        "channel_number",
        "channel_width",
        "interface",
        "interface_mode",
        "mac_address",
        "mcs_index",
        "noise_dbm",
        "phy_mode",
        "rssi_dbm",
        "security",
        "ssid",
        "transmit_power",
        "transmit_rate",
    ]

    func loadBssidMapping(from path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("error: failed to read BSSID mapping file")
            return
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let components = line.components(separatedBy: ",")
            if components.count >= 2 {
                let bssid = components[0].trimmingCharacters(in: .whitespaces)
                let apName = components[1].trimmingCharacters(in: .whitespaces)
                bssidToApName[bssid] = apName
            }
        }
    }

    func showHelp() {
        let help = """
        使用方法: wifi-unredactor [オプション]

        オプション:
          --help              このヘルプメッセージを表示
          --csv              CSV形式で出力（デフォルト: JSON形式）
          --no-header        CSVヘッダーを非表示（CSV形式時のみ有効）
          --no-units        単位を非表示（例: dBm, Mbps）
          --fields <fields>  出力するフィールドをカンマ区切りで指定
          --bssid-mapping <file>  BSSIDとAP名のマッピングファイルを指定

        利用可能なフィールド:
          \(jsonKeys.joined(separator: "\n          "))

        例:
          wifi-unredactor --csv --fields ssid,bssid,rssi_dbm
          wifi-unredactor --bssid-mapping mapping.csv --no-units
        """
        print(help)
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // コマンドライン引数を処理
        let args = CommandLine.arguments

        if args.contains("--help") {
            showHelp()
            return
        }

        if args.contains("--csv") {
            outputFormat = "csv"
        }
        if args.contains("--no-header") {
            showCSVHeader = false
        }
        if args.contains("--no-units") {
            showUnits = false
        }
        if let mappingIndex = args.firstIndex(of: "--bssid-mapping"),
           mappingIndex + 1 < args.count {
            loadBssidMapping(from: args[mappingIndex + 1])
        }
        if let fieldsIndex = args.firstIndex(of: "--fields"),
           fieldsIndex + 1 < args.count {
            selectedFields = args[fieldsIndex + 1].split(separator: ",").map(String.init)
            // 指定されたフィールドが有効かチェック
            selectedFields = selectedFields?.filter { jsonKeys.contains($0) }
            if selectedFields?.isEmpty ?? true {
                selectedFields = nil  // 有効なフィールドがない場合はnilに
            }
        }

        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
    }

    func outputCSV(_ data: [String: String]) {
        let keysToUse = selectedFields ?? jsonKeys
        let header = keysToUse.joined(separator: ",")
        let values = keysToUse.map { key in
            let value = data[key] ?? ""
            // カンマを含む場合はダブルクォートで囲む
            return value.contains(",") ? "\"\(value)\"" : value
        }.joined(separator: ",")

        if showCSVHeader {
            print(header)
        }
        print(values)
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            if let interface = CWWiFiClient.shared().interface() {
                var tempOutput: [String: String] = [:]

                tempOutput["interface"] = interface.interfaceName

                if let mac = interface.hardwareAddress() {
                    tempOutput["mac_address"] = mac
                } else {
                    tempOutput["mac_address"] = "failed to retrieve MAC address"
                }

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
                    if let apName = bssidToApName[bssid] {
                        tempOutput["ap_name"] = apName
                    } else {
                        tempOutput["ap_name"] = ""
                    }
                } else {
                    tempOutput["bssid"] = "failed to retrieve BSSID"
                    tempOutput["ap_name"] = ""
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
                tempOutput["noise_dbm"] = showUnits ? "\(noise)dBm" : String(noise)

                let rssi = interface.rssiValue()
                tempOutput["rssi_dbm"] = showUnits ? "\(rssi)dBm" : String(rssi)

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
                    switch channel.channelBand {
                    case .band2GHz:
                        tempOutput["channel_band"] = "2.4GHz"
                    case .band5GHz:
                        tempOutput["channel_band"] = "5GHz"
                    case .band6GHz:
                        tempOutput["channel_band"] = "6GHz"
                    case .bandUnknown:
                        tempOutput["channel_band"] = "unknown"
                    @unknown default:
                        tempOutput["channel_band"] = "unknown"
                    }
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
                tempOutput["transmit_power"] = showUnits ? "\(power)dBm" : String(power)

                let rate = Int(interface.transmitRate())
                tempOutput["transmit_rate"] = showUnits ? "\(rate)Mbps" : String(rate)

                // NOTE: https://stackoverflow.com/questions/48129952/core-wlan-mcs-index
                if let mcs = interface.value(forKey: "mcsIndex") as? Int {
                    tempOutput["mcs_index"] = String(mcs)
                } else {
                    tempOutput["mcs_index"] = "unknown"
                }

                if outputFormat == "csv" {
                    outputCSV(tempOutput)
                } else {
                    // 順序付きの出力を作成
                    var orderedOutput: [String: String] = [:]
                    let keysToUse = selectedFields ?? jsonKeys
                    for key in keysToUse {
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
            }
            NSApp.terminate(nil)
        } else {
            if outputFormat == "csv" {
                print("location services denied")
            } else {
                let jsonOutput = ["error": "location services denied"]
                if let jsonData = try? JSONSerialization.data(withJSONObject: jsonOutput, options: [.prettyPrinted, .sortedKeys]),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                } else {
                    print("error: failed to create JSON")
                }
            }
            NSApp.terminate(nil)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
