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
import Foundation
import RealmSwift
import UIKit

private var tableViewBoundsKVOContext = 0

enum PlaceholderState {
    case pullToCreate(distance: CGFloat)
    case releaseToCreate
    case switchToLists
    case alpha(CGFloat)
}

class TablePresenter<Parent: Object>: NSObject,
UITableViewDataSource, UITableViewDelegate, UIGestureRecognizerDelegate where Parent: ListPresentable {

    // Cast first to existential to placate generic type checking.
    private func castCell(cell: UITableViewCell?) -> TableViewCell<Parent.Item>? {
        return cell as Any as? TableViewCell<Parent.Item>
    }

    var viewController: ViewControllerProtocol! {
        didSet {
            setupMovingGesture()
        }
    }
    weak var cellPresenter: CellPresenter<Parent.Item>!

    private var items: List<Parent.Item> {
        return parent.items
    }

    private let parent: Parent
    init(parent: Parent, colors: [UIColor]) {
        self.parent = parent
        self.colors = colors
    }

    deinit {
        boundsToken?.invalidate()
    }

    // MARK: Setup table view
    private var boundsToken: NSKeyValueObservation?

    func setupTableView(in view: UIView, topConstraint: inout NSLayoutConstraint?, listTitle title: String?) {
        let tableView = viewController.tableView
        let tableViewContentView = viewController.tableViewContentView

        view.addSubview(tableView)
        constrain(tableView) { tableView in
            topConstraint = (tableView.top == tableView.superview!.top)
            tableView.right == tableView.superview!.right
            tableView.bottom == tableView.superview!.bottom
            tableView.left == tableView.superview!.left
        }

        tableView.register(TableViewCell<Parent.Item>.self, forCellReuseIdentifier: "cell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .black
        tableView.rowHeight = 54
        tableView.showsVerticalScrollIndicator = false

        view.addSubview(tableViewContentView)
        tableViewContentView.isHidden = true

        boundsToken = tableView.observe(\UITableView.bounds) { [weak self] _, _ in
            guard let viewController = self?.viewController else { return }
            let tableView = viewController.tableView
            let tableViewContentView = viewController.tableViewContentView
            let view = tableView.superview!
            let height = max(view.frame.height - tableView.contentInset.top, tableView.contentSize.height + tableView.contentInset.bottom)
            tableViewContentView.frame = CGRect(x: 0, y: -tableView.contentOffset.y, width: view.frame.width, height: height)
        }
    }

    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = castCell(cell: viewController.tableView.dequeueReusableCell(withIdentifier: "cell",
                                                                               for: indexPath))!
        cell.item = items[indexPath.row]
        cell.presenter = cellPresenter

        if let editingIndexPath = cellPresenter.currentlyEditingIndexPath, editingIndexPath.row != indexPath.row {
            cell.alpha = editingCellAlpha
        }

        return cell
    }

    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if cellPresenter.currentlyEditingIndexPath?.row == indexPath.row {
//            return floor(cellPresenter.cellHeight(forText: cellPresenter.currentlyEditingCell!.textView.text, timeHidden: true))
//        }

        var item = items[indexPath.row]

        // If we are dragging an item around, swap those
        // two items for their appropriate height values
        if let startIndexPath = startIndexPath, let destinationIndexPath = destinationIndexPath {
            if indexPath.row == destinationIndexPath.row {
                item = items[startIndexPath.row]
            } else if indexPath.row == startIndexPath.row {
                item = items[destinationIndexPath.row]
            }
        }
        return floor(max(cellPresenter.cellHeight(forText: item.text, timeHidden: item.date == nil), tableView.rowHeight))
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.contentView.backgroundColor = color(forRow: indexPath.row)
        cell.alpha = cellPresenter.currentlyEditing ? editingCellAlpha : 1
    }

    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let itemCell = castCell(cell: cell)!
        itemCell.reset()
    }

    // MARK: UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        viewController.scrollViewDidScroll?(scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        viewController.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
    }

    // MARK: Moving

    private var snapshot: UIView!
    private var startIndexPath: IndexPath?
    private var destinationIndexPath: IndexPath?

    private func setupMovingGesture() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressGestureRecognized(recognizer:)))
        longPressGestureRecognizer.delegate = self
        viewController.tableView.addGestureRecognizer(longPressGestureRecognizer)
    }

    @objc func longPressGestureRecognized(recognizer: UILongPressGestureRecognizer) {
        let tableView = viewController.tableView

        let location = recognizer.location(in: tableView)
        let indexPath = tableView.indexPathForRow(at: location) ?? IndexPath(row: items.count - 1, section: 0)

        switch recognizer.state {
        case .began:
            guard let cell = tableView.cellForRow(at: indexPath) else { break }
            startIndexPath = indexPath
            destinationIndexPath = indexPath

            // Add the snapshot as subview, aligned with the cell
            var center = cell.center
            UIGraphicsBeginImageContextWithOptions(cell.frame.size, true, 0)
            cell.layer.render(in: UIGraphicsGetCurrentContext()!)
            snapshot = UIImageView(image: UIGraphicsGetImageFromCurrentImageContext()!)
            UIGraphicsEndImageContext()
            snapshot.layer.shadowColor = UIColor.black.cgColor
            snapshot.layer.shadowOffset = CGSize(width: -5, height: 0)
            snapshot.layer.shadowRadius = 5
            snapshot.center = center
            cell.isHidden = true
            tableView.addSubview(snapshot)

            // Animate
            let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            shadowAnimation.fromValue = 0
            shadowAnimation.toValue = 1
            shadowAnimation.duration = 0.3
            snapshot.layer.add(shadowAnimation, forKey: shadowAnimation.keyPath)
            snapshot.layer.shadowOpacity = 1
            UIView.animate(withDuration: 0.3) { [unowned self] in
                center.y = location.y
                self.snapshot.center = center
                self.snapshot.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }
        case .changed:
            snapshot.center.y = location.y

            if let destinationPath = destinationIndexPath, indexPath != destinationPath && !items[indexPath.row].completed {
                // move rows
                tableView.moveRow(at: destinationPath, to: indexPath)
                destinationIndexPath = indexPath
            }
        case .ended, .cancelled, .failed:
            guard
                let startIndexPath = startIndexPath,
                let destinationIndexPath = destinationIndexPath,
                let cell = tableView.cellForRow(at: destinationIndexPath)
                else { break }

            if destinationIndexPath.row != startIndexPath.row && !items[destinationIndexPath.row].completed {
                viewController.uiWriteNoUpdateList {
                    items.move(from: startIndexPath.row, to: destinationIndexPath.row)
                }
            }

            let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            shadowAnimation.fromValue = 1
            shadowAnimation.toValue = 0
            shadowAnimation.duration = 0.3
            snapshot.layer.add(shadowAnimation, forKey: shadowAnimation.keyPath)
            snapshot.layer.shadowOpacity = 0

            UIView.animate(withDuration: 0.3, animations: { [unowned self] in
                self.snapshot.center = cell.center
                self.snapshot.transform = .identity
            }, completion: { [unowned self] _ in
                cell.isHidden = false
                self.snapshot.removeFromSuperview()
                self.snapshot = nil

                self.viewController.didUpdateList(reload: false)
            })

            self.startIndexPath = nil
            self.destinationIndexPath = nil
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let tableView = viewController.tableView

        let location = gestureRecognizer.location(in: tableView)
        if let indexPath = tableView.indexPathForRow(at: location),
            let cell = castCell(cell: tableView.cellForRow(at: indexPath)) {
            return !cell.item.completed
        }
        return gestureRecognizer is UITapGestureRecognizer
    }

    // MARK: Colors

    private let colors: [UIColor]

    func color(forRow row: Int) -> UIColor {
        let fraction = Double(row) / Double(max(13, items.count))
        return colors.gradientColor(atFraction: fraction)
    }

    func updateColors(completion: (() -> Void)? = nil) {
        let tableView = viewController.tableView

        let visibleCellsAndColors = tableView.visibleCells.map { cell in
            return (cell, color(forRow: tableView.indexPath(for: cell)!.row))
        }

        UIView.animate(withDuration: 0.5, animations: {
            for (cell, color) in visibleCellsAndColors {
                cell.contentView.backgroundColor = color
            }
        }, completion: { _ in
            completion?()
        })
    }

    // MARK: Placeholder cell

    // Placeholder cell to use before being adding to the table view
    private let placeHolderCell = TableViewCell<Parent.Item>(style: .default, reuseIdentifier: "cell")

    func setupPlaceholderCell(in tableView: UITableView) {
        placeHolderCell.alpha = 0
        placeHolderCell.backgroundView!.backgroundColor = color(forRow: 0)
        placeHolderCell.layer.anchorPoint = CGPoint(x: 0.5, y: 1)
        tableView.addSubview(placeHolderCell)

        constrain(placeHolderCell) { placeHolderCell in
            placeHolderCell.bottom == placeHolderCell.superview!.top + tableView.rowHeight / 2
            placeHolderCell.left == placeHolderCell.superview!.superview!.left
            placeHolderCell.right == placeHolderCell.superview!.superview!.right
        }
        constrain(placeHolderCell.contentView, placeHolderCell) { contentView, placeHolderCell in
            contentView.edges == placeHolderCell.edges
            contentView.height == tableView.rowHeight
        }
    }

    func adjustPlaceholder(state: PlaceholderState) {
        switch state {
        case .pullToCreate(let distancePulledDown):
            UIView.animate(withDuration: 0.1) { [unowned self] in
                self.placeHolderCell.navHintView.alpha = 0
            }
            placeHolderCell.textView.text = "Pull to Create Item"

            let cellHeight = viewController.tableView.rowHeight
            let angle = CGFloat(Double.pi / 2.0) - tan(distancePulledDown / cellHeight)

            var transform = CATransform3DIdentity
            transform.m34 = CGFloat(1.0 / -(1000 * 0.3))
            transform = CATransform3DRotate(transform, angle, 1, 0, 0)
            placeHolderCell.layer.transform = transform

        case .releaseToCreate:
            UIView.animate(withDuration: 0.1) { [unowned self] in
                self.placeHolderCell.navHintView.alpha = 0
            }
            placeHolderCell.layer.transform = CATransform3DIdentity
            placeHolderCell.textView.text = "Release to Create Item"
        case .switchToLists:
            placeHolderCell.navHintView.hintText = "Switch to Lists"
            placeHolderCell.navHintView.hintArrowTransfom = CGAffineTransform.identity.rotated(by: .pi)

            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0.5,
                options: [], animations: { [unowned self] in

                self.placeHolderCell.navHintView.alpha = 1
                self.placeHolderCell.navHintView.hintArrowTransfom  = .identity
            }, completion: nil)

        case .alpha(let alpha):
            placeHolderCell.alpha = alpha
        }
    }
}
