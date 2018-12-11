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

import Foundation
import RealmSwift
import UIKit

internal let editingCellAlpha: CGFloat = 0.3

class CellPresenter<Item: Object> where Item: CellPresentable {

    var viewController: ViewControllerProtocol!

    let items: List<Item>
    init(items: List<Item>) {
        self.items = items
    }

    func delete(item: Item) {
        viewController.uiWrite {
            guard !item.isInvalidated, let index = items.index(of: item) else {
                return
            }

            items.realm?.delete(item)
            viewController.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .left)
        }
    }

    func complete(item: Item) {
        viewController.uiWrite {
            guard !item.isInvalidated, let index = items.index(of: item) else {
                return
            }

            let sourceIndexPath = IndexPath(row: index, section: 0)
            let destinationIndexPath: IndexPath
            if item.completed {
                // move cell to bottom
                destinationIndexPath = IndexPath(row: items.count - 1, section: 0)
            } else {
                // move cell just above the first completed item
                let completedCount = items.filter("completed = true").count
                destinationIndexPath = IndexPath(row: items.count - completedCount - 1, section: 0)
            }

            items.move(from: sourceIndexPath.row, to: destinationIndexPath.row)
            viewController.tableView.moveRow(at: sourceIndexPath, to: destinationIndexPath)
        }
    }

    // MARK: Editing

    var currentlyEditing: Bool { return currentlyEditingCell != nil }

    private(set) var currentlyEditingCell: TableViewCell<Item>? {
        didSet {
            viewController.tableView.isScrollEnabled = !currentlyEditing
        }
    }
    private(set) var currentlyEditingIndexPath: IndexPath?

    func cellDidBeginEditing(_ editingCell: TableViewCell<Item>) {
        items.realm?.beginWrite()
        currentlyEditingCell = editingCell
        let tableView = viewController.tableView

        currentlyEditingIndexPath = tableView.indexPath(for: editingCell)

        viewController.setPlaceholderAlpha(to: 0)
        tableView.bounces = false

        UIView.animate(withDuration: 0.3, animations: {
            tableView.superview?.layoutSubviews()
            for cell in tableView.visibleCells where cell !== editingCell {
                cell.alpha = editingCellAlpha
            }
        }, completion: { _ in
            tableView.bounces = true
        })
    }

    func cellDidEndEditing(_ editingCell: TableViewCell<Item>) {
        currentlyEditingCell = nil
        currentlyEditingIndexPath = nil
        let tableView = viewController.tableView

        UIView.animate(withDuration: 0.3) {
            for cell in tableView.visibleCells where cell !== editingCell {
                cell.alpha = 1
            }
            tableView.superview?.layoutSubviews()
        }

        let item = editingCell.item
        if item!.text.isEmpty {
            let indexPath = IndexPath(row: items.index(of: item!)!, section: 0)
            item?.realm!.delete(item!)
            viewController.tableView.deleteRows(at: [indexPath], with: .top)
        }
        viewController.finishUIWrite()
    }

    func cellDidChangeText(_ editingCell: TableViewCell<Item>) {
        // If the height of the text view has extended to the next line,
        // reload the height of the cell
        let height = cellHeight(forText: editingCell.textView.text)
        let tableView = viewController.tableView

        if Int(height) != Int(editingCell.frame.size.height) {
            UIView.performWithoutAnimation {
                tableView.beginUpdates()
                tableView.endUpdates()
            }

            for cell in tableView.visibleCells where cell !== editingCell {
                cell.alpha = editingCellAlpha
            }
        }
    }

    func cellHeight(forText text: String, timeHidden: Bool = true) -> CGFloat {
        guard let view = viewController.tableView.superview else {
            return 0
        }

        let dateHeight = timeHidden ? 0 : 17

        return text.boundingRect(with: CGSize(width: view.bounds.size.width - 25, height: view.bounds.size.height),
                                 options: [.usesLineFragmentOrigin],
                                 attributes: [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 18)],
                                 context: nil).height + 33 + CGFloat(dateHeight)
    }
}
