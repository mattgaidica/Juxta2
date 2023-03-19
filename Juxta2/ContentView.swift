//
//  ContentView.swift
//  Juxta2
//
//  Created by Matt Gaidica on 3/2/23.
//

import SwiftUI
import CoreBluetooth

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

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager()
    @State var doScan = false
    @State private var isPulsing = false
    @State var isOn: Bool = false
    
    let options: [Option] = [
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
                    .scaleEffect(isPulsing ? 1.25 : 1.0) // scale the text up and down
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { // animate the scale effect
                            isPulsing = true
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
                            Text(String(format: "%.2fV", bleManager.deviceBatteryVoltage))
                            .font(.title)
                            .fontWeight(.thin)
                        Spacer()
                        Text(String(format: "%.0f°F", bleManager.deviceTemperature)).font(.title).fontWeight(.thin)
                        Spacer()
                        Text("\(bleManager.deviceRSSI)dB").font(.title).fontWeight(.thin)
                    }.padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 50))
                }
                Divider().padding()
                VStack {
                    HStack {
                        Picker(selection: $bleManager.deviceAdvertisingMode, label: Text("Select Option"), content: {
                            ForEach(options) { option in
                                Text(option.label).tag(option.value)
                            }
                        })
                    }.pickerStyle(SegmentedPickerStyle())
                        .onChange(of: bleManager.deviceAdvertisingMode) { newValue in
                            bleManager.updateAdvertisingMode()
                        }.padding(.bottom, 10)
                    HStack {
                        Toggle("Scan with magnet present?", isOn: $isOn)
                    }.padding(EdgeInsets(top: 0, leading: 50, bottom: 10, trailing: 50))
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
                }
                
                VStack {
                    Divider().padding()
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
                                Text(peripheral.name ?? "Unknown")
                                Spacer()
                                Text(bleManager.getRSSIString(rssi)).foregroundColor(.green).fontWeight(.black)
                                Text("\(rssi) dB").frame(width:50)
                            }.foregroundColor(.white)
                        }
                    }
                }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
