//
//  AppDelegate.swift
//  EVA
//
//  Created by Clara Kim on 2/20/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        print("App relaunched for background upload completion: \(identifier)")
        backgroundCompletionHandler = completionHandler
    }
}
