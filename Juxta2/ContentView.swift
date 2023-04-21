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
    @State private var isConnectingPulsing = false
    @State private var newSubject = ""
    @State private var showSubjectModal = false
    @State private var showAdvancedOptionsModal = false
    @State private var newOptions = BLEManager.AdvancedOptionsStruct(duration: 0, modulo: 0, extevent: false, usemag: false)
    
    let juxtaModes: [Option] = [
        Option(value: 0, label: "Shelf"),
        Option(value: 1, label: "Interval"),
        Option(value: 2, label: "Motion"),
        Option(value: 3, label: "Base")
    ]
    
    var body: some View {
        VStack (spacing: 10) {
            Spacer()
            VStack {
                HStack {
                    Text(bleManager.dateStr)
                        .font(.title)
                        .fontWeight(.bold)
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
                    .scaleEffect(isConnectingPulsing ? 1.25 : 1.0) // scale the text up and down
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { // animate the scale effect
                            isConnectingPulsing = true
                        }
                    }
            }
            
            if bleManager.isConnected {
                VStack {
                    HStack {
                        Text(bleManager.deviceName)
                            .fontWeight(.heavy)
                            .font(.title2)
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
                            Text("\(bleManager.subject)").font(.title2).fontWeight(.bold)
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
                            Text(String(format: "%i", bleManager.deviceLogCount)).font(.title2).fontWeight(.bold)
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
                            Text(String(format: "%i", bleManager.deviceMetaCount)).font(.title2).fontWeight(.bold)
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
                            Text(String(format: "%i", bleManager.deviceLocalTime)).font(.title2).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceLocalTime)).font(.subheadline)
                        }
                    }
                    HStack {
                        Button(action: {
                            newOptions = bleManager.getAdvancedOptions()
                            showAdvancedOptionsModal = true
                        }) {
                            Text("Advanced Options").font(.caption)
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
                            Text("Dump Log Data")
                        }.buttonStyle(BlueButton()).disabled(bleManager.buttonDisable).opacity(bleManager.buttonDisable ? 0.5 : 1)
                        Spacer()
                        // include header below (-1)
                        Text("\(bleManager.juxtaTextbox.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count-1)")
                            .font(.footnote).opacity(0.5)
                        Spacer()
                        Button(action: {
                            bleManager.dumpData(bleManager.META_DUMP_KEY)
                        }) {
                            Text("Dump Meta Data")
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
                                Text(peripheral.name ?? "JX_X")
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
        }.padding().colorScheme(.dark) // Force dark mode
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
        textView.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.smallSystemFontSize, weight: .light)
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
    
    let durationDisplay = ["1", "2", "5", "10"]
    let moduloDisplay = ["30", "60", "360", "3600"]

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
                }.listRowBackground(Color.clear).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).font(.title)
                Section(header: Text("Interval Settings")) {
                    VStack(alignment: .leading) {
                        Text("Scan/Advertise for...").font(.footnote)
                        Slider(value: $newOptions.duration, in: 0...3, step: 1.0)
                        if newOptions.duration == 0 {
                            Text("\(durationDisplay[Int(newOptions.duration)]) second")
                        } else {
                            Text("\(durationDisplay[Int(newOptions.duration)]) seconds")
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Every... (modulo time)").font(.footnote)
                        Slider(value: $newOptions.modulo, in: 0...3, step: 1.0)
                        Text("\(moduloDisplay[Int(newOptions.modulo)]) seconds")
                    }
                }
                Section {
                    VStack {
                        Toggle("Increase event logging rate?", isOn: $newOptions.extevent)
                        HStack {
                            Text("From a maximum of 60s to 10s (eg, motion).").font(.footnote).opacity(0.5).multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                }
                Section {
                    Text("__Shelf__ mode only advertises when the device is pointing skywards. It keeps time, but does not log anything.").padding(0)
                    Text("__Interval__ mode uses the interval settings turn on scanning and advertising at a set rate. It also logs motion events.")
                    Text("__Motion__ mode only logs motion events (no radio).")
                    Text("__Base__ mode is a special type of interval that increases radio power and turns off event logging.")
                }.listRowBackground(Color.clear).font(.footnote).listRowInsets(EdgeInsets())
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
        Button(action: {
            newOptions = BLEManager.AdvancedOptionsStruct(duration: 2.0, modulo: 1.0, extevent: false, usemag: false)
        }) {
            Text("Use Defaults")
        }.buttonStyle(WhiteButton())
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
                TextField("SUBJECT", text: $newSubject).font(.title)
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
            .padding(10)
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
            .frame(width:150)
            .padding(10)
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
            .padding(10)
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
            .padding(20)
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
        ContentView()
    }
}
