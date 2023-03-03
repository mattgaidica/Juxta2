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

struct ContentView: View {
    @ObservedObject var bleManager = BLEManager()
 
    var body: some View {
        VStack (spacing: 10) {
            VStack {
                Text("Juxta 2")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Status goes here
            if bleManager.isSwitchedOn {
                Text("Bluetooth is switched on")
            }
            else {
                Text("Bluetooth is NOT switched on")
            }
            
            HStack {
                VStack {
                    Button(action: {
                        self.bleManager.startScanning()
                    }) {
                        Text("Start Scanning")
                    }.buttonStyle(GrowingButton())
                }.padding()

                VStack {
                    Button(action: {
                        self.bleManager.stopScanning()
                    }) {
                        Text("Stop Scanning")
                    }.buttonStyle(GrowingButton())
                }.padding()
            }
            
            NavigationView {
                List(bleManager.devices, id: \.self) { peripheral in
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unknown")
                        Text("RSSI: \(bleManager.rssiValues[peripheral.hash] ?? 0) dBm")
                    }.onTapGesture {
                        bleManager.connect(to: peripheral)
                    }
                }
            }.frame(height: 400)
        
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
