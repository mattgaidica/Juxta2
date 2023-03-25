//
//  Juxta2App.swift
//  Juxta2
//
//  Created by Matt Gaidica on 3/2/23.
//
import Foundation
import SwiftUI
import CoreBluetooth

@main
struct Juxta2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}

struct ActivityViewController: UIViewControllerRepresentable {
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
    
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var myCentral: CBCentralManager!
    @Published var isConnected: Bool = true
    @Published var isConnecting: Bool = false
    @Published var isSwitchedOn = false
    @Published var devices: [CBPeripheral] = []
    @Published var rssiValues: [Int: NSNumber] = [:]
    
    @Published var deviceName: String = "JX_XXXXXXXXXXXX"
    @Published var deviceRSSI: Int = 0
    @Published var deviceLogCount: UInt32 = 0
    @Published var deviceLocalTime: UInt32 = 0
    @Published var deviceMetaCount: UInt32 = 0
    @Published var deviceAdvertisingMode: UInt8 = 0
    @Published var deviceBatteryVoltage: Float = 0.0
    @Published var deviceTemperature: Float = 0.0
    
    @Published var juxtaTextbox: String = "Data..."
    @Published var isScanning: Bool = false
    @Published var dateStr: String = "XXX X, XXXX XX:XX"
    @Published var copyTextboxString: String = ""
    @Published var seconds: UInt32 = 0
    @Published var buttonDisable: Bool = false
    @Published var connectingPeripheralName: String = ""
    @Published var syncBorder: CGFloat = 0
    @Published var subject: String = "SUBJECT"
    
    public let RESET_DUMP_KEY: UInt8 = 0x00
    public let LOGS_DUMP_KEY: UInt8 = 0x11
    public let META_DUMP_KEY: UInt8 = 0x22
    private let JUXTA_LOG_LENGTH: UInt32 = 13
    private let JUXTA_META_LENGTH: UInt32 = 7
    public let DATA_TYPES = ["xl","mg","conn"]
    
    private var discoveredDevices = Set<CBPeripheral>()
    private var connectedPeripheral: CBPeripheral?
    private var timerRSSI: Timer?
    private var timerScan: Timer?
    private var timer1Hz: Timer?
    private var timerData: Timer?
    private var connectTimeoutTimer: Timer?
    
    private var localTimeChar: CBCharacteristic?
    private var logCountChar: CBCharacteristic?
    private var advertiseModeChar: CBCharacteristic?
    private var dataChar: CBCharacteristic?
    private var deviceBatteryVoltageChar: CBCharacteristic?
    private var metaCountChar: CBCharacteristic?
    private var deviceTemperatureChar: CBCharacteristic?
    private var commandChar: CBCharacteristic?
    private var subjectChar: CBCharacteristic?
    
    private var hexTimeData = [UInt8](repeating: 0, count: 4)
    private var dumpType: UInt8 = 0
    
