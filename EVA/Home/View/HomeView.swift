//
//  HomeView.swift
//  EVA
//
//  Created by Kaia Gao on 7/15/24.
//

import Foundation
import SwiftUI


struct HomeView: View {
    
    var body: some View {
        VStack {
            Spacer()
            Text("EVA")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(40)


            
            Image(information.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(10)
                .padding(100)

            Spacer()

            Text(information.name)
                .font(.title)
            
            Spacer()
            ForEach(information.institution, id: \.self) { institution in
                            Text(institution)
//                                .padding()
//                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(5)
                        }
        }
    }
    
}


struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
