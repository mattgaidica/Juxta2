//
//  ContentView.swift
//  Juxta2
//
//  Created by Matt Gaidica on 3/2/23.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager()
    @State var doScan = false
    @State private var newSubject = ""
    @State private var showSubjectModal = false
    @State private var showAdvancedOptionsModal = false
    @State private var newOptions = BLEManager.AdvancedOptionsStruct(juxtaAdvEvery: 0.0, juxtaScanEvery: 0.0)
    
    let juxtaModes: [Option] = [
        Option(value: 0, label: "Shelf"),
        Option(value: 1, label: "Interval")
//        Option(value: 2, label: "Motion"),
//        Option(value: 3, label: "Base")
    ]
    
    var body: some View {
        VStack (spacing: 10) {
            Spacer()
            VStack {
                HStack {
                    Text(bleManager.dateStr)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                HStack {
                    Text(String(format: "0x%llX • %i", bleManager.seconds, bleManager.seconds))
                        .fontWeight(.light)
                }
            }.padding()
            
            .sheet(isPresented: $bleManager.isConnecting) {
                Text("CONNECTING\n\(bleManager.connectingPeripheralName)")
                    .font(.title)
                    .multilineTextAlignment(.center)
            }
            
            if bleManager.isConnected {
                VStack {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(bleManager.deviceName)
                                .fontWeight(.heavy)
                                .font(.title3)
                            if bleManager.isBase {
                                Text("BASE STATION").font(.subheadline).foregroundColor(.white)
                            } else {
                                Text("ANIMAL LOGGER").font(.subheadline).foregroundColor(.white)
                            }
                        }
                        Spacer()
                        Button(action: {
                            bleManager.disconnect()
                        }) {
                            Text("Disconnect")
                        }.buttonStyle(WhiteButton())
                    }
                    HStack {
                        Text(bleManager.softwareVersion)
                        Spacer()
                        Text(String(format: "%.2fV", bleManager.deviceBatteryVoltage))
                        Spacer()
                        Text(String(format: "%.0f°F", bleManager.deviceTemperature))
                        Spacer()
                        Text("\(bleManager.deviceRSSI)dB")
                    }.padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)).font(.title).fontWeight(.thin)
                }
                Divider().padding(10)
                VStack {
                    HStack {
                        Picker(selection: $bleManager.deviceAdvertisingMode, label: Text("Select Option"), content: {
                            ForEach(juxtaModes) { mode in
                                Text(mode.label).tag(mode.value)
                            }
                        })
                    }.pickerStyle(SegmentedPickerStyle())
                        .onChange(of: bleManager.deviceAdvertisingMode) { newValue in
                            bleManager.updateAdvertisingMode(bleManager.advancedOptions)
                        }.padding(.bottom, 10)
                    HStack {
                        Button(action: {
                            bleManager.readSubject()
                        }) {
                            Text("Read Subject")
                        }.buttonStyle(YellowButton())
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(bleManager.subject)").font(.title3).fontWeight(.bold)
                            Text("Click to Edit").font(.caption).opacity(0.5)
                        }.onTapGesture {
                            newSubject = bleManager.getSubject() // non-publishable string
                            self.showSubjectModal = true
                        }
                    }
                    .onChange(of: showSubjectModal) { _ in
                        // triggers update of newSubject before modal
                    }
                    .sheet(isPresented: $showSubjectModal) {
                        SubjectModalView(newSubject: $newSubject) {doSave in
                            showSubjectModal = false
                            if doSave {
                                bleManager.updateSubject(newSubject)
                            }
                        }
                    }
                    HStack {
                        Button(action: {
                            bleManager.readLogCount()
                        }) {
                            Text("Read Log Count")
                        }.buttonStyle(YellowButton())

                        Button(action: {
                            bleManager.clearLogCount()
                        }) {
                            Text("RESET").font(.headline).foregroundColor(.red)
                        }.padding(10)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%i", bleManager.deviceLogCount)).font(.title3).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceLogCount)).font(.subheadline)
                                
                        }
                    }
                    HStack {
                        Button(action: {
                            bleManager.readMetaCount()
                        }) {
                            Text("Read Meta Count")
                        }.buttonStyle(YellowButton())

                        Button(action: {
                            bleManager.clearMetaCount()
                        }) {
                            Text("RESET").font(.headline).foregroundColor(.red)
                        }.padding(10)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%i", bleManager.deviceMetaCount)).font(.title3).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceMetaCount)).font(.subheadline)
                        }
                    }
                    HStack {
                        Button(action: {
                            bleManager.readLocalTime()
                        }) {
                            Text("Read Local Time")
                        }.buttonStyle(YellowButton())

                        Button(action: {
                            bleManager.updateLocalTime()
                        }) {
                            Text("SYNC").font(.headline).foregroundColor(.white)
                        }.padding(10).border(.white, width: bleManager.syncBorder)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%i", bleManager.deviceLocalTime)).font(.title3).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceLocalTime)).font(.subheadline)
                        }
                    }
                    HStack {
                        Button(action: {
                            newOptions = bleManager.getAdvancedOptions()
                            showAdvancedOptionsModal = true
                        }) {
                            Text("Advanced Options")
                        }
                    }.padding(EdgeInsets(top: 10, leading: 0, bottom: 0, trailing: 0))
                    .onChange(of: showAdvancedOptionsModal) { _ in
                        // This triggers an update when showSheet changes, even without the Text(variableToPass) in the view
                    }
                    .sheet(isPresented: $showAdvancedOptionsModal) {
                        AdvancedOptionsModalView(newOptions: $newOptions, juxtaMode: "\(juxtaModes[Int(bleManager.deviceAdvertisingMode)].label)") { doSave in
                            self.showAdvancedOptionsModal = false
                            if doSave {
                                bleManager.updateAdvertisingMode(newOptions)
                            }
                        }
                    }
                }
                
                VStack {
                    Divider().padding(10)
                    HStack {
                        Button(action: {
                            bleManager.dumpData(bleManager.LOGS_DUMP_KEY)
                        }) {
                            Text("Dump Logs")
                        }.buttonStyle(BlueButton()).disabled(bleManager.buttonDisable).opacity(bleManager.buttonDisable ? 0.5 : 1)
                        Spacer()
                        // include header below (-1)
                        Text("\(bleManager.juxtaTextbox.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count-1)")
                            .font(.footnote).opacity(0.5)
                        Spacer()
                        Button(action: {
                            bleManager.dumpData(bleManager.META_DUMP_KEY)
                        }) {
                            Text("Dump Meta")
                        }.buttonStyle(BlueButton()).disabled(bleManager.buttonDisable).opacity(bleManager.buttonDisable ? 0.5 : 1)
                    }
                    
                    HStack {
                        ZStack(alignment: .bottom) {
                            NonEditableTextEditor(text: $bleManager.juxtaTextbox)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                                .onTapGesture {}
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black]),
                                startPoint: .top,
                                endPoint: .bottom
                            ).frame(height: 20)
                        }
                    }.padding()
                    
                    HStack {
                        Button(action: {
                            bleManager.copyTextbox()
                        }) {
                            Text(bleManager.copyTextboxString.isEmpty ? "Copy Data" : bleManager.copyTextboxString)
                        }
                    }
                }
                
                Spacer()
            } else { // not connected
                HStack {
                    if bleManager.isScanning {
                        Button(action: {
                            bleManager.stopScan()
                        }) {
                            Text("Scanning...")
                        }.foregroundColor(.white).padding(20).font(.title2)
                    } else {
                        Button(action: {
                            bleManager.startScan()
                        }) {
                            Text("Start Scanning")
                        }.buttonStyle(BigBlueButton())
                    }
                }
                NavigationView {
                    List(bleManager.devices.sorted(by: { (peripheral1, peripheral2) -> Bool in
                        guard let rssi1 = bleManager.rssiValues[peripheral1.hash], let rssi2 = bleManager.rssiValues[peripheral2.hash] else {
                            return false
                        }
                        return rssi1.compare(rssi2) == .orderedDescending
                    }), id: \.self) { peripheral in
                        let rssi = bleManager.rssiValues[peripheral.hash] ?? 0
                        Button(action: {
                            bleManager.connect(to: peripheral)
                            doScan = false
                        }) {
                            HStack {
                                Text(peripheral.name ?? "JX")
                                Spacer()
                                Text(bleManager.getRSSIString(rssi)).foregroundColor(.green).fontWeight(.black)
                                Text("\(rssi) dB").frame(width:50)
                            }.foregroundColor(.white)
                        }
                    }
                }
                Text(bleManager.myVersion).font(.footnote).foregroundColor(.gray)
            }
            Spacer()
        }.padding()
    }
}

