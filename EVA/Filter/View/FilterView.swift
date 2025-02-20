//
//  FilterView.swift
//  EVA
//
//  Created by Kaia Gao on 7/20/24.
//

import PhotosUI
import SwiftUI
import Alamofire

//struct ReturnInfo: Decodable{
//    var filteredImg: String
//}

struct  FilterView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @ObservedObject var viewModel = FilterViewModel(FilterModel())
    @State private var progress: Double = 0
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var imgName: String = "null"
    @State private var mimeType: String = "null"
    @State var originalImg: UIImage?

    @FocusState private var focusItem: Bool
    

    
    var body: some View {
        GeometryReader {_ in
            VStack {
                HStack{
                    Text("VA: ")
                    TextField(
                        "Enter Visual Acuity",
                        text: $viewModel.va
                    )
                    .padding(.horizontal)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(UIColor.lightGray))
//                    .keyboardType(.numberPad)
                    .focused($focusItem)

                }
                .padding(.horizontal)
                
                
                HStack{
                    Text("CS: ")
                    TextField(
                        "Enter Contrast Sensitivity",
                        text: $viewModel.cs
                    )
                    .padding(.horizontal)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(UIColor.lightGray))
//                    .keyboardType(.numberPad)
                    .focused($focusItem)
                    
                }
                .padding(.horizontal)
                
                Divider().overlay(.black)
                
                VStack {
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                        //                        if selectedItem != nil, let data = selectedImageData, let image = UIImage(data: data) {
                        if selectedItem != nil {
                            if let selectedImage = originalImg {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 30)
                            }
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                        }
                    }
                    .onChange(of: selectedItem) {
                        Task {
                            if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                                selectedImageData = data
                                originalImg = UIImage(data: data)
                            }
                            
                            
                            if let selectedItem, let localID = selectedItem.itemIdentifier {
                                let result = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
                        
                                if let asset = result.firstObject {
                                    // Fetch the PHAssetResource for the asset
                                    let resources = PHAssetResource.assetResources(for: asset)
                                    if let resource = resources.first {
                                        // Now you have the file name
                                        let filename = resource.originalFilename
                                        let exten = filename.split(separator: ".").last
                                        imgName = filename
                                        let mediaType = asset.mediaType
//                                        let mediaSubType = asset.mediaSubtypes
                                        
                                        switch mediaType {
                                                    case .unknown:
                                            mimeType = "none/"
                                                    case .image:
                                            mimeType = "image"
                                                    case .video:
                                            mimeType = "video"
                                                    case .audio:
                                                        mimeType = "audio"

                                        @unknown default:
                                            print("Wrong Media Type")
                                        }
                                        mimeType = mimeType+(exten ?? "none")
                                        
                                
                                    }
                                }
                                
                            }
                            
                            
                            
                            
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
//                .frame(height: 500)
                
                Text("\(imgName)").italic()
                
                Divider().overlay(.black)
                
                
                Spacer()
                
  
                
                Button(
                    action: {viewModel.filterImage(selectedImageData, imgName: imgName, mimeType: mimeType, cs: viewModel.cs, va: viewModel.va,downprogress:progress)},
                    label: {
                        Text("Apply Filter")
                            .foregroundColor(.white)
                    })
                .padding([.vertical])
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                    
                Spacer()
                

                HStack {
                           Text("Upload")
                               .font(.headline)
                               .padding(.horizontal,10)
                               .font(.system(size: 20))

                    ProgressView(value: viewModel.uploadProgress, total: 1.0)
                               .progressViewStyle(LinearProgressViewStyle())
                               .padding()
                       }

                HStack {
                        Text("Download")
                            .font(.headline)
                            .padding(.horizontal,10)
                            .font(.system(size: 20))
                        
                        ProgressView(value: viewModel.downloadProgress, total: 1.0)
                            .progressViewStyle(LinearProgressViewStyle())
                        .padding()}
                .padding(.bottom, 15)
                
                if viewModel.showRollingProgress {

                    ProgressView("Processing").progressViewStyle(CircularProgressViewStyle())}
                Spacer()
                                

  
                
                
            }
        }
        .navigationTitle("Linear Filter")
        .toolbar {
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
                    .font(.system(size: 15))
            }
        }
        .onTapGesture{
            focusItem = false
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $viewModel.showFilteredImg) {
            VStack {
                HStack {
                    Button(action: {viewModel.showFilteredImg = false}) { //Photo collection view
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.black)
                            .font(.system(size: 25))
                    }
                    .padding(.leading, 15)
                    Spacer()
                }
                
                Spacer()
                
                Text("\(viewModel.filteredImgName)").italic()

                Image(uiImage: viewModel.filteredImg ?? UIImage())
                    .resizable()
                    .scaledToFit()
                
                
                Button(
                    action: {viewModel.saveFilteredImage()
                        viewModel.downloadProgress = 0
                        viewModel.uploadProgress = 0
                    },
                    label: {
                        Text("Save")
                            .foregroundColor(.white)
                    })
                .padding([.vertical])
                .frame(maxWidth: .infinity)
                .background(Color.blue)
//                .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                Spacer()
            }
            
        }
        
    }
}

#Preview {
    FilterView()
}
