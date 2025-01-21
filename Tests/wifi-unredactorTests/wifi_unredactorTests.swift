import XCTest
@testable import wifi_unredactor

class WiFiUnredactorTests: XCTestCase {
    // MARK: - Test Data
    var testWiFiData: WiFiData!
    var testChannelInfo: WiFiData.ChannelInfo!

    // MARK: - Setup
    override func setUp() {
        super.setUp()
        testChannelInfo = WiFiData.ChannelInfo(number: 36, band: "5GHz", width: "80MHz")
        testWiFiData = WiFiData(
            timestamp: "2024-01-21T12:00:00.000+0900",
            interface: "en0",
            macAddress: "00:11:22:33:44:55",
            ssid: "TestNetwork",
            bssid: "AA:BB:CC:DD:EE:FF",
            apName: "TestAP",
            phyMode: "802.11ax",
            noiseDBM: -95,
            rssiDBM: -65,
            interfaceMode: "station",
            channelInfo: testChannelInfo,
            security: "WPA3 Personal",
            transmitPower: 20,
            transmitRate: 866,
            mcsIndex: "9"
        )
    }

    override func tearDown() {
        testWiFiData = nil
        testChannelInfo = nil
        super.tearDown()
    }

    // MARK: - WiFiData Tests
    func testWiFiDataInitialization() {
        XCTAssertEqual(testWiFiData.ssid, "TestNetwork")
        XCTAssertEqual(testWiFiData.channelInfo.band, "5GHz")
        XCTAssertEqual(testWiFiData.channelInfo.width, "80MHz")
    }

    // MARK: - JSON Formatter Tests
    func testJSONFormatterBasicOutput() {
        let formatter = JSONFormatter()
        let output = formatter.format(testWiFiData, showUnits: true, selectedFields: nil)

        guard let json = try? parseJSON(output) else {
            XCTFail("JSONのパースに失敗しました")
            return
        }

        // 基本フィールドの検証
        XCTAssertEqual(json["ssid"], "TestNetwork", "SSIDが一致しません")
        XCTAssertEqual(json["interface"], "en0", "インターフェース名が一致しません")
        XCTAssertEqual(json["bssid"], "AA:BB:CC:DD:EE:FF", "BSSIDが一致しません")
        XCTAssertEqual(json["ap_name"], "TestAP", "AP名が一致しません")
    }

    func testJSONFormatterWithUnits() {
        let formatter = JSONFormatter()
        let output = formatter.format(testWiFiData, showUnits: true, selectedFields: nil)

        guard let json = try? parseJSON(output) else {
            XCTFail("JSONのパースに失敗しました")
            return
        }

        // 単位付きの値の検証
        XCTAssertEqual(json["rssi_dbm"], "-65dBm", "RSSI値が一致しません")
        XCTAssertEqual(json["transmit_power"], "20dBm", "送信電力が一致しません")
        XCTAssertEqual(json["transmit_rate"], "866Mbps", "送信レートが一致しません")
    }

    func testJSONFormatterWithoutUnits() {
        let formatter = JSONFormatter()
        let output = formatter.format(testWiFiData, showUnits: false, selectedFields: nil)

        guard let json = try? parseJSON(output) else {
            XCTFail("JSONのパースに失敗しました")
            return
        }

        // 単位なしの値の検証
        XCTAssertEqual(json["rssi_dbm"], "-65", "単位なしRSSI値が一致しません")
        XCTAssertEqual(json["transmit_power"], "20", "単位なし送信電力が一致しません")
        XCTAssertEqual(json["transmit_rate"], "866", "単位なし送信レートが一致しません")
    }

    func testJSONFormatterWithSelectedFields() {
        let formatter = JSONFormatter()
        let selectedFields = ["ssid", "rssi_dbm"]
        let output = formatter.format(testWiFiData, showUnits: true, selectedFields: selectedFields)

        guard let json = try? parseJSON(output) else {
            XCTFail("JSONのパースに失敗しました")
            return
        }

        // 選択したフィールドの検証
        XCTAssertEqual(json.count, 2, "選択したフィールド数が一致しません")
        XCTAssertEqual(json["ssid"], "TestNetwork")
        XCTAssertEqual(json["rssi_dbm"], "-65dBm")

        // 選択していないフィールドが含まれていないことを確認
        XCTAssertNil(json["bssid"], "選択していないフィールドが含まれています")
    }

    // MARK: - CSV Formatter Tests
    func testCSVFormatterBasicOutput() {
        let formatter = CSVFormatter(showHeader: true)
        let output = formatter.format(testWiFiData, showUnits: true, selectedFields: ["ssid", "rssi_dbm"])
        let lines = output.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 2, "CSVの行数が一致しません")
        XCTAssertEqual(lines[0], "ssid,rssi_dbm", "ヘッダーが一致しません")
        XCTAssertEqual(lines[1], "TestNetwork,-65dBm", "データ行が一致しません")
    }

    func testCSVFormatterWithoutHeader() {
        let formatter = CSVFormatter(showHeader: false)
        let output = formatter.format(testWiFiData, showUnits: true, selectedFields: ["ssid", "rssi_dbm"])
        let lines = output.components(separatedBy: "\n")

        XCTAssertEqual(lines.count, 1, "ヘッダーなしCSVの行数が一致しません")
        XCTAssertEqual(lines[0], "TestNetwork,-65dBm", "データ行が一致しません")
    }

    // MARK: - WiFi Service Tests
    func testBSSIDMapping() {
        let wifiService = WiFiService()
        let tempFile = NSTemporaryDirectory() + "test_mapping.csv"
        let mappingContent = """
        AA:BB:CC:DD:EE:FF,TestAP1
        11:22:33:44:55:66,TestAP2
        """
        try? mappingContent.write(toFile: tempFile, atomically: true, encoding: .utf8)

        XCTAssertNoThrow(try wifiService.loadBssidMapping(from: tempFile))

        try? FileManager.default.removeItem(atPath: tempFile)
    }

    // MARK: - Helper Methods
    private func parseJSON(_ jsonString: String) throws -> [String: String] {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] else {
            throw WiFiError.failedToCreateJSON
        }
        return json
    }
}