struct Option: Identifiable {
    let id = UUID()
    let value: UInt8
    let label: String
}

struct NonEditableTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .light)
        textView.isEditable = false
        textView.isSelectable = false
        textView.text = text
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.text = text
    }
}

struct AdvancedOptionsModalView: View {
    @Binding var newOptions: BLEManager.AdvancedOptionsStruct
    var juxtaMode: String
    var completionHandler: (Bool) -> Void
    // Add a new property to store the original value
    @State private var originalVariable: BLEManager.AdvancedOptionsStruct
    
    let juxtaAdvEvery_table = ["1", "2", "5", "10"]
    let juxtaScanEvery_table = ["10","20","30","60"]

    init(newOptions: Binding<BLEManager.AdvancedOptionsStruct>, juxtaMode: String, completionHandler: @escaping (Bool) -> Void) {
        self._newOptions = newOptions
        self.juxtaMode = juxtaMode
        self.completionHandler = completionHandler
        // Initialize the original value to the current value
        self._originalVariable = State(initialValue: newOptions.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                HStack {
                    Text("Currently in ")
                    Text(juxtaMode)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(10)
                        .pickerStyle(.wheel)
                    Text(" Mode")
                }.listRowBackground(Color.clear).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).font(.title2)
                Section(header: Text("Interval Settings")) {
                    VStack(alignment: .leading) {
                        Text("Advertise every...").font(.footnote)
                        Slider(value: $newOptions.juxtaAdvEvery, in: 0...3, step: 1.0)
                        if newOptions.juxtaAdvEvery == 0 {
                            Text("\(juxtaAdvEvery_table[Int(newOptions.juxtaAdvEvery)]) second")
                        } else {
                            Text("\(juxtaAdvEvery_table[Int(newOptions.juxtaAdvEvery)]) seconds")
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Scan every...").font(.footnote)
                        Slider(value: $newOptions.juxtaScanEvery, in: 0...3, step: 1.0)
                        Text("\(juxtaScanEvery_table[Int(newOptions.juxtaScanEvery)]) seconds")
                    }
                }
            }
            .navigationBarItems(trailing: Button("Save") {
                completionHandler(true)
            })
            .navigationBarItems(trailing: Button("Cancel") {
                newOptions = originalVariable
                completionHandler(false)
            }
            )
        }
//        Button(action: {
//            newOptions = BLEManager.AdvancedOptionsStruct(duration: 2.0, modulo: 2.0, fasterEvents: false, isBase: false)
//        }) {
//            Text("Use Defaults")
//        }.buttonStyle(WhiteButton())
    }
}

