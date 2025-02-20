//
//  CameraSelectionModel.swift
//  EVA
//
//  Created by Kaia Gao on 7/19/24.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class CameraSelectionModel:ObservableObject{
    var distancesList = [1, 3, 5] //Publish not necessary
    var levelsList = ["eye", "waist"] //Publish not necessary
    
    var hazards: [String]? // Camera model data (original from the model)
    var distances: [Int]? // Camera model data (original from the model)
    var levels: [String]? // Camera model data (original from the model)
    
    @Published var isSelectionVisible = false
    
    @Published var rawFileURL: URL?

    
    
    @Published var recentImage: UIImage?
    @Published var isCameraBusy = false
    @Published var lowResolutionWarning = false

    @Published var selectedHazard: String = ""
    @Published var selectedDistance: Int = 0
    @Published var selectedLevel: String = ""
    @Published var selectedId: String = ""
    @Published var selectedAngle: String = ""
    @Published var selectedLux: String = "999"
    @Published var searchText: String = ""
    
    @Published var imageName:String = ""
    
    var maxWidth = Int32(0)
    var maxHeight = Int32(0)
    
    func saveLabel() {
        
        self.imageName = "\(self.selectedHazard) _ ID\(self.selectedId) _ \(self.selectedDistance)m _ \(self.selectedLevel) _ ANGLE\(self.selectedAngle) _ \(self.selectedLux)lux"
    }
    
    var filteredHazards: [String]? {
            guard !searchText.isEmpty else { return hazards }
            return hazards!.filter { hazard in
                hazard.lowercased().contains(searchText.lowercased())
            }
        }
    
    private func parseCSVAt(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let dataEncoded = String(data: data, encoding: .utf8)
            if let dataArr = dataEncoded?.components(separatedBy: "\n") {
                self.hazards = dataArr.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        } catch {
            print("Error reading CSV file")
        }
    }
    
    func loadHazardsFromCSV() {
        let path = Bundle.main.path(forResource: "hazards", ofType: "csv")!
        parseCSVAt(url: URL(fileURLWithPath: path))
    }
    
    init() {
        loadHazardsFromCSV()
        self.distances = self.distancesList
        self.levels = self.levelsList

    }
    
}
