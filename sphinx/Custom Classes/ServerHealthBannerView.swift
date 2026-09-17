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
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        ])
    }

    func configure(health: MixerServerHealth) {
        if let copy = SphinxServerHealth.bannerCopy(for: health) {
            label.text = copy
            isHidden = false
        } else {
            label.text = nil
            isHidden = true
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

    func apply(health: MixerServerHealth) {
        installBannerIfNeeded(on: window)
        banner?.configure(health: health)
    }

    func hide() {
        banner?.configure(health: .ok)
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
            let health = SphinxOnionManager.sharedInstance.currentServerHealth
            Task { @MainActor [weak self] in
                self?.apply(health: health)
            }
        }
    }
}