//@State var isOn: Bool = false
//HStack {
//    Toggle("Scan with magnet present?", isOn: $isOn)
//}.padding(EdgeInsets(top: 0, leading: 50, bottom: 10, trailing: 50))

struct SubjectModalView: View {
    @Binding var newSubject: String // binds to text field
    @State private var originalVariable: String
    var completionHandler: (Bool) -> Void
    
    init(newSubject: Binding<String>, completionHandler: @escaping (Bool) -> Void) {
        self._newSubject = newSubject
        self.completionHandler = completionHandler
        // Initialize the original value to the current value
        self._originalVariable = State(initialValue: newSubject.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("SUBJECT", text: $newSubject).font(.title2)
                Text("Note: A *subject* is associated with a device but not every row of it's data in memory. It is only listed during log dumps for clear archiving.").font(.footnote).opacity(0.5)
            }.autocapitalization(.allCharacters).textContentType(.username)
            .navigationTitle("Edit Subject")
            .navigationBarItems(trailing: Button("Save") {
                if newSubject != "" && newSubject != originalVariable {
                    completionHandler(true)
                } else {
                    cancelCompletion()
                }
                
            })
            .navigationBarItems(trailing: Button("Cancel") {
                cancelCompletion()
            }).padding()
        }
    }
    
    private func cancelCompletion() {
        newSubject = originalVariable
        completionHandler(false)
    }
}

struct WhiteButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(.white)
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct YellowButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width:140)
            .padding(8)
            .background(.yellow)
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BlueButton: ButtonStyle {
    @ObservedObject var bleManager = BLEManager()
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width:130)
            .padding(8)
            .background(.blue)
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BigBlueButton: ButtonStyle {
    @ObservedObject var bleManager = BLEManager()
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(15)
            .font(.title2)
            .background(.blue)
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView().previewDisplayName("Home")
            SubjectModalView(newSubject: .constant("JX")) {_ in
            }.previewDisplayName("Subject")
            AdvancedOptionsModalView(newOptions: .constant(BLEManager.AdvancedOptionsStruct(juxtaAdvEvery: 0.0, juxtaScanEvery: 0.0)), juxtaMode: "Test", completionHandler: {_ in }).previewDisplayName("Options")
        }
    }
}
