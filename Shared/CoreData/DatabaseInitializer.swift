//
//  DatabaseInitializer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import Sentry

/// Wrapper for `DataMigrationManager` to simplify handling all the migrations
public class DatabaseInitializer: BPLogger {
  private let dataMigrationManager: DataMigrationManager

  /// Initializer
  public init() {
    self.dataMigrationManager = DataMigrationManager()
  }

  /// Handle applying all the migrations to the CoreData stack before returning it
  public func loadCoreDataStack() async throws -> CoreDataStack {
    if dataMigrationManager.canPeformMigration() {
      return try await handleMigrations()
    } else {
      return try await loadLibrary()
    }
  }

  /// Wrapper to clean up the DB related files
  /// - Note: Only necessary if we're attempting to recover from a failed migration
  public func cleanupStoreFiles() {
    dataMigrationManager.cleanupStoreFile()
  }

  private func handleMigrations() async throws -> CoreDataStack {
    if dataMigrationManager.needsMigration() {
      try await dataMigrationManager.performMigration()
      return try await handleMigrations()
    } else {
      return try await loadLibrary()
    }
  }

  private func loadLibrary() async throws -> CoreDataStack {
    let crumb = Breadcrumb()
    crumb.level = SentryLevel.info
    crumb.category = "launch"
    crumb.message = "Attempting to load library"
    SentrySDK.addBreadcrumb(crumb)
    return try await withCheckedThrowingContinuation { continuation in
      let stack = dataMigrationManager.getCoreDataStack()

      let crumb2 = Breadcrumb()
      crumb2.level = SentryLevel.info
      crumb2.category = "launch"
      crumb2.message = "Attempting to load store"
      SentrySDK.addBreadcrumb(crumb2)
      stack.loadStore { _, error in
        if let error = error {
          Self.logger.error("Failed to load store")
          let crumb3 = Breadcrumb()
          crumb3.level = SentryLevel.info
          crumb3.category = "launch"
          crumb3.message = "Failed to load store: \(error.localizedDescription)"
          SentrySDK.addBreadcrumb(crumb3)
          continuation.resume(throwing: error)
        } else {
          let dataManager = DataManager(coreDataStack: stack)
          let libraryService = LibraryService(dataManager: dataManager)
          _ = libraryService.getLibrary()

          let crumb4 = Breadcrumb()
          crumb4.level = SentryLevel.info
          crumb4.category = "launch"
          crumb4.message = "Success loading store"
          SentrySDK.addBreadcrumb(crumb4)
          continuation.resume(returning: stack)
        }
      }
    }
  }
}
