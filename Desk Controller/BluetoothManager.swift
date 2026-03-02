//
//  BluetoothManager.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Foundation
@preconcurrency import CoreBluetooth

@MainActor
class BluetoothManager: NSObject {

    var stopOnFirstConnection = true

    // Singleton for managing it all
    static let shared = BluetoothManager()

    var centralManager: CBCentralManager?

    var onCentralManagerStateChange: (CBCentralManager?) -> Void = { _ in }

    var onConnectedPeripheralChange: (CBPeripheral?) -> Void = { _ in  }
    private var connectPeripheralRSSI: NSNumber?
    var connectedPeripheral: CBPeripheral? // Or is currently being connected to


    // Not currently used... just in case I want to handle multiple desks at once
    var onAvailablePeripheralsChange: ([CBPeripheral]) -> Void = { _ in }
    private var availablePeripherals = [CBPeripheral]() {
        didSet {
            onAvailablePeripheralsChange(availablePeripherals)
        }
    }


    // It will only match if the Name contains 'Desk' in it
    var matchCriteria: (CBPeripheral) -> Bool = { peripheral in
        guard let name = peripheral.name, name.contains("Desk") else {
            return false
        }
        return true
    }


    override init() {
        super.init()
        startScanning()
    }

    func startScanning() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    func reconnect() {
        guard let peripheral = connectedPeripheral,
              peripheral.state == .disconnected else {
                  return
        }

        centralManager?.connect(peripheral, options: nil)
    }
}

extension BluetoothManager: CBCentralManagerDelegate {

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            centralManager = central
            onCentralManagerStateChange(central)

            guard central.state == .poweredOn else {
                return
            }

            if let connectedPeripheral = connectedPeripheral, connectedPeripheral.state == .disconnected {
                central.connect(connectedPeripheral, options: nil)
                return
            }
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            guard connectedPeripheral != peripheral, matchCriteria(peripheral) else {
                return
            }

            if !availablePeripherals.contains(peripheral) {
                availablePeripherals.append(peripheral)
            }

            let isClosestMatchingPeripheral = (connectPeripheralRSSI != nil && RSSI.intValue < connectPeripheralRSSI!.intValue)

            if connectedPeripheral == nil || isClosestMatchingPeripheral {
                central.connect(peripheral, options: nil)
                connectPeripheralRSSI = RSSI
                connectedPeripheral = peripheral
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated {
            guard peripheral == connectedPeripheral else {
                return
            }

            if stopOnFirstConnection {
                central.stopScan()
            }

            onConnectedPeripheralChange(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral == connectedPeripheral else {
                return
            }

            connectPeripheralRSSI = nil
            connectedPeripheral = nil

            onConnectedPeripheralChange(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard peripheral == connectedPeripheral else {
                return
            }

            connectPeripheralRSSI = nil
            connectedPeripheral = nil

            onConnectedPeripheralChange(nil)
        }
    }

}
