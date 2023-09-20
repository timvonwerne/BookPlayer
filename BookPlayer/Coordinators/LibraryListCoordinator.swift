//
//  LibraryListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit

class LibraryListCoordinator: ItemListCoordinator, UINavigationControllerDelegate, BPLogger {
  weak var tabBarController: UITabBarController?
  let importManager: ImportManager

  var fileSubscription: AnyCancellable?
  var importOperationSubscription: AnyCancellable?
  private var disposeBag = Set<AnyCancellable>()

  init(
    navigationController: UINavigationController,
    playerManager: PlayerManagerProtocol,
    importManager: ImportManager,
    libraryService: LibraryServiceProtocol,
    playbackService: PlaybackServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.importManager = importManager

    super.init(
      navigationController: navigationController,
      playerManager: playerManager,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncService
    )
  }

  // swiftlint:disable:next function_body_length
  override func start() {
    let vc = ItemListViewController.instantiate(from: .Main)
    let viewModel = ItemListViewModel(
      folderRelativePath: nil,
      playerManager: self.playerManager,
      networkClient: NetworkClient(),
      libraryService: self.libraryService,
      playbackService: self.playbackService,
      syncService: self.syncService,
      themeAccent: ThemeManager.shared.currentTheme.linkColor
    )
    viewModel.onTransition = { [weak self] route in
      switch route {
      case .showFolder(let relativePath):
        self?.showFolder(relativePath)
      case .loadPlayer(let relativePath):
        self?.loadPlayer(relativePath)
      case .showDocumentPicker:
        self?.showDocumentPicker()
      case .showSearchList(let relativePath, let placeholderTitle):
        self?.showSearchList(at: relativePath, placeholderTitle: placeholderTitle)
      case .showItemDetails(let item):
        self?.showItemDetails(item)
      case .showExportController(let items):
        self?.showExportController(for: items)
      case .showItemSelectionScreen(let availableItems, let selectionHandler):
        self?.showItemSelectionScreen(availableItems: availableItems, selectionHandler: selectionHandler)
      case .showMiniPlayer(let flag):
        self?.showMiniPlayer(flag: flag)
      case .listDidAppear:
        self?.handleLibraryLoaded()
      }
    }
    viewModel.coordinator = self
    vc.viewModel = viewModel
    vc.navigationItem.largeTitleDisplayMode = .automatic
    vc.tabBarItem = UITabBarItem(
      title: "library_title".localized,
      image: UIImage(systemName: "books.vertical"),
      selectedImage: UIImage(systemName: "books.vertical.fill")
    )

    self.presentingViewController = self.navigationController
    self.navigationController.pushViewController(vc, animated: true)
    self.navigationController.delegate = self

    if let tabBarController = tabBarController {
      let newControllersArray = (tabBarController.viewControllers ?? []) + [self.navigationController]
      tabBarController.setViewControllers(newControllersArray, animated: false)
    }

    if let appDelegate = AppDelegate.shared {
      for action in appDelegate.pendingURLActions {
        ActionParserService.handleAction(action)
      }
    }

    self.documentPickerDelegate = vc

    AppDelegate.shared?.watchConnectivityService?.startSession()
  }

  func handleLibraryLoaded() {
    loadLastBookIfNeeded()
    syncList()
    bindImportObserverIfNeeded()
  }

  func bindImportObserverIfNeeded() {
    guard
      fileSubscription == nil,
      AppDelegate.shared?.activeSceneDelegate != nil
    else { return }

    self.fileSubscription = self.importManager.observeFiles().sink { [weak self] files in
      guard let self = self,
            !files.isEmpty,
            self.shouldShowImportScreen() else { return }

      self.showImport()
    }

    self.importOperationSubscription = self.importManager.operationPublisher.sink(receiveValue: { [weak self] operation in
      guard let self = self else {
        return
      }

      let coordinator = self.getLastItemListCoordinator(from: self)

      coordinator.onAction?(.newImportOperation(operation))

      operation.completionBlock = {
        DispatchQueue.main.async {
          coordinator.onAction?(.importOperationFinished(operation.processedFiles, operation.suggestedFolderName))
        }
      }

      self.importManager.start(operation)
    })
  }

