import UIKit

class WorkspaceFeaturesViewController: UIViewController {
    
    // MARK: - Properties
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadingWheel: UIActivityIndicatorView!
    @IBOutlet weak var emptyStateLabel: UILabel!
    @IBOutlet weak var createButton: UIButton!
    
    var workspace: Workspace!
    private var features: [HiveFeature] = []
    
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
        
        createButton.backgroundColor = .Sphinx.PrimaryBlue
//        createButton.setTitle("+", for: .normal)
//        createButton.titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .medium)
//        createButton.setTitleColor(.white, for: .normal)
        createButton.layer.cornerRadius = 28
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        createButton.layer.shadowRadius = 4
        createButton.layer.shadowOpacity = 0.3
//        createButton.translatesAutoresizingMaskIntoConstraints = false
        createButton.addTarget(self, action: #selector(createButtonTapped), for: .touchUpInside)
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
    }
    
    // MARK: - Actions

    @objc private func createButtonTapped() {
        let vc = CreateFeatureViewController.instantiate(workspaceId: workspace.id)
        vc.delegate = self
        present(vc, animated: true)
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
    
    // MARK: - Pusher Handler Methods

    func handleFeatureTitleUpdated(featureId: String, newTitle: String) {
        guard let index = features.firstIndex(where: { $0.id == featureId }) else { return }
        features[index].title = newTitle
        let indexPath = IndexPath(row: index, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }

    func handleFeatureListShouldRefresh() {
        loadFeatures()
    }

    func loadFeatures() {
        guard !isLoading else { return }
        
        isLoading = true
        
        print("[WorkspaceFeaturesVC] Loading features for workspace: \(workspace.id)")
        
        API.sharedInstance.fetchFeaturesWithAuth(
            workspaceId: workspace.id,
            callback: { [weak self] features in
                print("[WorkspaceFeaturesVC] Features loaded: \(features.count)")
                DispatchQueue.main.async {
                    self?.features = features
                    self?.tableView.reloadData()
                    self?.isLoading = false
                    self?.refreshControl.endRefreshing()
                }
            },
            errorCallback: { [weak self] in
                print("[WorkspaceFeaturesVC] Failed to load features")
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
    
    private func openFeaturePlan(feature: HiveFeature) {
        let planVC = FeaturePlanViewController.instantiate(feature: feature, workspace: workspace)
        navigationController?.pushViewController(planVC, animated: true)
    }
}

// MARK: - CreateFeatureViewControllerDelegate

extension WorkspaceFeaturesViewController: CreateFeatureViewControllerDelegate {
    func didCreateFeature(_ feature: HiveFeature) {
        loadFeatures()                     // fire-and-forget background refresh
        openFeaturePlan(feature: feature)  // navigate immediately, no waiting
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
