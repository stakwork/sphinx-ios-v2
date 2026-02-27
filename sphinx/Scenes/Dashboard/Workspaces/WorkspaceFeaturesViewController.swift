import UIKit

class WorkspaceFeaturesViewController: UIViewController {
    
    // MARK: - Properties
    
    var workspace: Workspace!
    private var features: [HiveFeature] = []
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.backgroundColor = .Sphinx.Body
        table.separatorStyle = .none
        table.rowHeight = 75
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    
    private lazy var loadingWheel: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "NO FEATURES FOUND"
        label.textColor = .Sphinx.SecondaryText
        label.font = UIFont(name: "Roboto-Regular", size: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .Sphinx.Text
        return control
    }()
    
    // MARK: - Instantiation
    
    static func instantiate(workspace: Workspace) -> WorkspaceFeaturesViewController {
        let viewController = WorkspaceFeaturesViewController()
        viewController.workspace = workspace
        return viewController
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupTableView()
        setupLoadingAndEmpty()
        addCreateButton()
        loadFeatures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload features when returning from detail view
        loadFeatures()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .Sphinx.Body
    }
    
    private func setupTableView() {
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(
            WorkspaceFeatureTableViewCell.nib,
            forCellReuseIdentifier: WorkspaceFeatureTableViewCell.reuseID
        )
        
        refreshControl.addTarget(
            self,
            action: #selector(handleRefresh),
            for: .valueChanged
        )
        tableView.refreshControl = refreshControl
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupLoadingAndEmpty() {
        view.addSubview(loadingWheel)
        view.addSubview(emptyStateLabel)
        
        NSLayoutConstraint.activate([
            loadingWheel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingWheel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func addCreateButton() {
        // Floating action button - bottom right
        let createButton = UIButton(type: .custom)
        createButton.backgroundColor = .Sphinx.PrimaryBlue
        createButton.setTitle("+", for: .normal)
        createButton.titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .medium)
        createButton.setTitleColor(.white, for: .normal)
        createButton.layer.cornerRadius = 28
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        createButton.layer.shadowRadius = 4
        createButton.layer.shadowOpacity = 0.3
        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
        
        view.addSubview(createButton)
        
        NSLayoutConstraint.activate([
            createButton.widthAnchor.constraint(equalToConstant: 56),
            createButton.heightAnchor.constraint(equalToConstant: 56),
            createButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            createButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func createButtonTapped() {
        let alert = UIAlertController(
            title: "New Feature",
            message: "Enter a name for the new feature",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Feature name"
            textField.autocapitalizationType = .sentences
        }
        
        let createAction = UIAlertAction(title: "Create", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let textField = alert?.textFields?.first,
                  let name = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { return }
            
            self.createFeature(name: name)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(createAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    @objc private func handleRefresh() {
        loadFeatures()
    }
    
    // MARK: - Data Loading
    
    private var isLoading = false {
        didSet {
            LoadingWheelHelper.toggleLoadingWheel(
                loading: isLoading,
                loadingWheel: loadingWheel,
                loadingWheelColor: .Sphinx.Text
            )
            tableView.isHidden = isLoading
            emptyStateLabel.isHidden = !features.isEmpty || isLoading
        }
    }
    
    private func loadFeatures() {
        guard !isLoading else { return }
        
        isLoading = true
        
        API.sharedInstance.fetchFeaturesWithAuth(
            workspaceId: workspace.id,
            callback: { [weak self] features in
                DispatchQueue.main.async {
                    self?.features = features
                    self?.tableView.reloadData()
                    self?.isLoading = false
                    self?.refreshControl.endRefreshing()
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    self?.features = []
                    self?.tableView.reloadData()
                    self?.isLoading = false
                    self?.refreshControl.endRefreshing()
                    
                    AlertHelper.showAlert(
                        title: "Error",
                        message: "Failed to load features. Please try again."
                    )
                }
            }
        )
    }
    
    private func createFeature(name: String) {
        LoadingWheelHelper.toggleLoadingWheel(
            loading: true,
            loadingWheel: loadingWheel,
            loadingWheelColor: .Sphinx.Text
        )
        
        API.sharedInstance.createFeatureWithAuth(
            workspaceId: workspace.id,
            name: name,
            callback: { [weak self] feature in
                DispatchQueue.main.async {
                    LoadingWheelHelper.toggleLoadingWheel(
                        loading: false,
                        loadingWheel: self?.loadingWheel ?? UIActivityIndicatorView(),
                        loadingWheelColor: .Sphinx.Text
                    )
                    
                    guard let feature = feature else {
                        AlertHelper.showAlert(
                            title: "Error",
                            message: "Failed to create feature."
                        )
                        return
                    }
                    
                    // Navigate to feature plan view
                    self?.openFeaturePlan(feature: feature)
                }
            },
            errorCallback: { [weak self] in
                DispatchQueue.main.async {
                    LoadingWheelHelper.toggleLoadingWheel(
                        loading: false,
                        loadingWheel: self?.loadingWheel ?? UIActivityIndicatorView(),
                        loadingWheelColor: .Sphinx.Text
                    )
                    
                    AlertHelper.showAlert(
                        title: "Error",
                        message: "Failed to create feature. Please try again."
                    )
                }
            }
        )
    }
    
    private func openFeaturePlan(feature: HiveFeature) {
        let planVC = FeaturePlanViewController.instantiate(feature: feature)
        navigationController?.pushViewController(planVC, animated: true)
    }
}

// MARK: - UITableView DataSource & Delegate

extension WorkspaceFeaturesViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return features.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: WorkspaceFeatureTableViewCell.reuseID,
            for: indexPath
        ) as? WorkspaceFeatureTableViewCell else {
            return UITableViewCell()
        }
        
        let feature = features[indexPath.row]
        let isLastRow = indexPath.row == features.count - 1
        cell.configure(with: feature, isLastRow: isLastRow)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let feature = features[indexPath.row]
        openFeaturePlan(feature: feature)
    }
}
