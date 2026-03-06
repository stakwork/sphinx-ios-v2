//
//  HiveShareViewController.swift
//  sphinx
//
//  Programmatic modal for sharing a Hive deep-link to a chat or contact.
//

import UIKit

// MARK: - HiveShareContactTableViewCell

class HiveShareContactTableViewCell: UITableViewCell {

    static let reuseID = "HiveShareContactTableViewCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        iv.backgroundColor = UIColor.Sphinx.LightDivider
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = UIFont(name: "Roboto-Regular", size: 15)
        lbl.textColor = UIColor.Sphinx.Text
        return lbl
    }()

    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = UIColor.Sphinx.PrimaryBlue
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor, constant: -8),

            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 22),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ChatListCommonObject, isSelected: Bool) {
        nameLabel.text = item.getName()
        checkmarkImageView.isHidden = !isSelected

        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = UIColor.Sphinx.WashedOutReceivedText

        if let urlStr = item.getPhotoUrl(), let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.avatarImageView.image = img }
            }.resume()
        }
    }
}

// MARK: - HiveShareViewController

class HiveShareViewController: UIViewController {

    // MARK: - Properties
    private var shareURL: String = ""
    private var shareLabel: String = ""

    private var allItems: [ChatListCommonObject] = []
    private var filteredItems: [ChatListCommonObject] = []
    private var selectedItem: ChatListCommonObject? = nil

    // MARK: - UI
    private var headerView: UIView!
    private var titleLabel: UILabel!
    private var closeButton: UIButton!

    private var searchContainer: UIView!
    private var searchTextField: UITextField!
    private var copyButton: UIButton!

    private var tableView: UITableView!
    private var confirmButton: UIButton!

    // MARK: - Instantiate
    static func instantiate(url: String, label: String) -> HiveShareViewController {
        return HiveShareViewController(url: url, label: label)
    }

    private init(url: String, label: String) {
        self.shareURL = url
        self.shareLabel = label
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.Sphinx.Body
        setupHeader()
        setupSearchRow()
        setupTableView()
        setupConfirmButton()
        loadItems()
    }

    // MARK: - Setup

    private func setupHeader() {
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.Sphinx.Body
        view.addSubview(headerView)

        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Share"
        titleLabel.font = UIFont(name: "Roboto-Medium", size: 14)
        titleLabel.textColor = UIColor.Sphinx.Text
        titleLabel.textAlignment = .center
        headerView.addSubview(titleLabel)

        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let xmarkImg = UIImage(systemName: "xmark")
        closeButton.setImage(xmarkImg, for: .normal)
        closeButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.Sphinx.LightDivider
        headerView.addSubview(divider)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 50),
            closeButton.heightAnchor.constraint(equalToConstant: 50),

            divider.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func setupSearchRow() {
        searchContainer = UIView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        searchTextField = UITextField()
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.placeholder = "Search chats & contacts"
        searchTextField.font = UIFont(name: "Roboto-Regular", size: 14)
        searchTextField.textColor = UIColor.Sphinx.Text
        searchTextField.layer.cornerRadius = 8
        searchTextField.layer.borderWidth = 1
        searchTextField.layer.borderColor = UIColor.Sphinx.LightDivider.cgColor
        searchTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        searchTextField.leftViewMode = .always
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)
        searchContainer.addSubview(searchTextField)

        copyButton = UIButton(type: .system)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.setTitle("Copy", for: .normal)
        copyButton.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        copyButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 14)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        searchContainer.addSubview(copyButton)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 44),

            copyButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor),
            copyButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 50),

            searchTextField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor),
            searchTextField.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            searchTextField.topAnchor.constraint(equalTo: searchContainer.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchContainer.bottomAnchor)
        ])
    }

    private func setupTableView() {
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = UIColor.Sphinx.LightDivider
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        tableView.rowHeight = 60
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HiveShareContactTableViewCell.self, forCellReuseIdentifier: HiveShareContactTableViewCell.reuseID)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupConfirmButton() {
        confirmButton = UIButton(type: .system)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.setTitle("Confirm", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = UIFont(name: "Roboto-Medium", size: 16)
        confirmButton.backgroundColor = UIColor.Sphinx.PrimaryBlue
        confirmButton.layer.cornerRadius = 28
        confirmButton.alpha = 0.4
        confirmButton.isUserInteractionEnabled = false
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        view.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            confirmButton.topAnchor.constraint(equalTo: tableView.bottomAnchor, constant: 12),
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.heightAnchor.constraint(equalToConstant: 56),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func loadItems() {
        allItems = ContactsService.sharedInstance.contactListObjects + ContactsService.sharedInstance.chatListObjects
        filteredItems = allItems
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func copyTapped() {
        ClipboardHelper.copyToClipboard(text: shareURL, message: "link.copied.clipboard".localized)
    }

    @objc private func searchTextChanged(_ textField: UITextField) {
        let searchText = textField.text ?? ""
        if searchText.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter {
                $0.getName().lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }

    @objc private func confirmTapped() {
        guard let selected = selectedItem else { return }

        let chat: Chat?
        let contact: UserContact?

        if let c = selected as? Chat {
            chat = c
            contact = nil
        } else if let uc = selected as? UserContact {
            contact = uc
            chat = uc.getChat()
        } else {
            chat = nil
            contact = nil
        }

        guard let resolvedChat = chat else {
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "generic.error.message".localized
            )
            return
        }

        let (validMessage, _) = SphinxOnionManager.sharedInstance.sendMessage(
            to: contact,
            content: shareLabel,
            chat: resolvedChat,
            provisionalMessage: nil,
            msgType: 0,
            threadUUID: nil,
            replyUUID: nil,
            forceIncludeTimezone: false
        )

        if validMessage != nil {
            dismiss(animated: true)
        } else {
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "generic.error.message".localized
            )
        }
    }

    private func updateConfirmButton() {
        let enabled = selectedItem != nil
        confirmButton.alpha = enabled ? 1.0 : 0.4
        confirmButton.isUserInteractionEnabled = enabled
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension HiveShareViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: HiveShareContactTableViewCell.reuseID,
            for: indexPath
        ) as? HiveShareContactTableViewCell else {
            return UITableViewCell()
        }
        let item = filteredItems[indexPath.row]
        let isSelected = (selectedItem?.getName() == item.getName())
        cell.configure(with: item, isSelected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tapped = filteredItems[indexPath.row]
        if selectedItem?.getName() == tapped.getName() {
            selectedItem = nil
        } else {
            selectedItem = tapped
        }
        tableView.reloadData()
        updateConfirmButton()
    }
}
