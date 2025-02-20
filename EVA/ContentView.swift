//
//  ContentView.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import SwiftUI

// ContentView view is the first view that you’ll see when you launch your app.
struct ContentView: View {
    var body: some View {
//        VStack {
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
//            Text("Hello, world!")
//        }
//        .padding()
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "person")
                }
            CameraView()
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
            LidarView()
                .tabItem {
                    Label("LiDAR", systemImage: "ruler")
                }
            FilterView()
                .tabItem {
                    Label("Filter", systemImage: "photo.artframe.circle.fill")
                }
                
        }

    }
}

#Preview {
    ContentView()
}
