import Cocoa
import CoreLocation
import CoreWLAN
import Foundation

// MARK: - Constants
enum Constants {
    static let defaultOutputFormat = "json"
    static let defaultShowCSVHeader = true
    static let defaultShowUnits = true

    static let jsonKeys = [
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
}

// MARK: - Error Types
enum WiFiError: Error {
    case locationServicesDenied
    case interfaceNotAvailable
    case failedToCreateJSON
    case failedToReadMapping
    case invalidFields
}

// MARK: - Data Structures
struct WiFiData {
    let timestamp: String
    let interface: String
    let macAddress: String
    let ssid: String
    let bssid: String
    let apName: String
    let phyMode: String
    let noiseDBM: Int
    let rssiDBM: Int
    let interfaceMode: String
    let channelInfo: ChannelInfo
    let security: String
    let transmitPower: Int
    let transmitRate: Int
    let mcsIndex: String

    struct ChannelInfo {
        let number: Int
        let band: String
        let width: String
    }
}

// MARK: - Output Formatter Protocol
protocol OutputFormatter {
    func format(_ data: WiFiData, showUnits: Bool, selectedFields: [String]?) -> String
}

// MARK: - Output Formatters
class JSONFormatter: OutputFormatter {
    func format(_ data: WiFiData, showUnits: Bool, selectedFields: [String]?) -> String {
        var dict: [String: String] = [:]

        // Convert WiFiData to dictionary
        dict["timestamp"] = data.timestamp
        dict["interface"] = data.interface
        dict["mac_address"] = data.macAddress
        dict["ssid"] = data.ssid
        dict["bssid"] = data.bssid
        dict["ap_name"] = data.apName
        dict["phy_mode"] = data.phyMode
        dict["noise_dbm"] = showUnits ? "\(data.noiseDBM)dBm" : String(data.noiseDBM)
        dict["rssi_dbm"] = showUnits ? "\(data.rssiDBM)dBm" : String(data.rssiDBM)
        dict["interface_mode"] = data.interfaceMode
        dict["channel_number"] = String(data.channelInfo.number)
        dict["channel_band"] = data.channelInfo.band
        dict["channel_width"] = data.channelInfo.width
        dict["security"] = data.security
        dict["transmit_power"] = showUnits ? "\(data.transmitPower)dBm" : String(data.transmitPower)
        dict["transmit_rate"] = showUnits ? "\(data.transmitRate)Mbps" : String(data.transmitRate)
        dict["mcs_index"] = data.mcsIndex

        // Filter fields if needed
        if let fields = selectedFields {
            dict = dict.filter { fields.contains($0.key) }
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "error: failed to create JSON"
        }

        return jsonString
    }
}

class CSVFormatter: OutputFormatter {
    let showHeader: Bool

    init(showHeader: Bool = true) {
        self.showHeader = showHeader
    }

    func format(_ data: WiFiData, showUnits: Bool, selectedFields: [String]?) -> String {
        let keysToUse = selectedFields ?? Constants.jsonKeys
        var output = ""

        if showHeader {
            output += keysToUse.joined(separator: ",") + "\n"
        }

        let dict: [String: String] = [
            "timestamp": data.timestamp,
            "interface": data.interface,
            "mac_address": data.macAddress,
            "ssid": data.ssid,
            "bssid": data.bssid,
            "ap_name": data.apName,
            "phy_mode": data.phyMode,
            "noise_dbm": showUnits ? "\(data.noiseDBM)dBm" : String(data.noiseDBM),
            "rssi_dbm": showUnits ? "\(data.rssiDBM)dBm" : String(data.rssiDBM),
            "interface_mode": data.interfaceMode,
            "channel_number": String(data.channelInfo.number),
            "channel_band": data.channelInfo.band,
            "channel_width": data.channelInfo.width,
            "security": data.security,
            "transmit_power": showUnits ? "\(data.transmitPower)dBm" : String(data.transmitPower),
            "transmit_rate": showUnits ? "\(data.transmitRate)Mbps" : String(data.transmitRate),
            "mcs_index": data.mcsIndex
        ]

        let values = keysToUse.map { key in
            let value = dict[key] ?? ""
            return value.contains(",") ? "\"\(value)\"" : value
        }

        output += values.joined(separator: ",")
        return output
    }
}

// MARK: - WiFi Service
class WiFiService {
    private let interface: CWInterface?
    private var bssidToApName: [String: String]

    init() {
        self.interface = CWWiFiClient.shared().interface()
        self.bssidToApName = [:]
    }

