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

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    var myCentral: CBCentralManager!
    @Published var isConnected: Bool = true
    @Published var isSwitchedOn = false
    @Published var devices: [CBPeripheral] = []
    @Published var rssiValues: [Int: NSNumber] = [:]
    @Published var deviceName: String = "JX_XXXXXXXXXXXX"
    @Published var deviceRSSI: Int = 0
    @Published var deviceLogCount: UInt32 = 0
    @Published var deviceLocalTime: UInt32 = 0
    @Published var deviceAdvertisingMode: UInt8 = 0
    @Published var textbox: String = "Log data..."
    @Published var isScanning: Bool = false
    @Published var currentTime: String = "XXX X, XXXX XX:XX"
    @Published var hexTime: String = "0xXXXXXXXX"
    @Published var copyTextboxString: String = ""

    private var discoveredDevices = Set<CBPeripheral>()
    private var connectedPeripheral: CBPeripheral?
    private var timerRSSI: Timer?
    private var timerScan: Timer?
    private var timer1Hz: Timer?
    private var timerData: Timer?
    private var localTimeChar: CBCharacteristic?
    private var logCountChar: CBCharacteristic?
    private var advertiseModeChar: CBCharacteristic?
    private var dataChar: CBCharacteristic?
    private var dataInitKey: UInt8 = 0xFF
    private var dataExitKey: UInt8 = 0x00
    private var dataLineLength = 17 // see JUXTA_LOG_SIZE
    private var hexTimeData: [UInt8] = [0,0,0,0]
    private var dataCount: UInt32 = 0
    // data vars
    private var data_logCount: UInt32 = 0
    private var data_scanAddr: [UInt8] = [0,0,0,0,0,0]
    private var data_localTime: UInt32 = 0
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
        self.timer1Hz = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.currentTime = self.getDateTimeStr()
            self.hexTime = self.getHexTimeStr()
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
        textbox = ""
        deviceName = peripheral.name ?? "Unknown"
        connectedPeripheral = peripheral
        self.timerRSSI = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            peripheral.readRSSI()
        }
        resetDevices()
        devices.append(peripheral)
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == CBUUIDs.JuxtaService {
                peripheral.discoverCharacteristics([CBUUIDs.JuxtaLogCountChar, CBUUIDs.JuxtaLocalTimeChar, CBUUIDs.JuxtaAdvertiseModeChar, CBUUIDs.JuxtaDataChar], for: service)
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
                if characteristic.uuid == CBUUIDs.JuxtaLocalTimeChar {
                    jprint("LocalTime characteristic found")
                    localTimeChar = characteristic
                    readLocalTime()
                }
                if characteristic.uuid == CBUUIDs.JuxtaAdvertiseModeChar {
                    jprint("AdvertiseMode characteristic found")
                    advertiseModeChar = characteristic
                    readAdvertisingMode()
                }
                if characteristic.uuid == CBUUIDs.JuxtaDataChar {
                    jprint("Data characteristic found")
                    dataChar = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
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
        print("Failed to connect to peripheral: \(peripheral.name ?? "")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.timerRSSI?.invalidate()
        self.timerRSSI = nil
        isConnected = false
        resetDevices()
        print("Disconnected from peripheral: \(peripheral.name ?? "")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == dataChar {
            var data: UInt8 = 0
            if let characteristicValue = characteristic.value {
                data = characteristicValue[0]
            }
            timerData?.invalidate()
            timerData = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { timer in
                print("Download done")
                self.exitData() // reset log count on Juxta, no notify back
            }
            initData() // ask for more
            dataCount += 1
            print(dataCount)

            let n = dataCount % 17
            switch n {
            case 1: // header
                break;
            case 2: // header
                break;
            case 3: // log count
                data_logCount = data_logCount | UInt32(data) << 0
            case 4: // log count
                data_logCount = data_logCount | UInt32(data) << 8
            case 5: // log count
                data_logCount = data_logCount | UInt32(data) << 16
            case 6: // log count
                data_logCount = data_logCount | UInt32(data) << 24
                nprint(String(format: "%05d,", data_logCount))
            case 7:
                data_scanAddr[5] = data
            case 8:
                data_scanAddr[4] = data
            case 9:
                data_scanAddr[3] = data
            case 10:
                data_scanAddr[2] = data
            case 11:
                data_scanAddr[1] = data
            case 12:
                data_scanAddr[0] = data
                nprint(data_scanAddr.map { String(format: "%X", $0) }.joined(separator: ":") + ",");
            case 13:
                var RSSIInt8: Int8 = 0
                withUnsafePointer(to: &data) { ptr in
                    ptr.withMemoryRebound(to: Int8.self, capacity: 1) { intPtr in
                        RSSIInt8 = intPtr.pointee
                    }
                }
                nprint(String(format: "%i,", RSSIInt8))
            case 14:
                data_localTime = data_localTime | UInt32(data) << 0
            case 15:
                data_localTime = data_localTime | UInt32(data) << 8
            case 16:
                data_localTime = data_localTime | UInt32(data) << 16
            case 0: // ie, 17
                data_localTime = data_localTime | UInt32(data) << 24
                nprint(String(format: "0x%llX\n", data_localTime))
                resetDataVars()
            default:
                break;
            }
        }
        if characteristic == logCountChar {
            let data:Data = characteristic.value!
            deviceLogCount = rev32(data)
        }
        if characteristic == localTimeChar {
            let data:Data = characteristic.value!
            deviceLocalTime = rev32(data)
        }
        if characteristic == advertiseModeChar {
            if let characteristicValue = characteristic.value {
                deviceAdvertisingMode = characteristicValue[0]
            }
        }
    }
    
    func rev32(_ data: Data) -> UInt32 {
        var int32val: UInt32 = 0
        let _ = data.withUnsafeBytes { pointer in
            int32val = pointer.load(as: UInt32.self)
        }
        let int32data = withUnsafeBytes(of: &int32val) { Data($0) }  // Convert to byte sequence
        let reversedData = Data(int32data.reversed())  // Reverse byte sequence
        return reversedData.withUnsafeBytes { $0.load(as: UInt32.self) }  // Convert back to Int32
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScan()
        self.timerScan?.invalidate()
        self.timerScan = nil
        myCentral.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        isConnected = false
        resetDevices()
        if let peripheral = self.connectedPeripheral {
            myCentral.cancelPeripheralConnection(peripheral)
        }
    }
    
    func startScan() {
        print("Starting scan")
        isScanning = true
        myCentral.scanForPeripherals(withServices: [CBUUIDs.JuxtaService], options: nil)
        self.timerScan = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.stopScan()
        }
     }
    
    func stopScan() {
        print("Stopping scan")
        isScanning = false
        myCentral.stopScan()
    }
    
    func resetDevices() {
        devices = []
        discoveredDevices = Set<CBPeripheral>()
    }
    
    func getDateTimeStr() -> String {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, YYYY HH:mm:ss"
        return dateFormatter.string(from: date)
    }
    
    func getHexTimeStr() -> String {
        let seconds =  UInt32(NSDate().timeIntervalSince1970)
        let hexDateString = String(format: "0x%llX", seconds)
        hexTimeData[3] = UInt8(seconds & 0xFF)
        hexTimeData[2] = UInt8(seconds >> 8 & 0xFF)
        hexTimeData[1] = UInt8(seconds >> 16 & 0xFF)
        hexTimeData[0] = UInt8(seconds >> 24 & 0xFF)
        return hexDateString
    }
    
    func readLogCount() {
        if let peripheral = connectedPeripheral, let characteristic = logCountChar {
            jprint("Reading log count")
            peripheral.readValue(for: characteristic)
        }
    }
    
    func readLocalTime() {
        if let peripheral = connectedPeripheral, let characteristic = localTimeChar {
            jprint("Reading local time")
            peripheral.readValue(for: characteristic)
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
    
    func updateLocalTime() {
        if let peripheral = connectedPeripheral, let characteristic = localTimeChar {
            jprint("Updating local time")
            let data = Data(hexTimeData)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            readLocalTime()
        }
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
    
    func jprint(_ text: String) {
        print(text)
        textbox = text + "\n" + textbox
    }
    func nprint(_ text: String) {
        textbox = textbox + text
    }
    
    func copyTextbox() {
        UIPasteboard.general.string = textbox
        copyTextboxString = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.copyTextboxString = ""
        }
    }
    
    func dumpLogData() {
        dataCount = 0
        textbox = ""
        resetDataVars()
        initData()
    }
    
    func initData() {
        if let peripheral = connectedPeripheral, let characteristic = dataChar {
            let data = Data([dataInitKey])
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }
    
    func exitData() {
        if let peripheral = connectedPeripheral, let characteristic = dataChar {
            let data = Data([dataExitKey])
            // make sure logCount is reset on Juxta, no notification
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
            dataCount = 0
        }
    }
    func resetDataVars() {
        data_logCount = 0
        data_scanAddr = [0,0,0,0,0,0]
        data_localTime = 0
    }
}
