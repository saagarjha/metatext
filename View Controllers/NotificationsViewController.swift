// Copyright © 2021 Metabolist. All rights reserved.

import Combine
import Mastodon
import UIKit
import ViewModels

final class NotificationsViewController: UIPageViewController {
    private let segmentedControl = UISegmentedControl(items: [
        NSLocalizedString("notifications.all", comment: ""),
        NSLocalizedString("notifications.mentions", comment: "")
    ])
    private let notificationViewControllers: [TableViewController]
    private let viewModel: NavigationViewModel
    private let rootViewModel: RootViewModel
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: NavigationViewModel, rootViewModel: RootViewModel) {
        self.viewModel = viewModel
        self.rootViewModel = rootViewModel

        var excludingAllExceptMentions = Set(MastodonNotification.NotificationType.allCasesExceptUnknown)

        excludingAllExceptMentions.remove(.mention)

        notificationViewControllers = [
            TableViewController(viewModel: viewModel.notificationsViewModel(excludeTypes: []),
                                rootViewModel: rootViewModel),
            TableViewController(viewModel: viewModel.notificationsViewModel(excludeTypes: excludingAllExceptMentions),
                                rootViewModel: rootViewModel)
        ]

        super.init(transitionStyle: .scroll,
                   navigationOrientation: .horizontal,
                   options: [.interPageSpacing: CGFloat.defaultSpacing])

        if let firstViewController = notificationViewControllers.first {
            setViewControllers([firstViewController], direction: .forward, animated: false)
        }

        tabBarItem = NavigationViewModel.Tab.notifications.tabBarItem
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate = self

        navigationItem.titleView = segmentedControl
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addAction(
            UIAction { [weak self] _ in
                guard let self = self,
                      let currentViewController = self.viewControllers?.first as? TableViewController,
                      let currentIndex = self.notificationViewControllers.firstIndex(of: currentViewController),
                      self.segmentedControl.selectedSegmentIndex != currentIndex
                else { return }

                self.setViewControllers(
                    [self.notificationViewControllers[self.segmentedControl.selectedSegmentIndex]],
                    direction: self.segmentedControl.selectedSegmentIndex > currentIndex ? .forward : .reverse,
                    animated: !UIAccessibility.isReduceMotionEnabled)
            },
            for: .valueChanged)
    }
    
#if targetEnvironment(macCatalyst)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.interactivePopGestureRecognizer?.delegate = self
        
        let toolbar = NSToolbar(identifier: "notifications")
        toolbar.delegate = self
        
        if #available(macCatalyst 16.0, *) {
            toolbar.centeredItemIdentifiers = [ToolbarItem.segment.identifier]
        }
        
        let scene = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }.first!
        let titlebar = scene.titlebar!
        titlebar.titleVisibility = .hidden
        titlebar.toolbar = toolbar
    }
#endif
}

#if targetEnvironment(macCatalyst)
extension NotificationsViewController: NSToolbarDelegate, UIGestureRecognizerDelegate {
    enum ToolbarItem: String, CaseIterable {
        case segment
        case compose
        
        var identifier: NSToolbarItem.Identifier {
            NSToolbarItem.Identifier(rawValue)
        }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            NSToolbarItem.Identifier(ToolbarItem.segment.rawValue),
            .flexibleSpace,
            NSToolbarItem.Identifier(ToolbarItem.compose.rawValue),
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        ToolbarItem.allCases.map(\.identifier)
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch ToolbarItem(rawValue: itemIdentifier.rawValue)! {
        case .segment:
            return NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: UIBarButtonItem(customView: segmentedControl))
        case .compose:
            return NSToolbarItem(itemIdentifier: itemIdentifier, barButtonItem: navigationItem.rightBarButtonItem!)
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
#endif

extension NotificationsViewController: NavigationHandling {
    func handle(navigation: Navigation) {
        switch navigation {
        case .notification:
            guard let firstViewController = notificationViewControllers.first else { return }

            segmentedControl.selectedSegmentIndex = 0
            setViewControllers([firstViewController], direction: .reverse, animated: false)
            firstViewController.handle(navigation: navigation)
        default:
            (viewControllers?.first as? TableViewController)?.handle(navigation: navigation)
        }
    }
}

extension NotificationsViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard
            let viewController = viewController as? TableViewController,
            let index = notificationViewControllers.firstIndex(of: viewController),
            index + 1 < notificationViewControllers.count
        else { return nil }

        return notificationViewControllers[index + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard
            let viewController = viewController as? TableViewController,
            let index = notificationViewControllers.firstIndex(of: viewController),
            index > 0
        else { return nil }

        return notificationViewControllers[index - 1]
    }
}

extension NotificationsViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard let viewController = viewControllers?.first as? TableViewController,
              let index = notificationViewControllers.firstIndex(of: viewController)
        else { return }

        segmentedControl.selectedSegmentIndex = index
    }
}

extension NotificationsViewController: ScrollableToTop {
    func scrollToTop(animated: Bool) {
        (viewControllers?.first as? TableViewController)?.scrollToTop(animated: animated)
    }
}
