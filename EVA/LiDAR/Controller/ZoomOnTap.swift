//
//  ZoomOnTap.swift
//  EVA
//
//  Created by Kaia Gao on 7/19/24.
//

import Foundation
import SwiftUI

struct ZoomOnTap<T: View>: View {
        
    let content: T
    @State private var isPresented = false

    init(@ViewBuilder content: () -> T) {
        self.content = content()
    }
    
    var body: some View {
        content.onTapGesture { isPresented.toggle() }
            .fullScreenCover(isPresented: $isPresented) {
                content.onTapGesture { isPresented.toggle() }
            }
    }
}

