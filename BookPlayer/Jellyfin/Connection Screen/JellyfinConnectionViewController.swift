//
//  JellyfinConnectionViewController.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import SwiftUI
import Themeable
import UIKit

class JellyfinConnectionViewController: UIViewController, MVVMControllerProtocol {
  var viewModel: JellyfinConnectionViewModel!
  private var disposeBag = Set<AnyCancellable>()

  // MARK: - UI components

  private lazy var contentView: UIView = {
    let view = JellyfinConnectionView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: view)
    addChild(hostingController)
    hostingController.didMove(toParent: self)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    return hostingController.view
  }()

  // MARK: - Initializer

  init(viewModel: JellyfinConnectionViewModel) {
    super.init(nibName: nil, bundle: nil)
    self.viewModel = viewModel
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    setupNavigationItem()
    addSubviews()
    addConstraints()
    setUpTheming()
    bindConnectionObservers()
  }

  private func setupNavigationItem() {
    self.navigationItem.title = "jellyfin_connection_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .cancel,
      target: self,
      action: #selector(self.didTapCancel)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "jellyfin_connect_button".localized,
      style: .done,
      target: self,
      action: #selector(self.didTapConnect)
    )
    definesPresentationContext = true
  }

  private func addSubviews() {
    view.addSubview(contentView)
  }

  private func addConstraints() {
    let safeLayoutGuide = view.safeAreaLayoutGuide

    NSLayoutConstraint.activate([
      contentView.topAnchor.constraint(equalTo: safeLayoutGuide.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: safeLayoutGuide.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: safeLayoutGuide.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: safeLayoutGuide.bottomAnchor),
    ])
  }

  private func bindConnectionObservers() {
    viewModel.createCanConnectPublisher().sink { [weak self] canConnect in
      self?.navigationItem.rightBarButtonItem?.isEnabled = canConnect
    }
    .store(in: &disposeBag)
  }

  @objc func didTapCancel() {
    viewModel.handleCancelAction()
  }

  @objc func didTapConnect() {

  }
}

// MARK: - Themeable

extension JellyfinConnectionViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    contentView.backgroundColor = theme.systemGroupedBackgroundColor
  }
}
