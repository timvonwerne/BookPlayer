//
//  JellyfinConnectionForm.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinConnectionForm: View {
  /// View model for the form
  @ObservedObject var viewModel: JellyfinConnectionFormViewModel
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    Form {
      Section(header: Text("jellyfin_section_server_url".localized)
        .foregroundColor(themeViewModel.secondaryColor)
      ) {
        ClearableTextField("jellyfin_server_url_placeholder".localized, text: $viewModel.serverUrl)
      }
    }
    .environmentObject(themeViewModel)
  }
}

#Preview {
  JellyfinConnectionForm(viewModel: JellyfinConnectionFormViewModel())
}
