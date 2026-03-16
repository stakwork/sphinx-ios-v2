import UIKit

class WorkspaceFeaturesViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    
    var workspace: Workspace!
    private var features: [HiveFeature] = []
    private var currentPage = 1
    private var totalPages = 1
    private weak var paginationView: PaginationControlView?
    private var paginationHasBeenBuilt = false
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = .Sphinx.Text
        return control
    }()
    
    // MARK: - Instantiation

    static func instantiate(workspace: Workspace) -> WorkspaceFeaturesViewController {
        let vc = StoryboardScene.Dashboard.workspaceFeaturesViewController.instantiate()
        vc.workspace = workspace
        return vc
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupTableView()
        setupPaginationView()
        loadFeatures()
    }

    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .Sphinx.Body
        
        tableView.backgroundColor = .Sphinx.Body
        tableView.separatorStyle = .none
        tableView.rowHeight = 110
        tableView.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 0, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        loadingWheel.translatesAutoresizingMaskIntoConstraints = false
        loadingWheel.hidesWhenStopped = true
        
        emptyStateLabel.text = "NO FEATURES FOUND"
        emptyStateLabel.textColor = .Sphinx.SecondaryText
        emptyStateLabel.font = UIFont(name: "Roboto-Regular", size: 16)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isHidden = true
    }
    
    private func setupTableView() {
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
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 8))
    }
    
    private func setupPaginationView() {
        let pagination = PaginationControlView()
        pagination.delegate = self
        pagination.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pagination)
        
        NSLayoutConstraint.activate([
            pagination.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pagination.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            pagination.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pagination.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        // Re-pin tableView bottom to pagination top instead of safe area bottom
        if let existingBottom = tableView.constraints.first(where: {
            ($0.firstItem as? UIView == tableView && $0.firstAttribute == .bottom) ||
            ($0.secondItem as? UIView == tableView && $0.secondAttribute == .bottom)
        }) {
            existingBottom.isActive = false
        }
        // Also check view's constraints for tableView bottom
        for constraint in view.constraints {
            let isTableBottom = (constraint.firstItem as? UITableView == tableView && constraint.firstAttribute == .bottom)
                || (constraint.secondItem as? UITableView == tableView && constraint.secondAttribute == .bottom)
            if isTableBottom {
                constraint.isActive = false
            }
        }
        
        tableView.bottomAnchor.constraint(equalTo: pagination.topAnchor, constant: -8).isActive = true
        
        paginationView = pagination
    }
    
    // MARK: - Actions

    func createButtonTapped() {
        let vc = CreateFeatureViewController.instantiate(workspaceId: workspace.id)
        vc.delegate = self
        present(vc, animated: true)
    }
    
    @objc private func handleRefresh() {
        currentPage = 1
        paginationHasBeenBuilt = false
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
            if !paginationHasBeenBuilt {
                paginationView?.isHidden = isLoading
            }
            emptyStateLabel.isHidden = !features.isEmpty || isLoading
        }
    }
    
    // MARK: - Pusher Handler Methods

    func handleFeatureTitleUpdated(featureId: String, newTitle: String) {
        guard let index = features.firstIndex(where: { $0.id == featureId }) else { return }
        features[index].title = newTitle
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    func handleFeatureListShouldRefresh() {
        loadFeatures(showLoading: false)
    }

    func loadFeatures(showLoading: Bool = true) {
        guard !isLoading else { return }
        if showLoading { isLoading = true }
        
        print("[WorkspaceFeaturesVC] Loading features for workspace: \(workspace.id), page: \(currentPage)")
        
        API.sharedInstance.fetchFeaturesWithAuth(
            workspaceId: workspace.id,
            page: currentPage,
            callback: { [weak self] features, info in
                guard let self else { return }
                print("[WorkspaceFeaturesVC] Features loaded: \(features.count), totalPages: \(info.totalPages)")
                DispatchQueue.main.async {
                    self.totalPages = info.totalPages
                    self.features = features
                    self.tableView.reloadData()
                    self.paginationView?.configure(currentPage: self.currentPage, totalPages: info.totalPages)
                    self.paginationHasBeenBuilt = true
                    self.isLoading = false
                    self.refreshControl.endRefreshing()
                }
            },
            errorCallback: { [weak self] in
                guard let self else { return }
                print("[WorkspaceFeaturesVC] Failed to load features")
                DispatchQueue.main.async {
                    self.features = []
                    self.tableView.reloadData()
                    self.isLoading = false
                    self.refreshControl.endRefreshing()
                    
                    AlertHelper.showAlert(
                        title: "Error",
                        message: "Failed to load features. Please try again."
                    )
                }
            }
        )
    }
    
    private func openFeaturePlan(feature: HiveFeature) {
        let planVC = FeaturePlanViewController.instantiate(feature: feature, workspace: workspace)
        navigationController?.pushViewController(planVC, animated: true)
    }
}

