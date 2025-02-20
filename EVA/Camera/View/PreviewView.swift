//
//  PreviewView.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import Foundation
import SwiftUI


struct PreviewView: View {
//    @EnvironmentObject var fetcher:APIModel = APIModel.functions

    var body: some View {
        
        Button(action:{
            
            print(APIModel.functions.imageData.filterId)
        }, label: {
            Text("Fetch")
        })
//        .task {
//            await APIModel.functions.fetchData()
//            }
    }
}

