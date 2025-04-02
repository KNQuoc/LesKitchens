//
//  LesKitchensApp.swift
//  LesKitchens
//
//  Created by Quoc Ngo on 4/1/25.
//

import Firebase
import SwiftUI

@main
struct LesKitchensApp: App {
  @StateObject var authViewModel = AuthViewModel()

  init() {
    FirebaseApp.configure()
  }

  var body: some Scene {
    WindowGroup {
      if authViewModel.userSession != nil {
        ContentView()
          .environmentObject(authViewModel)
      } else {
        LoginView()
          .environmentObject(authViewModel)
      }
    }
  }
}
