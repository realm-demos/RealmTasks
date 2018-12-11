////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016-2017 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Cartography
import RealmSwift
import UIKit

private enum NavDirection {
    case up, down
}

enum ViewControllerType {
    case lists
    case defaultListTasks
    case tasks(TaskList)
}

enum ViewControllerPosition {
    case up(ViewControllerType)
    case down(ViewControllerType)
}

// MARK: View Controller
// swiftlint:disable:next type_body_length
final class ViewController<Item, Parent: Object>: UIViewController, UIGestureRecognizerDelegate,
    UIScrollViewDelegate, ViewControllerProtocol where Parent: ListPresentable, Parent.Item == Item {

    // MARK: Properties
    var items: List<Item> {
        return listPresenter.parent.items
    }

    // Cast first to existential to placate generic type checking.
    private static func castCell(cell: UITableViewCell?) -> TableViewCell<Item>? {
        return cell as Any as? TableViewCell<Item>
    }

    // Table View
    internal let tableView = UITableView()
    internal let tableViewContentView = UIView()

    // Scrolling
    private var distancePulledDown: CGFloat {
        let contentInset: UIEdgeInsets
        if #available(iOS 11.0, *) {
            contentInset = tableView.adjustedContentInset
        } else {
            contentInset = tableView.contentInset
        }
        return -tableView.contentOffset.y - contentInset.top
    }
    private var distancePulledUp: CGFloat {
        return tableView.contentOffset.y + tableView.bounds.size.height - max(tableView.bounds.size.height, tableView.contentSize.height)
    }

    // Auto Layout
    private var topConstraint: NSLayoutConstraint?
    private var nextConstraints: ConstraintGroup?

    // Top/Bottom View Controllers
    private var topViewController: UIViewController?
    private var bottomViewController: UIViewController?

    private var listPresenter: ListPresenter<Item, Parent>!

    // MARK: UI Writes
    func uiWrite(block: () -> Void) {
        uiWriteNoUpdateList(block: block)
        didUpdateList(reload: false)
    }

    func uiWriteNoUpdateList(block: () -> Void) {
        items.realm?.beginWrite()
        block()
        commitUIWrite()
    }

    func finishUIWrite() {
        commitUIWrite()
        didUpdateList(reload: false)
    }

    private func commitUIWrite() {
        _ = try? items.realm?.commitWrite(withoutNotifying: [listPresenter.notificationToken!])
    }

    // MARK: View Lifecycle

    init(parent: Parent, colors: [UIColor]) {
        super.init(nibName: nil, bundle: nil)

        listPresenter = ListPresenter(parent: parent, colors: colors)
        listPresenter.viewController = self

        if Item.self == Task.self {
            auxViewController = .up(.lists)
        } else {
            auxViewController = .down(.defaultListTasks)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestureRecognizers()
    }

    // MARK: UI

    private func setupUI() {
        listPresenter.tablePresenter.setupTableView(in: view, topConstraint: &topConstraint, listTitle: title)
        listPresenter.tablePresenter.setupPlaceholderCell(in: tableView)

        tableView.dataSource = listPresenter.tablePresenter
        tableView.delegate = listPresenter.tablePresenter

        listPresenter.updateOnboardView()
    }

    override func didMove(toParentViewController parent: UIViewController?) {
        guard parent == nil else { // we're being removed from our parent controller
            return
        }

        let visibleCells = tableView.visibleCells
        for cell in visibleCells {
            ViewController.castCell(cell: cell)?.reset()
        }
    }

    // MARK: Gesture Recognizers

    private func setupGestureRecognizers() {
        tableView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized(recognizer:))))
    }

    @objc func tapGestureRecognized(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else {
            return
        }
        if listPresenter.cellPresenter.currentlyEditing {
            view.endEditing(true)
            return
        }
        let location = recognizer.location(in: tableView)
        let cell: TableViewCell<Item>!
        if let indexPath = tableView.indexPathForRow(at: location),
            let typedCell = ViewController.castCell(cell: tableView.cellForRow(at: indexPath)) {
            cell = typedCell
            if case .down(_) = auxViewController!, location.x > tableView.bounds.width / 2 {
                navigateToBottomViewController(item: cell.item)
                return
            }
        } else {
            items.realm?.beginWrite()
            let row = items.filter("completed = false").count
            items.insert(Item(), at: row)
            let indexPath = IndexPath(row: row, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
            cell = ViewController.castCell(cell: tableView.cellForRow(at: indexPath))!
            finishUIWrite()
            listPresenter.updateOnboardView(animated: true)
        }
        let textView = cell.textView
        textView.isUserInteractionEnabled = !textView.isUserInteractionEnabled
        textView.becomeFirstResponder()
    }

    private func navigateToBottomViewController(item: Item) {
        guard let list = item as? TaskList else { return }

        auxViewController = .down(.tasks(list))
        bottomViewController = createAuxController()

        startMovingToNextViewController(direction: .down)
        finishMovingToNextViewController(direction: .down)
    }

    private func startMovingToNextViewController(direction: NavDirection) {
        let nextVC = direction == .up ? topViewController! : bottomViewController!
        let parentVC = parent as! ContainerViewController
        parentVC.addChildViewController(nextVC)
        parentVC.containerView.insertSubview(nextVC.view, at: 1)
        view.removeAllConstraints()
        nextConstraints = constrain(nextVC.view, tableViewContentView) { nextView, tableViewContentView in
            nextView.size == nextView.superview!.size
            nextView.left == nextView.superview!.left
            if direction == .up {
                nextView.bottom == tableViewContentView.top - 200
            } else {
                nextView.top == tableViewContentView.bottom + tableView.rowHeight + tableView.contentInset.bottom
            }
        }
        nextVC.didMove(toParentViewController: parentVC)
    }

    private func finishMovingToNextViewController(direction: NavDirection) {
        let nextVC = direction == .up ? topViewController! : bottomViewController!
        let parentVC = parent!
        willMove(toParentViewController: nil)
        parentVC.title = nextVC.title
        parentVC.view.layoutIfNeeded()
        constrain(nextVC.view, view, replace: nextConstraints!) { nextView, currentView in
            nextView.edges == nextView.superview!.edges
            if direction == .up {
                currentView.top == nextView.bottom
            } else {
                currentView.bottom == nextView.top
            }
            currentView.size == nextView.size
            currentView.left == nextView.left
        }
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [], animations: {
            parentVC.view.layoutIfNeeded()
        }, completion: { [unowned self] _ in
            self.view.removeFromSuperview()
            nextVC.didMove(toParentViewController: parentVC)
            self.removeFromParentViewController()
        })
    }

    // MARK: UIScrollViewDelegate methods

    // FIXME: This could easily be refactored to avoid such a high CC.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        func removeVC(_ viewController: UIViewController?) {
            if scrollView.isDragging {
                viewController?.view.removeFromSuperview()
                viewController?.removeFromParentViewController()
            }
        }

        if case .down(_) = auxViewController!, distancePulledUp > tableView.rowHeight {
            if bottomViewController === parent?.childViewControllers.last { return }
            if bottomViewController == nil {
                bottomViewController = createAuxController()
            }
            startMovingToNextViewController(direction: .down)
            return
        } else {
            removeVC(bottomViewController)
        }

        guard distancePulledDown > 0 else {
            removeVC(topViewController)
            return
        }

        let cellHeight = tableView.rowHeight

        if distancePulledDown <= tableView.rowHeight {
            listPresenter.tablePresenter
                .adjustPlaceholder(state: .pullToCreate(distance: distancePulledDown))
            listPresenter.setOnboardAlpha(to: max(0, 1 - (distancePulledDown / cellHeight)))
        } else if distancePulledDown <= tableView.rowHeight * 2 {
            listPresenter.tablePresenter.adjustPlaceholder(state: .releaseToCreate)
        } else if case .up(_) = auxViewController! {
            if topViewController === parent?.childViewControllers.last { return }
            if topViewController == nil {
                topViewController = createAuxController()
            }
            startMovingToNextViewController(direction: .up)

            listPresenter.tablePresenter.adjustPlaceholder(state: .switchToLists)

            return
        }

        if scrollView.isDragging {
            removeVC(topViewController)
            setPlaceholderAlpha(to: min(1, distancePulledDown / tableView.rowHeight))
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if distancePulledUp > tableView.rowHeight {
            if bottomViewController === parent?.childViewControllers.last {
                finishMovingToNextViewController(direction: .down)
            } else {
                items.realm?.beginWrite()
                let itemsToDelete = items.filter("completed = true")
                let numberOfItemsToDelete = itemsToDelete.count
                guard numberOfItemsToDelete != 0 else {
                    items.realm?.cancelWrite()
                    return
                }

                items.realm?.delete(itemsToDelete)

                let startingIndex = items.count
                let indexPathsToDelete = (startingIndex..<(startingIndex + numberOfItemsToDelete)).map { index in
                    return IndexPath(row: index, section: 0)
                }
                tableView.deleteRows(at: indexPathsToDelete, with: .automatic)
                finishUIWrite()
                vibrate()
            }
            return
        }

        guard distancePulledDown > tableView.rowHeight else { return }

        if distancePulledDown > tableView.rowHeight * 2 &&
            topViewController === parent?.childViewControllers.last {
            finishMovingToNextViewController(direction: .up)
            return
        }
        // Create new item
        uiWrite {
            items.insert(Item(), at: 0)
        }
        tableView.reloadData()
        if let firstCell = ViewController.castCell(cell: tableView.visibleCells.first) {
            firstCell.textView.becomeFirstResponder()
        }
    }

    // MARK: ViewControllerProtocol

    func didUpdateList(reload: Bool) {
        listPresenter.tablePresenter.updateColors()
        listPresenter.updateOnboardView()
        if reload { tableView.reloadData() }
    }

    func setTopConstraint(to constant: CGFloat) {
        topConstraint?.constant = constant
    }

    func setPlaceholderAlpha(to alpha: CGFloat) {
        listPresenter.tablePresenter.adjustPlaceholder(state: .alpha(alpha))
    }

    func setListTitle(to title: String) {
        self.title = title
        parent?.title = title
    }

    // MARK: NavigationProtocol

    var auxViewController: ViewControllerPosition?

    func createAuxController() -> UIViewController? {
        let listType: ViewControllerType

        guard let auxViewControllerType = auxViewController else {
            return nil
        }

        switch auxViewControllerType {
        case .up(let type): listType = type
        case .down(let type): listType = type
        }

        switch listType {
        case .lists:
            return ViewController<TaskList, TaskListList>(
                parent: try! Realm().objects(TaskListList.self).first!,
                colors: UIColor.listColors()
            )
        case .defaultListTasks:
            return ViewController<Task, TaskList>(
                parent: try! Realm().objects(TaskList.self).first!,
                colors: UIColor.taskColors()
            )
        case .tasks(let list):
            return ViewController<Task, TaskList>(
                parent: list,
                colors: UIColor.taskColors()
            )
        }
    }
}
