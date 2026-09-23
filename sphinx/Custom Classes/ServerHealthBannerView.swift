//
//  ServerHealthBannerView.swift
//  sphinx
//
//  Non-blocking window-level overlay for Lightning node health.
//  Independent of ChatListHeader MQTT chrome (`updateConnectionSign`).
//

import UIKit

@MainActor
final class ServerHealthBannerView: UIView {
    /// Single source of truth for the banner's fixed height — also used by
    /// `ServerHealthBannerPresenter` to reserve the same amount of space at
    /// the top of the app content, so the banner never covers it.
    static let height: CGFloat = 42

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
        isHidden = true
        backgroundColor = UIColor.Sphinx.SphinxOrange
        accessibilityIdentifier = "serverHealthBanner"

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Roboto-Regular", size: 13.0) ?? UIFont.systemFont(ofSize: 13)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(health: ServerHealth) {
        guard SphinxOnionManager.sharedInstance.isServerHealthBannerVisible,
              let copy = ServerHealthPresentation.bannerCopy(for: health) else {
            label.text = nil
            isHidden = true
            return
        }
        backgroundColor = Self.backgroundColor(for: health)
        label.text = copy
        isHidden = false
    }

    /// `.degraded` (node reachable but unhealthy) gets the red treatment;
    /// `.unknown` (can't tell) keeps the original orange. `.ok` never
    /// reaches here — the banner is hidden for that state.
    private static func backgroundColor(for health: ServerHealth) -> UIColor {
        switch health {
        case .degraded:
            return UIColor.Sphinx.PrimaryRed
        case .unknown, .ok:
            return UIColor.Sphinx.SphinxOrange
        }
    }
}

@MainActor
final class ServerHealthBannerPresenter {
    static let shared = ServerHealthBannerPresenter()

    private weak var window: UIWindow?
    private var banner: ServerHealthBannerView?
    private var topConstraint: NSLayoutConstraint?
    private var observer: NSObjectProtocol?

    private init() {}

    func attach(to window: UIWindow?) {
        guard let window else { return }
        self.window = window
        installBannerIfNeeded(on: window)
        startObservingIfNeeded()
        apply(health: SphinxOnionManager.sharedInstance.currentServerHealth)
    }

    func apply(health: ServerHealth) {
        installBannerIfNeeded(on: window)
        banner?.configure(health: health)
        updateContentInset()
    }

    func hide() {
        banner?.configure(health: .ok)
        updateContentInset()
    }

    /// Reserves (or releases) space at the top of the app's own content via
    /// `additionalSafeAreaInsets` on the window's root view controller, so
    /// visible app screens — which lay their top chrome out against
    /// `safeAreaLayoutGuide` — shift down below the banner instead of it
    /// covering them. Set on the window's root VC (not a specific screen) so
    /// this applies to whatever's currently on screen, and safe-area insets
    /// propagate down through any properly-contained child view controllers.
    private func updateContentInset() {
        guard let rootViewController = window?.rootViewController else { return }

        let isBannerVisible = !(banner?.isHidden ?? true)
        let targetInset: CGFloat = isBannerVisible ? ServerHealthBannerView.height : 0
        guard rootViewController.additionalSafeAreaInsets.top != targetInset else { return }

        UIView.animate(withDuration: 0.25) {
            rootViewController.additionalSafeAreaInsets = UIEdgeInsets(
                top: targetInset,
                left: 0,
                bottom: 0,
                right: 0
            )
            rootViewController.view.layoutIfNeeded()
        }
    }

    private func installBannerIfNeeded(on window: UIWindow?) {
        guard let window else { return }
        if banner?.superview === window {
            window.bringSubviewToFront(banner!)
            return
        }

        banner?.removeFromSuperview()
        let view = ServerHealthBannerView()
        view.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(view)
        let top = view.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor)
        NSLayoutConstraint.activate([
            top,
            view.leadingAnchor.constraint(equalTo: window.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: window.trailingAnchor)
        ])
        banner = view
        topConstraint = top
        window.bringSubviewToFront(view)
    }

    private func startObservingIfNeeded() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .onServerHealthChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                let health = SphinxOnionManager.sharedInstance.currentServerHealth
                self?.apply(health: health)
            }
        }
    }
}
