////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
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
    case Up, Down
}

enum ViewControllerType {
    case Lists
    case DefaultListTasks
    case Tasks(TaskList)
}

enum ViewControllerPosition {
    case Up(ViewControllerType)
    case Down(ViewControllerType)
}

// MARK: View Controller

// swiftlint:disable:next type_body_length
final class ViewController<Item: Object, Parent: Object where Item: CellPresentable, Parent: ListPresentable, Parent.Item == Item>:
    UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, ViewControllerProtocol {

    // MARK: Properties
    var items: List<Item> {
        return listPresenter.parent.items
    }

    // Table View
    internal let tableView = UITableView()
    internal let tableViewContentView = UIView()

    // Scrolling
    private var distancePulledDown: CGFloat {
        return -tableView.contentOffset.y - tableView.contentInset.top
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

    func uiWrite(@noescape block: () -> Void) {
        uiWriteNoUpdateList(block)
        didUpdateList(reload: false)
    }

    func uiWriteNoUpdateList(@noescape block: () -> Void) {
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
            auxViewController = .Up(.Lists)
        } else {
            auxViewController = .Down(.DefaultListTasks)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestureRecognizers()
    }

    // MARK: UI

    private func setupUI() {
        listPresenter.tablePresenter.setupTableView(inView: view, topConstraint: &topConstraint, listTitle: title)
        listPresenter.tablePresenter.setupPlaceholderCell(inTableView: tableView)

        tableView.dataSource = listPresenter.tablePresenter
        tableView.delegate = listPresenter.tablePresenter

        listPresenter.updateOnboardView()
    }

    override func didMoveToParentViewController(parent: UIViewController?) {
        guard parent == nil else { // we're being removed from our parent controller
            return
        }

        let visibleCells = tableView.visibleCells
        for cell in visibleCells {
            (cell as! TableViewCell<Item>).reset()
        }
    }

    // MARK: Gesture Recognizers

    private func setupGestureRecognizers() {
        tableView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized(_:))))
    }

    func tapGestureRecognized(recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .Ended else {
            return
        }
        if listPresenter.cellPresenter.currentlyEditing {
            view.endEditing(true)
            return
        }
        let location = recognizer.locationInView(tableView)
        let cell: TableViewCell<Item>!
        if let indexPath = tableView.indexPathForRowAtPoint(location),
            let typedCell = tableView.cellForRowAtIndexPath(indexPath) as? TableViewCell<Item> {
            cell = typedCell
            if case .Down(_) = auxViewController! where location.x > tableView.bounds.width / 2 {
                navigateToBottomViewController(cell.item)
                return
            }
        } else {
            items.realm?.beginWrite()
            let row = items.filter("completed = false").count
            items.insert(Item(), atIndex: row)
            let indexPath = NSIndexPath(forRow: row, inSection: 0)
            tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            cell = tableView.cellForRowAtIndexPath(indexPath) as! TableViewCell<Item>
            finishUIWrite()
            listPresenter.updateOnboardView(true)
        }
        let textView = cell.textView
        textView.userInteractionEnabled = !textView.userInteractionEnabled
        textView.becomeFirstResponder()
    }

    private func navigateToBottomViewController(item: Item) {
        guard let list = item as? TaskList else { return }

        auxViewController = .Down(.Tasks(list))
        bottomViewController = createAuxController()

        startMovingToNextViewController(.Down)
        finishMovingToNextViewController(.Down)
    }

    private func startMovingToNextViewController(direction: NavDirection) {
        let nextVC = direction == .Up ? topViewController! : bottomViewController!
        let parentVC = parentViewController!
        parentVC.addChildViewController(nextVC)
        parentVC.view.insertSubview(nextVC.view, atIndex: 1)
        view.removeAllConstraints()
        nextConstraints = constrain(nextVC.view, tableViewContentView) { nextView, tableViewContentView in
            nextView.size == nextView.superview!.size
            nextView.left == nextView.superview!.left
            if direction == .Up {
                nextView.bottom == tableViewContentView.top - 200
            } else {
                nextView.top == tableViewContentView.bottom + tableView.rowHeight + tableView.contentInset.bottom
            }
        }
        nextVC.didMoveToParentViewController(parentVC)
    }

    private func finishMovingToNextViewController(direction: NavDirection) {
        let nextVC = direction == .Up ? topViewController! : bottomViewController!
        let parentVC = parentViewController!
        willMoveToParentViewController(nil)
        parentVC.title = nextVC.title
        parentVC.view.layoutIfNeeded()
        constrain(nextVC.view, view, replace: nextConstraints!) { nextView, currentView in
            nextView.edges == nextView.superview!.edges
            if direction == .Up {
                currentView.top == nextView.bottom
            } else {
                currentView.bottom == nextView.top
            }
            currentView.size == nextView.size
            currentView.left == nextView.left
        }
        UIView.animateWithDuration(0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5, options: [], animations: {
            parentVC.view.layoutIfNeeded()
        }, completion: { [unowned self] _ in
            self.view.removeFromSuperview()
            nextVC.didMoveToParentViewController(parentVC)
            self.removeFromParentViewController()
        })
    }

    // MARK: UIScrollViewDelegate methods

    // FIXME: This could easily be refactored to avoid such a high CC.
    // swiftlint:disable:next cyclomatic_complexity
    func scrollViewDidScroll(scrollView: UIScrollView) {
        func removeVC(viewController: UIViewController?) {
            if scrollView.dragging {
                viewController?.view.removeFromSuperview()
                viewController?.removeFromParentViewController()
            }
        }

        if case .Down(_) = auxViewController! where distancePulledUp > tableView.rowHeight {
            if bottomViewController === parentViewController?.childViewControllers.last { return }
            if bottomViewController == nil {
                bottomViewController = createAuxController()
            }
            startMovingToNextViewController(.Down)
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
                .adjustPlaceholder(.pullToCreate(distance: distancePulledDown))
            listPresenter.setOnboardAlpha(max(0, 1 - (distancePulledDown / cellHeight)))
        } else if distancePulledDown <= tableView.rowHeight * 2 {
            listPresenter.tablePresenter.adjustPlaceholder(.releaseToCreate)
        } else if case .Up(_) = auxViewController! {
            if topViewController === parentViewController?.childViewControllers.last { return }
            if topViewController == nil {
                topViewController = createAuxController()
            }
            startMovingToNextViewController(.Up)

            listPresenter.tablePresenter.adjustPlaceholder(.switchToLists)

            return
        }

        if scrollView.dragging {
            removeVC(topViewController)
            setPlaceholderAlpha(min(1, distancePulledDown / tableView.rowHeight))
        }
    }

    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if distancePulledUp > tableView.rowHeight {
            if bottomViewController === parentViewController?.childViewControllers.last {
                finishMovingToNextViewController(.Down)
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
                    return NSIndexPath(forRow: index, inSection: 0)
                }
                tableView.deleteRowsAtIndexPaths(indexPathsToDelete, withRowAnimation: .Automatic)
                finishUIWrite()
                vibrate()
            }
            return
        }

        guard distancePulledDown > tableView.rowHeight else { return }

        if distancePulledDown > tableView.rowHeight * 2 &&
            topViewController === parentViewController?.childViewControllers.last {
            finishMovingToNextViewController(.Up)
            return
        }
        // Create new item
        uiWrite {
            items.insert(Item(), atIndex: 0)
        }
        tableView.reloadData()
        if let firstCell = tableView.visibleCells.first as? TableViewCell<Item> {
            firstCell.textView.becomeFirstResponder()
        }
    }

    // MARK: ViewControllerProtocol

    func didUpdateList(reload reload: Bool) {
        listPresenter.tablePresenter.updateColors()
        listPresenter.updateOnboardView()
        if reload { tableView.reloadData() }
    }

    func setTopConstraintTo(constant constant: CGFloat) {
        topConstraint?.constant = constant
    }

    func setPlaceholderAlpha(alpha: CGFloat) {
        listPresenter.tablePresenter.adjustPlaceholder(.alpha(alpha))
    }

    func setListTitle(title: String) {
        self.title = title
        parentViewController?.title = title
    }

    // MARK: NavigationProtocol

    var auxViewController: ViewControllerPosition?

    func createAuxController() -> UIViewController? {
        let listType: ViewControllerType

        guard let auxViewControllerType = auxViewController else {
            return nil
        }

        switch auxViewControllerType {
        case .Up(let type): listType = type
        case .Down(let type): listType = type
        }

        switch listType {
        case .Lists:
            return ViewController<TaskList, TaskListList>(
                parent: try! Realm().objects(TaskListList.self).first!,
                colors: UIColor.listColors()
            )
        case .DefaultListTasks:
            return ViewController<Task, TaskList>(
                parent: try! Realm().objects(TaskList.self).first!,
                colors: UIColor.taskColors()
            )
        case .Tasks(let list):
            return ViewController<Task, TaskList>(
                parent: list,
                colors: UIColor.taskColors()
            )
        }
    }
}