// MARK: - PaginationControlViewDelegate

extension WorkspaceFeaturesViewController: PaginationControlViewDelegate {
    func paginationControlView(_ view: PaginationControlView, didSelectPage page: Int) {
        currentPage = page
        loadFeatures()
        tableView.setContentOffset(.zero, animated: false)
    }
}

// MARK: - CreateFeatureViewControllerDelegate

extension WorkspaceFeaturesViewController: CreateFeatureViewControllerDelegate {
    func didCreateFeature(_ feature: HiveFeature) {
        loadFeatures(showLoading: false)   // fire-and-forget background refresh
        openFeaturePlan(feature: feature)  // navigate immediately, no waiting
    }
}

// MARK: - WorkspaceFeatureTableViewCellDelegate

extension WorkspaceFeaturesViewController: WorkspaceFeatureTableViewCellDelegate {

    func cell(_ cell: WorkspaceFeatureTableViewCell, didTapStatusFor featureId: String) {
        guard let index = features.firstIndex(where: { $0.id == featureId }) else { return }
        let feature = features[index]
        let indexPath = IndexPath(row: index, section: 0)
        let statusOptions = ["BACKLOG", "PLANNED", "IN_PROGRESS", "COMPLETED", "CANCELLED", "ERROR", "BLOCKED"]

        let alert = UIAlertController(title: "Set Status", message: nil, preferredStyle: .actionSheet)
        for option in statusOptions {
            let isCurrent = feature.status?.uppercased() == option
            let displayTitle = option
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            let title = isCurrent ? "✓ \(displayTitle)" : displayTitle
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                let previousValue = self.features[index].status
                self.features[index].status = option
                self.tableView.reloadRows(at: [indexPath], with: .none)
                API.sharedInstance.updateFeatureWithAuth(
                    featureId: featureId,
                    status: option,
                    priority: nil,
                    callback: { _ in },
                    errorCallback: { [weak self] in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            self.features[index].status = previousValue
                            self.tableView.reloadRows(at: [indexPath], with: .none)
                            AlertHelper.showAlert(title: "Error", message: "Failed to update feature.")
                        }
                    }
                )
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell.contentView
            popover.sourceRect = cell.contentView.bounds
        }
        present(alert, animated: true)
    }

    func cell(_ cell: WorkspaceFeatureTableViewCell, didTapPriorityFor featureId: String) {
        guard let index = features.firstIndex(where: { $0.id == featureId }) else { return }
        let feature = features[index]
        let indexPath = IndexPath(row: index, section: 0)
        let priorityOptions = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]

        let alert = UIAlertController(title: "Set Priority", message: nil, preferredStyle: .actionSheet)
        for option in priorityOptions {
            let isCurrent = feature.priority?.uppercased() == option
            let displayTitle = option.capitalized
            let title = isCurrent ? "✓ \(displayTitle)" : displayTitle
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                guard let self = self else { return }
                let previousValue = self.features[index].priority
                self.features[index].priority = option
                self.tableView.reloadRows(at: [indexPath], with: .none)
                API.sharedInstance.updateFeatureWithAuth(
                    featureId: featureId,
                    status: nil,
                    priority: option,
                    callback: { _ in },
                    errorCallback: { [weak self] in
                        guard let self = self else { return }
                        DispatchQueue.main.async {
                            self.features[index].priority = previousValue
                            self.tableView.reloadRows(at: [indexPath], with: .none)
                            AlertHelper.showAlert(title: "Error", message: "Failed to update feature.")
                        }
                    }
                )
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = cell.contentView
            popover.sourceRect = cell.contentView.bounds
        }
        present(alert, animated: true)
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
        cell.delegate = self
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let feature = features[indexPath.row]
        openFeaturePlan(feature: feature)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let feature = features[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completionHandler in
            guard let self else { completionHandler(false); return }
            AlertHelper.showTwoOptionsAlert(
                title: "Delete Feature",
                message: "Are you sure you want to delete \"\(feature.title)\"? This cannot be undone.",
                confirmButtonTitle: "Delete",
                confirmStyle: .destructive,
                confirm: {
                    self.features.remove(at: indexPath.row)
                    self.tableView.deleteRows(at: [indexPath], with: .automatic)
                    API.sharedInstance.deleteFeatureWithAuth(featureId: feature.id) {
                        DispatchQueue.main.async { self.loadFeatures(showLoading: false) }
                    } errorCallback: {
                        DispatchQueue.main.async { self.loadFeatures(showLoading: false) }
                    }
                }
            )
            completionHandler(true)
        }
        deleteAction.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
