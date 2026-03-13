import UIKit

class HiveLinkNavigator {

    static func navigate(hiveLink: String, from vc: UIViewController) {
        guard let slug = hiveLink.hiveWorkspaceSlug,
              let entityId = hiveLink.hiveEntityId else {
            fallback(url: hiveLink)
            return
        }

        let bubbleHelper = NewMessageBubbleHelper()
        bubbleHelper.showLoadingWheel()

        API.sharedInstance.fetchWorkspacesWithAuth(
            callback: { workspaces in
                guard let workspace = workspaces.first(where: { $0.slug == slug }) else {
                    DispatchQueue.main.async {
                        bubbleHelper.hideLoadingWheel()
                        fallback(url: hiveLink)
                    }
                    return
                }

                if hiveLink.isHivePlanLink {
                    API.sharedInstance.fetchFeatureDetailWithAuth(
                        featureId: entityId,
                        callback: { feature in
                            DispatchQueue.main.async {
                                bubbleHelper.hideLoadingWheel()
                                guard let feature = feature else {
                                    fallback(url: hiveLink); return
                                }
                                let workspaceVC = WorkspaceViewController.instantiate(workspace: workspace)
                                let planVC = FeaturePlanViewController.instantiate(feature: feature, workspace: workspace)
                                
                                if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let rootVC = appDelegate.getRootViewController() {
                                    if let navVC = rootVC.getCenterNavigationController() {
                                        navVC.pushViewController(workspaceVC, animated: false)
                                        navVC.pushViewController(planVC, animated: true)
                                    }
                                }
                            }
                        },
                        errorCallback: {
                            DispatchQueue.main.async {
                                bubbleHelper.hideLoadingWheel()
                                fallback(url: hiveLink)
                            }
                        }
                    )
                } else if hiveLink.isHiveTaskLink {
                    API.sharedInstance.fetchTasksWithAuth(
                        workspaceId: workspace.id,
                        callback: { tasks, _ in
                            DispatchQueue.main.async {
                                bubbleHelper.hideLoadingWheel()
                                guard let task = tasks.first(where: { $0.id == entityId }) else {
                                    fallback(url: hiveLink); return
                                }
                                let workspaceVC = WorkspaceViewController.instantiate(workspace: workspace)
                                let taskChatVC = TaskChatViewController.instantiate(task: task, workspaceSlug: workspace.slug ?? "", workspaceId: workspace.id)
                                
                                if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let rootVC = appDelegate.getRootViewController() {
                                    if let navVC = rootVC.getCenterNavigationController() {
                                        navVC.pushViewController(workspaceVC, animated: false)
                                        navVC.pushViewController(taskChatVC, animated: true)
                                    }
                                }
                            }
                        },
                        errorCallback: {
                            DispatchQueue.main.async {
                                bubbleHelper.hideLoadingWheel()
                                fallback(url: hiveLink)
                            }
                        }
                    )
                }
            },
            errorCallback: {
                DispatchQueue.main.async {
                    bubbleHelper.hideLoadingWheel()
                    fallback(url: hiveLink)
                }
            }
        )
    }

    private static func fallback(url: String) {
        guard let url = URL(string: url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
