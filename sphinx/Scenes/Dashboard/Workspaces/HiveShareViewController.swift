//
//  HiveShareViewController.swift
//  sphinx
//
//  Programmatic modal for sharing a Hive deep-link to a chat or contact.
//

import UIKit
import SDWebImage

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

    private let initialsLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = UIFont(name: "Roboto-Bold", size: 14)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.clipsToBounds = true
        lbl.layer.cornerRadius = 20
        lbl.isHidden = true
        return lbl
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
        contentView.addSubview(initialsLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),

            initialsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            initialsLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            initialsLabel.widthAnchor.constraint(equalToConstant: 40),
            initialsLabel.heightAnchor.constraint(equalToConstant: 40),

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

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.sd_cancelCurrentImageLoad()
        avatarImageView.image = nil
        initialsLabel.isHidden = true
        avatarImageView.isHidden = false
    }

    func configure(with item: ChatListCommonObject, isSelected: Bool) {
        nameLabel.text = item.getName()
        checkmarkImageView.isHidden = !isSelected

        let isTribe = !item.isConversation()

        // Cancel any previous load to avoid image bleed-over
        avatarImageView.sd_cancelCurrentImageLoad()

        if let urlStr = item.getPhotoUrl()?.removeDuplicatedProtocol(),
           !urlStr.isEmpty,
           let url = URL(string: urlStr) {
            // Show initials/placeholder while loading
            if isTribe {
                showTribePlaceholder()
            } else {
                showInitials(for: item)
            }
            avatarImageView.sd_setImage(
                with: url,
                placeholderImage: nil,
                options: .lowPriority,
                progress: nil
            ) { [weak self] image, error, _, _ in
                guard let self = self else { return }
                if error == nil, let image = image {
                    self.initialsLabel.isHidden = true
                    self.avatarImageView.isHidden = false
                    self.avatarImageView.image = image
                    self.avatarImageView.tintColor = nil
                }
            }
        } else {
            if isTribe {
                showTribePlaceholder()
            } else {
                showInitials(for: item)
            }
        }
    }

    private func showTribePlaceholder() {
        initialsLabel.isHidden = true
        avatarImageView.isHidden = false
        avatarImageView.image = UIImage(named: "tribePlaceholder")
        avatarImageView.tintColor = UIColor.Sphinx.SecondaryText
    }

    private func showInitials(for item: ChatListCommonObject) {
        let initials = item.getName().getInitialsFromName()
        let color = item.getColor()
        initialsLabel.text = initials
        initialsLabel.backgroundColor = color
        initialsLabel.isHidden = false
        avatarImageView.isHidden = true
    }
}

// MARK: - HiveShareViewController

class HiveShareViewController: UIViewController {

    // MARK: - Properties
    private var shareURL: String = ""
    private var shareLabel: String = ""
    private var workspaceSlug: String = ""

    private var workspaceContacts: [ChatListCommonObject] = []
    private var workspaceTribes: [ChatListCommonObject] = []
    private var filteredContacts: [ChatListCommonObject] = []
    private var filteredTribes: [ChatListCommonObject] = []

    /// Up to 3 selected items, keyed by getObjectId()
    private var selectedItems: [ChatListCommonObject] = []

    private let maxSelections = 3

    // MARK: - UI
    private var headerView: UIView!
    private var titleLabel: UILabel!
    private var closeButton: UIButton!

    private var searchContainer: UIView!
    private var searchTextField: UITextField!
    private var copyButton: UIButton!