    // data vars
    private var data_logCount: UInt32 = 0
    private var data_scanAddr = [UInt8](repeating: 0, count: 6)
    private var data_localTime: UInt32 = 0
    private var data_temp: Int16 = 0
    private var data_voltage: UInt16 = 0
    private var data_xl = [Int16](repeating: 0, count: 3)
    private var data_mg = [Int16](repeating: 0, count: 3)
    private var dataBuffer = [UInt8](repeating: 0, count: 128)
    private var subjectBuffer = [UInt8](repeating: 0, count: 16) // see JUXTAPROFILE_SUBJECT_LEN
    private var dataPos: UInt32 = 0
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
        timer1Hz = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.dateStr = self.getDateStr()
            self.seconds = UInt32(NSDate().timeIntervalSince1970)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
            isConnected = false // reset on phone
        }
        else {
            isSwitchedOn = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        rssiValues[peripheral.hash] = RSSI
        if !discoveredDevices.contains(peripheral) {
            discoveredDevices.insert(peripheral)
            devices.append(peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectTimeoutTimer?.invalidate()
        isConnecting = false
        juxtaTextbox = ""
        deviceName = peripheral.name ?? "Unknown"
        connectedPeripheral = peripheral
        self.timerRSSI = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            peripheral.readRSSI()
        }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == CBUUIDs.JuxtaService {
                peripheral.discoverCharacteristics([CBUUIDs.JuxtaLogCountChar, CBUUIDs.JuxtaMetaCountChar, CBUUIDs.JuxtaLocalTimeChar, CBUUIDs.BatteryVoltageChar, CBUUIDs.DeviceTemperatureChar, CBUUIDs.JuxtaAdvertiseModeChar, CBUUIDs.JuxtaDataChar, CBUUIDs.JuxtaCommandChar, CBUUIDs.JuxtaSubjectChar], for: service)
            }
            jprint("Service discovered: \(service.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                if characteristic.uuid == CBUUIDs.JuxtaLogCountChar {
                    jprint("LogCount characteristic found")
                    logCountChar = characteristic
                    readLogCount()
                }
                if characteristic.uuid == CBUUIDs.JuxtaMetaCountChar {
                    jprint("MetaCount characteristic found")
                    metaCountChar = characteristic
                    readMetaCount()
                }
                if characteristic.uuid == CBUUIDs.JuxtaLocalTimeChar {
                    jprint("LocalTime characteristic found")
                    localTimeChar = characteristic
                    readLocalTime()
                }
                if characteristic.uuid == CBUUIDs.BatteryVoltageChar {
                    jprint("Battery characteristic found - notify")
                    deviceBatteryVoltageChar = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.uuid == CBUUIDs.DeviceTemperatureChar {
                    jprint("Temperature characteristic found - notify")
                    deviceTemperatureChar = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.uuid == CBUUIDs.JuxtaAdvertiseModeChar {
                    jprint("AdvertiseMode characteristic found")
                    advertiseModeChar = characteristic
                    readAdvertisingMode()
                }
                if characteristic.uuid == CBUUIDs.JuxtaDataChar {
                    jprint("Data characteristic found - notify")
                    dataChar = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                if characteristic.uuid == CBUUIDs.JuxtaCommandChar {
                    jprint("Command characteristic found")
                    commandChar = characteristic
                }
                if characteristic.uuid == CBUUIDs.JuxtaSubjectChar {
                    jprint("Subject characteristic found")
                    subjectChar = characteristic
                    readSubject()
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if error != nil {
            jprint("Failed to read RSSI: \(error!.localizedDescription)")
            return
        }
        rssiValues[peripheral.hash] = RSSI // old
        deviceRSSI = RSSI.intValue
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isConnecting = false
        print("Failed to connect to peripheral: \(peripheral.name ?? "")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.timerRSSI?.invalidate()
        self.timerRSSI = nil
        isConnected = false
        resetDevices()
        print("Disconnected from peripheral: \(peripheral.name ?? "")")
    }
    
    func connect(to peripheral: CBPeripheral) {
        connectingPeripheralName = peripheral.name ?? ""
        isConnecting = true
        stopScan()
        myCentral.connect(peripheral, options: nil)
        connectTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            if !self.isConnected {
                self.myCentral.cancelPeripheralConnection(peripheral)
                self.disconnect()
            }
            self.connectTimeoutTimer?.invalidate()
        }
    }
    
    func disconnect() {
        isConnected = false
        isConnecting = false
        if let peripheral = self.connectedPeripheral {
            myCentral.cancelPeripheralConnection(peripheral)
        }
        resetDevices()
    }
    
    func startScan() {
        print("Starting scan")
        isScanning = true
        resetDevices()
        // !! this will not update RSSI unless scanning is looped
        var loopCount = 0
        timerScan = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            if loopCount < 5 {
                self.myCentral.scanForPeripherals(withServices: [CBUUIDs.JuxtaService], options: nil)
                loopCount += 1
            } else {
                self.stopScan()
            }
        }
    }
    
    func stopScan() {
        print("Stopping scan")
        isScanning = false
        timerScan?.invalidate()
        timerScan = nil
        myCentral.stopScan()
    }
    
    func resetDevices() {
        devices = []
        discoveredDevices = Set<CBPeripheral>()
        rssiValues = [:]
        connectedPeripheral = nil
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == logCountChar {
            let data:Data = characteristic.value!
            let _ = data.withUnsafeBytes { pointer in
                deviceLogCount = pointer.load(as: UInt32.self)
            }
        }
        if characteristic == metaCountChar {
            let data:Data = characteristic.value!
            let _ = data.withUnsafeBytes { pointer in
                deviceMetaCount = pointer.load(as: UInt32.self)
            }
        }
        if characteristic == localTimeChar {
            let data:Data = characteristic.value!
            let _ = data.withUnsafeBytes { pointer in
                deviceLocalTime = pointer.load(as: UInt32.self)
                let nowSeconds = UInt32(NSDate().timeIntervalSince1970)
                let borderSize = 3.0
                if deviceLocalTime == nowSeconds || deviceLocalTime == nowSeconds + 1 || deviceLocalTime == nowSeconds - 1 {
                    jprint(">>> TIME DIFF: JUXTA & IOS EQUAL <<<")
                    syncBorder = 0
                } else if deviceLocalTime > nowSeconds {
                    jprint(String(format: ">>> TIME DIFF: JUXTA BEHIND BY %is <<<", deviceLocalTime - nowSeconds))
                    syncBorder = borderSize
                } else {
                    jprint(String(format: ">>> TIME DIFF: JUXTA BEHIND BY %is <<<", nowSeconds - deviceLocalTime))
                    syncBorder = borderSize
                }
            }
        }
        if characteristic == deviceTemperatureChar {
            if let characteristicValue = characteristic.value {
                let bytes = [UInt8](characteristicValue)
                let data = Data(_: bytes)
                let degC = data.withUnsafeBytes { $0.load(as: Float.self) }
                deviceTemperature = degC * (9/5) + 32 // convert to F
            }
        }
        if characteristic == deviceBatteryVoltageChar {
            if let characteristicValue = characteristic.value {
                let bytes = [UInt8](characteristicValue)
                let data = Data(_: bytes)
                let uint32Value = data.withUnsafeBytes { $0.load(as: UInt32.self) }
                deviceBatteryVoltage = Float(uint32Value) / 1e6
            }
        }
        if characteristic == advertiseModeChar {
            if let characteristicValue = characteristic.value {
                deviceAdvertisingMode = characteristicValue[0]
            }
        }
        if characteristic == dataChar {
            guard let characteristicValue = characteristic.value else { return }
            if characteristicValue.count == dataBuffer.count {
                characteristicValue.withUnsafeBytes {
                    dataBuffer = [UInt8](UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: characteristicValue.count))
                }
                var forceExit: Bool = false
                let UUIDString = CBUUIDs.JuxtaService.uuidString.suffix(4).dropFirst(2)
                if dumpType == LOGS_DUMP_KEY {
                    for i in 0...dataBuffer.count-1 {
                        dataPos += 1
                        var data = dataBuffer[i]
                        switch dataPos % JUXTA_LOG_LENGTH {
                        case 1: // header
                            if String(format: "%02X", data) != UUIDString {
                                forceExit = true
                            }
                        case 2: // header
                            break
                        case 3:
                            data_scanAddr[5] = data
                        case 4:
                            data_scanAddr[4] = data
                        case 5:
                            data_scanAddr[3] = data
                        case 6:
                            data_scanAddr[2] = data
                        case 7:
                            data_scanAddr[1] = data
                        case 8:
                            data_scanAddr[0] = data
                            nprint(data_scanAddr.map { String(format: "%X", $0) }.joined(separator: ":") + ",");
                        case 9:
                            var RSSIInt8: Int8 = 0
                            withUnsafePointer(to: &data) { ptr in
                                ptr.withMemoryRebound(to: Int8.self, capacity: 1) { intPtr in
                                    RSSIInt8 = intPtr.pointee
                                }
                            }
                            nprint(String(format: "%i,", RSSIInt8))
                        case 10:
                            data_localTime = data_localTime | UInt32(data) << 0
                        case 11:
                            data_localTime = data_localTime | UInt32(data) << 8
                        case 12:
                            data_localTime = data_localTime | UInt32(data) << 16
                        case 0: // ie, 13
                            data_localTime = data_localTime | UInt32(data) << 24
                            nprint(String(format: "%i\n", data_localTime))
                            resetVars()
                        default:
                            break
                        }
                        if forceExit {
                            print("forcing log exit")
                            break
                        }
                    }
                    if !forceExit {
                        requestData() // ask for more
                    }
                }
                if dumpType == META_DUMP_KEY {
                    for i in 0...dataBuffer.count-1 {
                        dataPos += 1
                        let data = dataBuffer[i]
                        print(String(format: "%i - %i - %02X", dataPos,dataPos % JUXTA_META_LENGTH, data))
                        switch dataPos % JUXTA_META_LENGTH {
                        case 1: // header
                            if String(format: "%02X", data) != UUIDString {
                                forceExit = true
                            }
                        case 2: // header
                            nprint(String(format: "%@,", subject))
                        case 3: // datatype
                            nprint(String(format: "%@,", DATA_TYPES[Int(data)]))
                        case 4: // temp
                            data_localTime = data_localTime | UInt32(data) << 0
                        case 5:
                            data_localTime = data_localTime | UInt32(data) << 8
                        case 7:
                            data_localTime = data_localTime | UInt32(data) << 16
                        case 0: // ie, 22
                            data_localTime = data_localTime | UInt32(data) << 24
                            nprint(String(format: "%i\n", data_localTime))
                            resetVars()
                        default:
                            break
                        }
                        if forceExit {
                            print("forcing meta exit")
                            break
                        }
                    }
                    if !forceExit {
                        requestData() // ask for more
                    }
                }
                resetDataTimer()
            }
        }
        if characteristic == subjectChar {
            if let characteristicValue = characteristic.value {
                let bytes = characteristicValue.filter { $0 != 0 }
                subject = String(bytes: bytes, encoding: .utf8) ?? ""
            }
        }
    }
    
    func getDateStr() -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, YYYY HH:mm:ss"
        return dateFormatter.string(from: date)
    }
    
    func readLogCount() {
        if let peripheral = connectedPeripheral, let characteristic = logCountChar {
            jprint("Reading log count")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func readMetaCount() {
        if let peripheral = connectedPeripheral, let characteristic = metaCountChar {
            jprint("Reading meta count")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func readLocalTime() {
        if let peripheral = connectedPeripheral, let characteristic = localTimeChar {
            jprint("Reading local time")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func updateLocalTime() {
        if let peripheral = connectedPeripheral, let characteristic = localTimeChar {
            jprint("Updating local time")
            var seconds =  UInt32(NSDate().timeIntervalSince1970)
            let data = Data(bytes: &seconds, count: MemoryLayout<UInt32>.size)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            readLocalTime()
        }
    }
    
    func readAdvertisingMode() {
        if let peripheral = connectedPeripheral, let characteristic = advertiseModeChar {
            jprint("Reading advertising mode")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func updateAdvertisingMode() {
        if let peripheral = connectedPeripheral, let characteristic = advertiseModeChar {
            jprint("Updating advertising mode")
            let data = Data([deviceAdvertisingMode])
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func readSubject() {
        if let peripheral = connectedPeripheral, let characteristic = subjectChar {
            jprint("Reading subject")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func updateSubject() {
        if let peripheral = connectedPeripheral, let characteristic = subjectChar {
            jprint("Updating subject")
            for (i, byte) in subject.utf8.prefix(subjectBuffer.count).enumerated() {
                subjectBuffer[i] = byte
            }
            peripheral.writeValue(Data(subjectBuffer), for: characteristic, type: .withResponse)
        }
        readSubject()
    }
    
    func clearLogCount() {
        if let peripheral = connectedPeripheral, let characteristic = logCountChar {
            jprint("Clearing log count")
            let clearData: [UInt8] = [0,0,0,0]
            let data = Data(clearData)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            readLogCount()
        }
    }
    
    func clearMetaCount() {
        if let peripheral = connectedPeripheral, let characteristic = metaCountChar {
            jprint("Clearing meta count")
            let clearData: [UInt8] = [0,0,0,0]
            let data = Data(clearData)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            readMetaCount()
        }
    }
    
    func jprint(_ text: String) {
        print(text)
        juxtaTextbox = text + "\n" + juxtaTextbox
    }
    func nprint(_ text: String) {
        juxtaTextbox = juxtaTextbox + text
    }
    
    func copyTextbox() {
        UIPasteboard.general.string = juxtaTextbox
        copyTextboxString = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.copyTextboxString = ""
        }
    }
    
    func dumpData(_ dt: UInt8) {
        buttonDisable = true
        dumpType = dt
        if dumpType == LOGS_DUMP_KEY {
            juxtaTextbox = "subject,my_mac,their_mac,rssi,local_time\n"
        } else if dumpType == META_DUMP_KEY {
            juxtaTextbox = "subject,data_type,local_time\n"
        }
        resetVars()
        dataPos = 0
        resetDataTimer()
        requestData()
    }
    
    func resetDataTimer() {
        timerData?.invalidate()
        timerData = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { timer in
            print("Download done")
            self.buttonDisable = false
            self.dumpType = self.RESET_DUMP_KEY
            self.requestData() // reset! this has no response
        }
    }
    
    func resetVars() {
        data_logCount = 0
        data_scanAddr = [UInt8](repeating: 0, count: 6)
        data_localTime = 0
        data_temp = 0
        data_voltage = 0
        data_xl = [Int16](repeating: 0, count: 3)
        data_mg = [Int16](repeating: 0, count: 3)
    }
    
    func requestData() {
        if let peripheral = connectedPeripheral, let characteristic = commandChar {
            peripheral.writeValue(Data([dumpType]), for: characteristic, type: .withResponse)
        }
    }
    
    func getJuxtaSettings() -> String {
        return "NA"
    }
    
    func getRSSIString(_ rssi: NSNumber) -> String {
        return String(repeating: "•", count: Int(127 - abs(rssi.intValue)) / 8)
    }
    
    func lsm303agr_from_fs_2g_hr_to_mg(_ lsb: Int16) -> Float {
        return (Float(lsb) / 16.0) * 0.98;
    }
    
    func juxta_raw_voltage_to_actual(_ lsb: UInt16) -> Float {
        return (Float(lsb) * 250) / 100 / 1000
    }
    
    func lsm303agr_from_lsb_hr_to_celsius(_ lsb: Int16) -> Float {
        ((Float(data_temp) / 64.0) / 4.0) + 25.0
    }
    
    func lsm303agr_from_lsb_to_mgauss(_ lsb: Int16) -> Float {
        return Float(lsb) * 1.5
    }
}