  func loadLastBookIfNeeded() {
    guard
      let libraryItem = libraryService.getLibraryLastItem()
    else { return }

    AppDelegate.shared?.loadPlayer(
      libraryItem.relativePath,
      autoplay: false,
      showPlayer: { [weak self] in
        if UserDefaults.standard.bool(forKey: Constants.UserActivityPlayback) {
          UserDefaults.standard.removeObject(forKey: Constants.UserActivityPlayback)
          self?.playerManager.play()
        }

        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.showPlayer) {
          UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.showPlayer)
          self?.showPlayer()
        }
      },
      alertPresenter: self
    )
  }

  func processFiles(urls: [URL]) {
    for url in urls {
      self.importManager.process(url)
    }
  }

  func showImport() {
    let child = ImportCoordinator(
      importManager: self.importManager,
      presentingViewController: self.presentingViewController
    )
    child.parentCoordinator = self
    self.childCoordinators.append(child)
    child.start()
  }

  func shouldShowImportScreen() -> Bool {
    return !self.childCoordinators.contains(where: { $0 is ImportCoordinator })
  }

  func getLastItemListCoordinator(from coordinator: ItemListCoordinator) -> ItemListCoordinator {
    if let child = coordinator.childCoordinators.last(where: { $0 is ItemListCoordinator}) as? ItemListCoordinator {
      return getLastItemListCoordinator(from: child)
    } else {
      return coordinator
    }
  }

  func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
    // Read the view controller we’re moving from.
    guard let fromViewController = navigationController.transitionCoordinator?.viewController(forKey: .from) else {
      return
    }

    // Check whether our view controller array already contains that view controller. If it does it means we’re pushing a different view controller on top rather than popping it, so exit.
    if navigationController.viewControllers.contains(fromViewController) {
      return
    }

    // Coordinator may be already released if popped by VoiceOver gesture
    guard let fromViewController  = fromViewController as? ItemListViewController,
          fromViewController.viewModel.coordinator != nil
    else { return }

    fromViewController.viewModel.coordinator.detach()
  }

  override func syncList() {
    Task { @MainActor in
      do {
        let lastPlayed: SyncableItem?

        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.hasScheduledLibraryContents) == true {
          lastPlayed = try await syncService.syncListContents(at: nil)
        } else {
          lastPlayed = try await syncService.syncLibraryContents()

          UserDefaults.standard.set(
            true,
            forKey: Constants.UserDefaults.hasScheduledLibraryContents
          )
        }

        reloadItemsWithPadding()
        if let lastPlayed {
          reloadLastBook(relativePath: lastPlayed.relativePath)
        }
      } catch BPSyncError.reloadLastBook(let relativePath) {
        reloadItemsWithPadding()
        reloadLastBook(relativePath: relativePath)
      } catch BPSyncError.differentLastBook(let relativePath) {
        reloadItemsWithPadding()
        setSyncedLastPlayedItem(relativePath: relativePath)
      } catch {
        Self.logger.trace("Sync contents error: \(error.localizedDescription)")
      }
    }
  }

  func reloadLastBook(relativePath: String) {
    let wasPlaying = playerManager.isPlaying
    playerManager.stop()
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: wasPlaying,
      showPlayer: nil,
      alertPresenter: self
    )
  }

  func setSyncedLastPlayedItem(relativePath: String) {
    /// Only continue overriding local book if it's not currently playing
    guard playerManager.isPlaying == false else { return }

    libraryService.setLibraryLastBook(with: relativePath)
    AppDelegate.shared?.loadPlayer(
      relativePath,
      autoplay: false,
      showPlayer: nil,
      alertPresenter: self
    )
  }
}