    private var tableView: UITableView!
    private var confirmButton: UIButton!

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .Sphinx.SecondaryText
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var errorLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = UIFont(name: "Roboto-Regular", size: 15)
        lbl.textColor = .Sphinx.SecondaryText
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.isHidden = true
        return lbl
    }()

    // MARK: - Instantiate
    static func instantiate(url: String, label: String, workspaceSlug: String) -> HiveShareViewController {
        return HiveShareViewController(url: url, label: label, workspaceSlug: workspaceSlug)
    }

    private init(url: String, label: String, workspaceSlug: String) {
        self.shareURL = url
        self.shareLabel = label
        self.workspaceSlug = workspaceSlug
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

        view.addSubview(loadingIndicator)
        view.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
        tableView.isHidden = true
        searchContainer.isHidden = true
        confirmButton.isHidden = true
        fetchMembers()
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
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor.Sphinx.WashedOutReceivedText
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)

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
            closeButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func setupSearchRow() {
        searchContainer = UIView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        searchTextField = UITextField()
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.tintColor = UIColor.Sphinx.SecondaryText
        searchTextField.font = UIFont(name: "Roboto-Regular", size: 14)
        searchTextField.textColor = UIColor.Sphinx.Text
        searchTextField.backgroundColor = UIColor.Sphinx.ProfileBG
        searchTextField.layer.cornerRadius = 10
        searchTextField.layer.masksToBounds = true
        searchTextField.layer.borderWidth = 0
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Search tribes & contacts",
            attributes: [.foregroundColor: UIColor.Sphinx.SecondaryText]
        )
        searchTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        searchTextField.leftViewMode = .always
        searchTextField.returnKeyType = .done
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged), for: .editingChanged)

        // Add Done toolbar to keyboard
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneBtn = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        toolbar.items = [flexSpace, doneBtn]
        searchTextField.inputAccessoryView = toolbar

        searchContainer.addSubview(searchTextField)

        copyButton = UIButton(type: .system)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.setTitle("Copy", for: .normal)
        copyButton.setTitleColor(UIColor.Sphinx.PrimaryBlue, for: .normal)
        copyButton.titleLabel?.font = UIFont(name: "Roboto-Regular", size: 15)
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        searchContainer.addSubview(copyButton)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 60),

            copyButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 70),

            searchTextField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchTextField.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),
            searchTextField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 44)
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
        tableView.keyboardDismissMode = .onDrag
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

    // MARK: - Members Fetch

    private func fetchMembers() {
        loadingIndicator.startAnimating()
        API.sharedInstance.fetchWorkspaceMembersWithAuth(
            slug: workspaceSlug,
            callback: { [weak self] members in
                DispatchQueue.main.async { self?.handleMembersLoaded(members) }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async { self?.handleMembersError() }
            }
        )
    }

    private func handleMembersLoaded(_ members: [WorkspaceMember]) {
        let pubkeySet = Set(members.compactMap { $0.lightningPubkey }.filter { !$0.isEmpty })

        let allContacts = ContactsService.sharedInstance.contactListObjects
        let matched = allContacts.filter { item in
            guard let contact = item as? Chat else { return false }
            if let pk = contact.ownerPubkey, pubkeySet.contains(pk) { return true }
            return false
        }

        workspaceContacts = sortedItems(matched)
        workspaceTribes = sortedItems(ContactsService.sharedInstance.chatListObjects)

        loadingIndicator.stopAnimating()
        tableView.isHidden = false
        searchContainer.isHidden = false
        confirmButton.isHidden = false
        applyFilter(searchText: "")
    }

    private func handleMembersError() {
        loadingIndicator.stopAnimating()
        errorLabel.text = "Workspace members couldn't be fetched at this moment"
        errorLabel.isHidden = false
        // tableView, searchContainer, confirmButton remain hidden
    }

    private func sortedItems(_ items: [ChatListCommonObject]) -> [ChatListCommonObject] {
        let withMessage = items.filter { $0.lastMessage != nil }
        let withoutMessage = items.filter { $0.lastMessage == nil }
        let sortedWithMessage = withMessage.sorted {
            ($0.lastMessage?.date ?? .distantPast) > ($1.lastMessage?.date ?? .distantPast)
        }
        let sortedWithoutMessage = withoutMessage.sorted {
            $0.getName().lowercased() < $1.getName().lowercased()
        }
        return sortedWithMessage + sortedWithoutMessage
    }

    private func applyFilter(searchText: String) {
        func filtered(_ source: [ChatListCommonObject]) -> [ChatListCommonObject] {
            searchText.isEmpty ? source : source.filter {
                $0.getName().lowercased().contains(searchText.lowercased())
            }
        }
        let baseContacts = filtered(workspaceContacts)
        let baseTribes = filtered(workspaceTribes)

        let selectedContacts = baseContacts.filter { isItemSelected($0) }
        let unselectedContacts = baseContacts.filter { !isItemSelected($0) }
        filteredContacts = selectedContacts + unselectedContacts

        let selectedTribes = baseTribes.filter { isItemSelected($0) }
        let unselectedTribes = baseTribes.filter { !isItemSelected($0) }
        filteredTribes = selectedTribes + unselectedTribes

        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        searchTextField.resignFirstResponder()
    }

    @objc private func copyTapped() {
        ClipboardHelper.copyToClipboard(text: shareURL, message: "link.copied.clipboard".localized)
    }

    @objc private func searchTextChanged(_ textField: UITextField) {
        applyFilter(searchText: textField.text ?? "")
    }

    @objc private func confirmTapped() {
        guard !selectedItems.isEmpty else { return }

        var sendFailures = 0

        for selected in selectedItems {
            let chat: Chat?
            let contact: UserContact?

            if let c = selected as? Chat {
                chat = c
                contact = c.getContact()
            } else if let uc = selected as? UserContact {
                contact = uc
                chat = uc.getChat()
            } else {
                chat = nil
                contact = nil
            }

            guard let resolvedChat = chat else {
                sendFailures += 1
                continue
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

            if let message = validMessage {
                // Save the context so the message can be found when confirmation arrives
                message.managedObjectContext?.saveContext()
            } else {
                sendFailures += 1
            }
        }

        if sendFailures == 0 {
            dismiss(animated: true)
        } else {
            AlertHelper.showAlert(
                title: "generic.error.title".localized,
                message: "generic.error.message".localized
            )
        }
    }

    private func updateConfirmButton() {
        let enabled = !selectedItems.isEmpty
        confirmButton.alpha = enabled ? 1.0 : 0.4
        confirmButton.isUserInteractionEnabled = enabled
    }

    private func isItemSelected(_ item: ChatListCommonObject) -> Bool {
        return selectedItems.contains(where: { $0.getObjectId() == item.getObjectId() })
    }
}

// MARK: - UITextFieldDelegate

extension HiveShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension HiveShareViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? filteredContacts.count : filteredTribes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: HiveShareContactTableViewCell.reuseID,
            for: indexPath
        ) as? HiveShareContactTableViewCell else {
            return UITableViewCell()
        }
        let item = indexPath.section == 0 ? filteredContacts[indexPath.row] : filteredTribes[indexPath.row]
        cell.configure(with: item, isSelected: isItemSelected(item))
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tapped = indexPath.section == 0 ? filteredContacts[indexPath.row] : filteredTribes[indexPath.row]

        if isItemSelected(tapped) {
            selectedItems.removeAll(where: { $0.getObjectId() == tapped.getObjectId() })
        } else {
            guard selectedItems.count < maxSelections else { return }
            selectedItems.append(tapped)
        }

        // Items move to/from top, so animate the full reorder
        let currentSearchText = searchTextField.text ?? ""
        applyFilter(searchText: currentSearchText)
        updateConfirmButton()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = UIColor.Sphinx.HeaderBG
        let label = UILabel()
        label.text = section == 0 ? "CONTACTS IN THE WORKSPACE" : "TRIBES"
        label.font = UIFont(name: "Roboto-Medium", size: 12) ?? .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .Sphinx.SecondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 32 }
}
