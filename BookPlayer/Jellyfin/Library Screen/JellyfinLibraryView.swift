//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject var themeViewModel = ThemeViewModel()
  @ScaledMetric var accessabilityScale: CGFloat = 1

  var body: some View {
    let columns = [
      GridItem(.adaptive(minimum: 100 * accessabilityScale), spacing: 20 * accessabilityScale)
    ]
    ScrollView {
      LazyVGrid(columns: columns, spacing: 20 * accessabilityScale) {
        ForEach(viewModel.userViews, id: \.id) { userView in
          let childViewModel = viewModel.createFolderViewModelFor(item: userView)
          NavigationLink {
            NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))
          } label: {
            JellyfinLibraryItemView<Model.FolderViewModel>(item: userView)
              .environmentObject(childViewModel)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding(10)
    }
    .navigationTitle(viewModel.libraryName)
    .environmentObject(viewModel)
    .onAppear { viewModel.fetchUserViews() }
    .onDisappear { viewModel.cancelFetchUserViews() }
    .navigationTitle(viewModel.libraryName)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button(
          action: viewModel.handleDoneAction,
          label: {
            Image(systemName: "xmark")
              .foregroundColor(themeViewModel.linkColor)
          }
        )
      }
    }
  }
}

class MockJellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, ObservableObject {
  let libraryName: String = "Mock"
  @Published var userViews: [JellyfinLibraryItem] = []

  func fetchUserViews() {}
  func cancelFetchUserViews() {}

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryFolderViewModel {
    return MockJellyfinLibraryFolderViewModel(data: item)
  }
  
  func handleDoneAction() {}
}

#Preview {
  let viewModel = {
    let viewModel = MockJellyfinLibraryViewModel()
    viewModel.userViews = [
      JellyfinLibraryItem(id: "0", name: "First View", kind: .userView),
      JellyfinLibraryItem(id: "1", name: "Second View", kind: .userView),
      JellyfinLibraryItem(id: "2", name: "Third View", kind: .userView),
      JellyfinLibraryItem(id: "3", name: "Fourth View", kind: .userView),
    ]
    return viewModel
  }()
  JellyfinLibraryView(viewModel: viewModel)
}