    func loadBssidMapping(from path: String) throws {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            throw WiFiError.failedToReadMapping
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

    func getCurrentWiFiData() throws -> WiFiData {
        guard let interface = self.interface else {
            throw WiFiError.interfaceNotAvailable
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)

        let bssid = interface.bssid() ?? "failed to retrieve BSSID"
        let apName = bssidToApName[bssid] ?? ""

        let channelInfo: WiFiData.ChannelInfo
        if let channel = interface.wlanChannel() {
            channelInfo = WiFiData.ChannelInfo(
                number: channel.channelNumber,
                band: {
                    switch channel.channelBand {
                    case .band2GHz: return "2.4GHz"
                    case .band5GHz: return "5GHz"
                    case .band6GHz: return "6GHz"
                    case .bandUnknown: return "unknown"
                    @unknown default: return "unknown"
                    }
                }(),
                width: {
                    switch channel.channelWidth {
                    case .width20MHz: return "20MHz"
                    case .width40MHz: return "40MHz"
                    case .width80MHz: return "80MHz"
                    case .width160MHz: return "160MHz"
                    case .widthUnknown: return "unknown"
                    @unknown default: return "unknown"
                    }
                }()
            )
        } else {
            channelInfo = WiFiData.ChannelInfo(number: 0, band: "unknown", width: "unknown")
        }

        return WiFiData(
            timestamp: dateFormatter.string(from: Date()),
            interface: interface.interfaceName ?? "unknown",
            macAddress: interface.hardwareAddress() ?? "failed to retrieve MAC address",
            ssid: interface.ssid() ?? "failed to retrieve SSID",
            bssid: bssid,
            apName: apName,
            phyMode: {
                switch interface.activePHYMode() {
                case .mode11a: return "802.11a"
                case .mode11b: return "802.11b"
                case .mode11g: return "802.11g"
                case .mode11n: return "802.11n"
                case .mode11ac: return "802.11ac"
                case .mode11ax: return "802.11ax"
                case .modeNone: return "none"
                @unknown default: return "unknown"
                }
            }(),
            noiseDBM: interface.noiseMeasurement(),
            rssiDBM: interface.rssiValue(),
            interfaceMode: {
                switch interface.interfaceMode() {
                case .none: return "none"
                case .station: return "station"
                case .hostAP: return "hostAP"
                case .IBSS: return "ibss"
                @unknown default: return "unknown"
                }
            }(),
            channelInfo: channelInfo,
            security: {
                let security = interface.security()
                switch security {
                case .none: return "none"
                case .WEP: return "WEP"
                case .dynamicWEP: return "Dynamic WEP"
                case .wpaPersonal: return "WPA Personal"
                case .wpaPersonalMixed: return "WPA Personal Mixed"
                case .wpaEnterprise: return "WPA Enterprise"
                case .wpaEnterpriseMixed: return "WPA Enterprise Mixed"
                case .wpa2Personal: return "WPA2 Personal"
                case .wpa2Enterprise: return "WPA2 Enterprise"
                case .wpa3Personal: return "WPA3 Personal"
                case .wpa3Enterprise: return "WPA3 Enterprise"
                case .wpa3Transition: return "WPA3 Transition"
                case .personal: return "Personal"
                case .enterprise: return "Enterprise"
                case .OWE: return "OWE"
                case .oweTransition: return "OWE Transition"
                case .unknown: return "unknown"
                @unknown default: return "unknown"
                }
            }(),
            transmitPower: interface.transmitPower(),
            transmitRate: Int(interface.transmitRate()),
            mcsIndex: (interface.value(forKey: "mcsIndex") as? Int).map(String.init) ?? "unknown"
        )
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    private var locationManager: CLLocationManager?
    private var wifiService: WiFiService
    private var outputFormatter: OutputFormatter
    private var showUnits: Bool
    private var selectedFields: [String]?

    override init() {
        self.wifiService = WiFiService()
        self.outputFormatter = JSONFormatter()
        self.showUnits = Constants.defaultShowUnits
        super.init()
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
          \(Constants.jsonKeys.joined(separator: "\n  "))

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

        // 出力フォーマットの設定
        if args.contains("--csv") {
            let showHeader = !args.contains("--no-header")
            outputFormatter = CSVFormatter(showHeader: showHeader)
        }

        // その他のオプションの設定
        showUnits = !args.contains("--no-units")

        if let mappingIndex = args.firstIndex(of: "--bssid-mapping"),
           mappingIndex + 1 < args.count {
            try? wifiService.loadBssidMapping(from: args[mappingIndex + 1])
        }

        if let fieldsIndex = args.firstIndex(of: "--fields"),
           fieldsIndex + 1 < args.count {
            selectedFields = args[fieldsIndex + 1]
                .split(separator: ",")
                .map(String.init)
                .filter { Constants.jsonKeys.contains($0) }

            if selectedFields?.isEmpty ?? true {
                selectedFields = nil
            }
        }

        // 位置情報の許可を要求
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorized {
            do {
                let wifiData = try wifiService.getCurrentWiFiData()
                let output = outputFormatter.format(wifiData, showUnits: showUnits, selectedFields: selectedFields)
                print(output)
            } catch {
                print("error: \(error)")
            }
        } else {
            print("error: location services denied")
        }
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
