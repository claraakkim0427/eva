//
//  CameraView.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import Foundation

import SwiftUI

struct CameraView: View {
    @StateObject private var model = CameraDataModel()
    @StateObject var viewModel = CameraSelectionModel()
    @State private var isSelectionVisible = false
 
    private static let barHeightFactor = 0.15
    
    var body: some View {
        
        NavigationStack {
            
            GeometryReader { geometry in
                // ViewfinderView to display live video from the camera.
                // binding the model’s viewfinderImage property to  ViewfinderView,
                //  ensure that the viewfinder updates whenever the view receives a new preview image.
                ViewfinderView(image:  $model.viewfinderImage )
                    .overlay(alignment: .top) {
                        HStack{
                            Spacer()
                            Button(action:{
                                
                                model.camera.switchRawMode()
                                debugPrint(model.camera.israw)
                            }, label: {
                                Text("RAW")
                            })
                            .strikethrough(!model.camera.israw, color: .white)
                            .foregroundColor(.white)
                            .opacity(0.75)
                            .frame(height: geometry.size.height * Self.barHeightFactor)
                            
                            Spacer()
                            
                            Text(viewModel.imageName).onReceive(viewModel.$imageName, perform: { name in
                                model.imageName = name
                            })
                                .font(.system(size: 12))
                                .padding(.horizontal)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {isSelectionVisible.toggle()}) { //Photo collection view
                                Image(systemName: "gear")
                                    .foregroundColor(.white)
                                    .font(.system(size: 25))
                                
                            }
                           
                            Spacer()
                        }
                    }
                    .overlay(alignment: .bottom) {
                        buttonsView()
                            .frame(height: geometry.size.height * Self.barHeightFactor+100)
                            .background(.black.opacity(0.75))
                    }
                    .overlay(alignment: .bottom) {
                        Color.white
                            .frame(height: geometry.size.height * Self.barHeightFactor*0.7)
                    }
                    .overlay(alignment: .center)  {
                        Color.clear
                            .frame(height: geometry.size.height * (1 - (Self.barHeightFactor * 2)))
                            .accessibilityElement()
                            .accessibilityLabel("View Finder")
                            .accessibilityAddTraits([.isImage])
                    }
                    .background(.black)
            }
            .task {
                await model.camera.start()
                await model.loadPhotos()
                await model.loadThumbnail()
            }
            .navigationTitle("Camera")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .ignoresSafeArea()
            .statusBar(hidden: true)
            
            .background(NavigationLink(destination: CameraSelectionView(viewModel: viewModel, isSelectionVisible: $isSelectionVisible), isActive: $isSelectionVisible) {
                                EmptyView() // Invisible navigation link
                            }.hidden())
            .onAppear(perform: {viewModel.saveLabel()})
            .onDisappear(perform: {
                model.camera.stop()
            })
        }
    }
    
    private func buttonsView() -> some View {
        VStack(spacing: 60){
            
            HStack(spacing: 60) {
                Spacer()
          
                
                
                
                NavigationLink {
                    PhotoCollectionView(photoCollection: model.photoCollection)
                        .onAppear {
                            model.camera.isPreviewPaused = true
                        }
                        .onDisappear {
                            model.camera.isPreviewPaused = false
                        }
                } label: {
                    Label {
                        Text("Gallery")
                    } icon: {
                        ThumbnailView(image: model.thumbnailImage)
                    }
                }
                
                // shutter
                Button {
                    model.camera.takePhoto()
                } label: {
                    Label {
                        Text("Take Photo")
                    } icon: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(width: 62, height: 62)
                            Circle()
                                .fill(.white)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                
                Button {
                    model.camera.switchCaptureDevice()
                } label: {
                    Label("Switch Camera", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
            
            }
            Spacer()
        }
        
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .padding()
    }
    
}

#Preview {
    CameraView()
}
