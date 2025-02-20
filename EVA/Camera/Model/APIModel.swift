//
//  APIModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import Foundation
import Alamofire
import SwiftUI

struct ImagewFilter: Decodable{
    var _id: String = "0"
    var filterId: String  = "0"
    var Date: String  = "0"
//    var __v:String = "0"
    
}
struct ReturnInfo: Decodable{
    var filteredImg: Array<Float>
}

class APIModel: ObservableObject{
    @Published var imageData = ImagewFilter()
    static let functions = APIModel()
    
    
    func uploadImage(imgType:String,imgData:Image,imageName:String) async {
        // params to send additional data, for eg. AccessToken or userUserId
        //       let params = ["userID":"userId","accessToken":"your accessToken"]
        //       print(params)
        AF.upload(multipartFormData: {
            multiPart in
            //           for (key,keyValue) in params{
            //               if let keyData = keyValue.data(using: .utf8){
            //                   multiPart.append(keyData, withName: key)
            //               }
            //           }
            //
//            multiPart.append(UIImage(), withName: "src_img",fileName: imageName,mimeType: "image/*")
        }, to: "Your URL",headers: [])
        .uploadProgress { progress in
            print("Upload Progress: \(progress.fractionCompleted)")
        }
        .downloadProgress { progress in
            print("Download Progress: \(progress.fractionCompleted)")
        }
        .responseDecodable(of:[ReturnInfo].self) { apiResponse in
            debugPrint(apiResponse)
        }
    }
        
        
        
        
    func fetchData() async {
        AF.request("http://192.168.0.9:8081/photo")
            .response { [self] // Make a request then get the response
                response in
                print("FETCHING")
                debugPrint(response)
//                for d in response.data!{
//                    print(d)
//                    print("Response DecodableType: \(String(describing: d))")
//                }
                
                
            
        //            self.imageData = try JSONDecoder().decode(ImagewFilter.self, from: response.data!)
//                let data = String(data:response.data!, encoding: .utf8)
                let decoder = JSONDecoder()
                do {
                    let fetchedData = try decoder.decode([ImagewFilter].self, from:response.data!)
                    imageData = fetchedData[1]
                    } catch {
                     print(error)
                 }
//                AF.download("https://httpbin.org/image/png")
//                    .downloadProgress { progress in
//                        print("Download Progress: \(progress.fractionCompleted)")
//                    }
//                    .responseData { response in
//                        if let data = response.value {
//                            let image = UIImage(data: data)
//                        }
//                    }

        //            Task { @MainActor in
        //                self.imageData = try JSONDecoder().decode(ImagewFilter.self, from: response.data!)
        //                   }
            }
//            .responseDecodable(of: FetchedDataCollection.self) { response in
//                print("Response DecodableType: \(String(describing: response.value))")
//                }
    }
}

struct FetchedDataCollection: Decodable{
    var sample: [ImagewFilter]
}


