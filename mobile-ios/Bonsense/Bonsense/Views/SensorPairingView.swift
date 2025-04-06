//
//  SensorReadingView.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-03-17.
//

import SwiftUI

struct SensorPairingView: View {
    @ObservedObject var bluetoothViewModel: BLECentralViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            BonsaiTheme.backgroundGradient()
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // TITLE
                Text("Sensor Connection")
                    .font(BonsaiTheme.titleFont)
                    .foregroundColor(BonsaiTheme.primaryGreen)
                    .padding(.top)
                
                if bluetoothViewModel.isScanning {
                    // SCANNING ANIMATION
                    scanningView
                } else if bluetoothViewModel.discoveredDevices.isEmpty {
                    // NO DEVICES FOUND
                    noDevicesView
                } else {
                    // DEVICE SELECTION
                    deviceSelectionView
                }
                
                // STATUS CARD - Automatically updates based on isConnected
                connectionStatusCard
                
                Spacer()
                
                // NAVIGATION LINK TO RESULTS
                NavigationLink(
                    destination: ResultView(viewModel: ResultViewModel(waterLevel: bluetoothViewModel.waterLevel ?? WaterLevel(percentage: 0)))
                        .environmentObject(bluetoothViewModel),
                    isActive: $bluetoothViewModel.navigateToResult
                ) {
                    EmptyView()
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading: backButton)
    }
    
    // MARK: - Component Views
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(BonsaiTheme.primaryGreen)
        }
    }
    
    private var scanningView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(BonsaiTheme.sandBeige)
                    .frame(width: 200, height: 200)
                    .shadow(color: BonsaiTheme.earthBrown.opacity(0.3), radius: 10)
                
                if bluetoothViewModel.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(BonsaiTheme.primaryGreen)
                        .frame(width: 100, height: 100)
                } else {
                    ProgressView()
                        .scaleEffect(2)
                        .progressViewStyle(CircularProgressViewStyle(tint: BonsaiTheme.primaryGreen))
                }
            }
            
            Text(bluetoothViewModel.isConnected ? "Connected" : "Searching for devices...")
                .font(BonsaiTheme.headlineFont)
                .foregroundColor(BonsaiTheme.earthBrown)
        }
    }
    
    private var noDevicesView: some View {
        VStack(spacing: 15) {
            Image(systemName: "bluetooth.slash")
                .font(.system(size: 50))
                .foregroundColor(.red)
                
            Text("No Devices Found")
                .font(BonsaiTheme.headlineFont)
                .foregroundColor(.red)
                
            Text(bluetoothViewModel.message)
                .font(BonsaiTheme.bodyFont)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            scanAgainButton(fullWidth: true)
                .padding(.horizontal)
                .padding(.top, 10)
        }
        .padding()
    }
    
    private var deviceSelectionView: some View {
        VStack(spacing: 15) {
            Text("Select a Device")
                .font(BonsaiTheme.headlineFont)
                .foregroundColor(BonsaiTheme.earthBrown)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<bluetoothViewModel.discoveredDevices.count, id: \.self) { index in
                        deviceButton(at: index)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 300)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.4))
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
            )
            
            scanAgainButton(fullWidth: false)
                .padding(.top, 10)
        }
    }
    
    private func deviceButton(at index: Int) -> some View {
        let deviceName = bluetoothViewModel.discoveredDevices[index]
        let isRecommended = deviceName.contains("★")
        
        return Button(action: {
            bluetoothViewModel.connectToPeripheral(at: index)
        }) {
            HStack {
                Image(systemName: isRecommended ? "star.fill" : "wave.3.right")
                    .foregroundColor(isRecommended ? .orange : BonsaiTheme.primaryGreen)
                
                Text(deviceName)
                    .lineLimit(1)
                    .foregroundColor(BonsaiTheme.earthBrown)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(BonsaiTheme.lightGreen)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isRecommended ? BonsaiTheme.sandBeige.opacity(0.8) : Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 3)
            )
            .contentShape(Rectangle()) // Makes the entire row tappable
        }
    }
    
    private func scanAgainButton(fullWidth: Bool) -> some View {
        Button(action: {
            bluetoothViewModel.startScanning()
        }) {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Scan Again")
            }
            .padding()
            .frame(maxWidth: fullWidth ? .infinity : 180)
            .background(BonsaiTheme.skyBlue)
            .foregroundColor(.white)
            .cornerRadius(15)
        }
    }
    
    private var connectionStatusCard: some View {
        VStack(spacing: 15) {
            Text("Connection Status")
                .font(BonsaiTheme.headlineFont)
                .foregroundColor(BonsaiTheme.earthBrown)
            
            HStack {
                Image(systemName: bluetoothViewModel.isConnected ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 30))
                    .foregroundColor(bluetoothViewModel.isConnected ? BonsaiTheme.primaryGreen : .red)
                    .animation(.easeInOut, value: bluetoothViewModel.isConnected)
                
                VStack(alignment: .leading) {
                    Text(bluetoothViewModel.isConnected ? "Device Connected" : "Waiting for Connection")
                        .font(BonsaiTheme.bodyFont.bold())
                        .animation(.easeInOut, value: bluetoothViewModel.isConnected)
                    
                    Text(bluetoothViewModel.message)
                        .font(BonsaiTheme.bodyFont)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(BonsaiTheme.sandBeige.opacity(0.5))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.7))
                .shadow(color: Color.gray.opacity(0.2), radius: 5)
        )
    }
}

#Preview("Connecting") {
	let viewModel = BLECentralViewModel()
	viewModel.isScanning = true
	viewModel.message = "Searching for Raspberry Pi..."
	
	return SensorPairingView(bluetoothViewModel: viewModel)
}

#Preview("Connected") {
	let viewModel = BLECentralViewModel()
	viewModel.isScanning = true
	viewModel.isConnected = true
	viewModel.message = "Connected to Bonsai Sensor"
	
	return SensorPairingView(bluetoothViewModel: viewModel)
}
