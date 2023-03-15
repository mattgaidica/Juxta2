//
//  ContentView.swift
//  Juxta2
//
//  Created by Matt Gaidica on 3/2/23.
//

import SwiftUI
import CoreBluetooth

struct GrowingButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
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
            .padding()
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
            .padding()
            .background(.blue)
            .foregroundColor(.black)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 1.2 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .opacity(bleManager.buttonDisable ? 0.5 : 1)
    }
}

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager()
    @State var doScan = false
    
    let options: [Option] = [
        Option(value: 0, label: "Axy Logger"),
        Option(value: 1, label: "Shelf Mode"),
        Option(value: 2, label: "Base Station")
    ]
    
    var body: some View {
        VStack (spacing: 10) {
            VStack {
                Text("Juxta 2")
                    .font(.largeTitle)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity)
            }
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
                        }.buttonStyle(GrowingButton())
                    }
                    HStack {
                            Text(String(format: "%.2fV", bleManager.batteryVoltage))
                                        .font(.largeTitle)
                        Spacer()
                            Text("\(bleManager.deviceRSSI)dB").font(.largeTitle)
                    }.padding()
                }
                Divider()
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
                        Button(action: {
                            bleManager.readLogCount()
                        }) {
                            Text("Read Log Count")
                        }.buttonStyle(YellowButton())
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%i", bleManager.deviceLogCount)).font(.title2).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceLogCount)).font(.subheadline)
                                
                        }
                        Button(action: {
                            bleManager.clearLogCount()
                        }) {
                            Image(systemName: "trash.slash.fill") // Use the SF Symbols library
                                .font(.system(size: 24)) // Set the font size of the icon
                        }.frame(width: 50).padding().foregroundColor(.white)
                    }
                    HStack {
                        Button(action: {
                            bleManager.readLocalTime()
                        }) {
                            Text("Read Local Time")
                        }.buttonStyle(YellowButton())
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(String(format: "%i", bleManager.deviceLocalTime)).font(.title2).fontWeight(.bold)
                            Text(String(format: "0x%08x", bleManager.deviceLocalTime)).font(.subheadline)
                        }
                        Button(action: {
                            bleManager.updateLocalTime()
                        }) {
                            Image(systemName: "icloud.and.arrow.up.fill") // Use the SF Symbols library
                                .font(.system(size: 24)) // Set the font size of the icon
                        }.frame(width: 50).padding().foregroundColor(.white)
                    }
                }
                
                VStack {
                    Divider()
                    HStack {
                        Text("Other Actions")
                            .font(.headline)
                    }.padding()
                    HStack {
                        Button(action: {
                            bleManager.dumpLogData()
                        }) {
                            Text("Dump Log Data")
                        }.buttonStyle(BlueButton()).disabled(bleManager.buttonDisable)
                        Spacer()
                        Text("n = \(bleManager.textbox.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count)")
                            .font(.footnote)
                        Spacer()
                        Button(action: {
                            bleManager.dumpLogData()
                        }) {
                            Text("Dump Axy Data")
                        }.buttonStyle(BlueButton()).disabled(bleManager.buttonDisable)
                    }
                    
                    HStack {
                        ZStack(alignment: .bottom) {
                            NonEditableTextEditor(text: $bleManager.textbox)
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
                        }.padding().foregroundColor(.white)
                    } else {
                        Button(action: {
                            bleManager.startScan()
                        }) {
                            Text("Start Scanning")
                            
                        }.buttonStyle(BlueButton())
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
                                Text("\(rssi) dB").frame(width:50)
                                Text(bleManager.getRSSIString(rssi)).foregroundColor(.green).fontWeight(.black)
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
