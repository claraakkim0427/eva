//
//  CameraSelectionView.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

struct CameraSelectionView: View {
    @ObservedObject var viewModel:CameraSelectionModel
    @Binding var isSelectionVisible:Bool

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: {
                    if let mainWindow = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive })?
                        .windows
                        .first(where: { $0.isKeyWindow }) {
                        mainWindow.endEditing(true)
                    }
                }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .foregroundColor(.black)
                        .font(.system(size: 20))
                }
                .padding(.leading, 15)
                
                Spacer()
            }.padding(.bottom, 10)
            
            
            
            VStack {
                
                Text("\(viewModel.selectedHazard) _ ID\(viewModel.selectedId) _ \(viewModel.selectedDistance)m _ \(viewModel.selectedLevel) _ ANGLE\(viewModel.selectedAngle) _ \(viewModel.selectedLux)lux").font(.system(size: 12)).padding(.horizontal)
                
                Divider().padding(.horizontal)
                
                HStack{
                    Text("ID:         ")
                    TextField(
                        "Enter the ID",
                        text: $viewModel.selectedId
                    ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                }.padding(.horizontal)
                
                
                Divider().padding(.horizontal)
                
                
                Text("Distance (m)")
                if let distanceList = viewModel.distances {
                    Picker("Distances", selection: $viewModel.selectedDistance) {
                        ForEach(0 ..< distanceList.count, id: \.self) { index in
                            Text(String(distanceList[index])).tag(distanceList[index])
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                }
                
                
                Divider().padding(.horizontal)
                
                Text("Height")
                if let levelList = viewModel.levels {
                    Picker("Height", selection: $viewModel.selectedLevel) {
                        ForEach(0 ..< levelList.count, id: \.self) { index in
                            Text(String(levelList[index])).tag(levelList[index])
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    
                }
                
                
                Divider().padding(.horizontal)
                
                HStack{
                    Text("Angle #:")
                    TextField(
                        "Enter the angle",
                        text: $viewModel.selectedAngle
                    ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                }.padding(.horizontal)
                
                
                
                
                
                Divider().padding(.horizontal)
                
                HStack{
                    Text("Lux:       ")
                    TextField(
                        "Enter the lux",
                        text: $viewModel.selectedLux
                    ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                }.padding(.horizontal)
                
                
                
                Divider().padding(.horizontal)
                
                
                Text("Hazards")
                if let hazardList = viewModel.filteredHazards {
                    NavigationStack {
                        List {
                            
                            ForEach(0 ..< hazardList.count, id: \.self) { index in
                                Text(String(hazardList[index]))
                                    .onTapGesture {
                                        viewModel.selectedHazard = hazardList[index]
                                    }
                            }
                            
                        }
                        .listStyle(.plain)
                        .searchable(text: $viewModel.searchText)
                    }
                }
            }
        }
    
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(.white)
//                .edgesIgnoringSafeArea(.all)  // Ensure it covers the whole screen
        
       }
}
