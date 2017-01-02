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

// FIXME: This file should be split up.
// swiftlint:disable file_length

import Cartography
import Cocoa
import RealmSwift

private let taskCellIdentifier = "TaskCell"
private let listCellIdentifier = "ListCell"
private let prototypeCellIdentifier = "PrototypeCell"

// FIXME: This type should be split up.
// swiftlint:disable:next type_body_length
final class ListViewController<ListType: ListPresentable where ListType: Object>: NSViewController,
    NSTableViewDelegate, NSTableViewDataSource, ItemCellViewDelegate, NSGestureRecognizerDelegate {

    typealias ItemType = ListType.Item

    let list: ListType

    private let tableView = NSTableView()

    private var notificationToken: NotificationToken?

    private let prototypeCell = PrototypeCellView(identifier: prototypeCellIdentifier)

    private var currentlyEditingCellView: ItemCellView?

    private var currentlyMovingRowView: NSTableRowView?
    private var currentlyMovingRowSnapshotView: SnapshotView?

    private var autoscrollTimer: NSTimer?

    init(list: ListType) {
        self.list = list

        super.init(nibName: nil, bundle: nil)!
    }

    deinit {
        notificationToken?.stop()
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        tableView.addTableColumn(NSTableColumn())
        tableView.backgroundColor = .clearColor()
        tableView.headerView = nil
        tableView.selectionHighlightStyle = .None
        tableView.intercellSpacing = .zero

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.drawsBackground = false

        view.addSubview(scrollView)

        constrain(scrollView) { scrollView in
            scrollView.edges == scrollView.superview!.edges
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let notificationCenter = NSNotificationCenter.defaultCenter()

        // Handle window resizing to update table view rows height
        notificationCenter.addObserver(self, selector: #selector(windowDidResize), name: NSWindowDidResizeNotification, object: view.window)
        notificationCenter.addObserver(self, selector: #selector(windowDidResize), name: NSWindowDidEnterFullScreenNotification, object: view.window)
        notificationCenter.addObserver(self, selector: #selector(windowDidResize), name: NSWindowDidExitFullScreenNotification, object: view.window)

        setupNotifications()
        setupGestureRecognizers()

        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupNotifications() {
        notificationToken = list.items.addNotificationBlock { [unowned self] changes in
            switch changes {
                case .Initial:
                    self.tableView.reloadData()
                case .Update(_, let deletions, let insertions, let modifications):
                    self.tableView.beginUpdates()
                    self.tableView.removeRowsAtIndexes(deletions.toIndexSet(), withAnimation: .EffectGap)
                    self.tableView.insertRowsAtIndexes(insertions.toIndexSet(), withAnimation: .EffectGap)
                    self.tableView.reloadDataForRowIndexes(modifications.toIndexSet(), columnIndexes: NSIndexSet(index: 0))
                    self.tableView.endUpdates()
                case .Error(let error):
                    fatalError(String(error))
            }
        }
    }

    private func setupGestureRecognizers() {
        let pressGestureRecognizer = NSPressGestureRecognizer(target: self, action: #selector(handlePressGestureRecognizer))
        pressGestureRecognizer.minimumPressDuration = 0.2

        let panGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePanGestureRecognizer))

        for recognizer in [pressGestureRecognizer, panGestureRecognizer] {
            recognizer.delegate = self
            tableView.addGestureRecognizer(recognizer)
        }
    }

    private dynamic func windowDidResize(notification: NSNotification) {
        updateTableViewHeightOfRows()
    }

    private func updateTableViewHeightOfRows(indexes: NSIndexSet? = nil) {
        // noteHeightOfRows animates by default, disable this
        NSView.animate(duration: 0) {
            tableView.noteHeightOfRowsWithIndexesChanged(indexes ?? NSIndexSet(indexesInRange: NSRange(0...tableView.numberOfRows)))
        }
    }

    // MARK: UI Writes

    private func beginUIWrite() {
        list.realm?.beginWrite()
    }

    private func commitUIWrite() {
        try! list.realm?.commitWrite(withoutNotifying: [notificationToken!])
    }

    func uiWrite(@noescape block: () -> Void) {
        beginUIWrite()
        block()
        commitUIWrite()
    }

    // MARK: Actions

    @IBAction func newItem(sender: AnyObject?) {
        endEditingCells()

        uiWrite {
            list.items.insert(ItemType(), atIndex: 0)
        }

        NSView.animate(animations: {
            NSAnimationContext.currentContext().allowsImplicitAnimation = false // prevents NSTableView autolayout issues
            tableView.insertRowsAtIndexes(NSIndexSet(index: 0), withAnimation: .EffectGap)
        }) {
            if let newItemCellView = self.tableView.viewAtColumn(0, row: 0, makeIfNecessary: false) as? ItemCellView {
                self.beginEditingCell(newItemCellView)
                self.tableView.selectRowIndexes(NSIndexSet(index: 0), byExtendingSelection: false)
            }
        }
    }

    override func validateToolbarItem(toolbarItem: NSToolbarItem) -> Bool {
        return validateSelector(toolbarItem.action)
    }

    override func validateMenuItem(menuItem: NSMenuItem) -> Bool {
        return validateSelector(menuItem.action)
    }

    private func validateSelector(selector: Selector) -> Bool {
        switch selector {
        case #selector(newItem):
            return !editing || currentlyEditingCellView?.text.isEmpty == false
        default:
            return true
        }
    }

    // MARK: Reordering

    var reordering: Bool {
        return currentlyMovingRowView != nil
    }

    private func beginReorderingRow(row: Int, screenPoint point: NSPoint) {
        currentlyMovingRowView = tableView.rowViewAtRow(row, makeIfNecessary: false)

        if currentlyMovingRowView == nil {
            return
        }

        tableView.enumerateAvailableRowViewsUsingBlock { _, row in
            if let view = tableView.viewAtColumn(0, row: row, makeIfNecessary: false) as? ItemCellView {
                view.isUserInteractionEnabled = false
            }
        }

        currentlyMovingRowSnapshotView = SnapshotView(sourceView: currentlyMovingRowView!)
        currentlyMovingRowView!.alphaValue = 0

        currentlyMovingRowSnapshotView?.frame.origin.y = view.convertPoint(point, fromView: nil).y - currentlyMovingRowSnapshotView!.frame.height / 2
        view.addSubview(currentlyMovingRowSnapshotView!)

        NSView.animate {
            let frame = currentlyMovingRowSnapshotView!.frame
            currentlyMovingRowSnapshotView!.frame = frame.insetBy(dx: -frame.width * 0.02, dy: -frame.height * 0.02)
        }

        beginUIWrite()
    }

    private func handleReorderingForScreenPoint(point: NSPoint) {
        guard reordering else {
            return
        }

        if let snapshotView = currentlyMovingRowSnapshotView {
            snapshotView.frame.origin.y = snapshotView.superview!.convertPoint(point, fromView: nil).y - snapshotView.frame.height / 2
        }

        let sourceRow = tableView.rowForView(currentlyMovingRowView!)
        let destinationRow: Int

        let pointInTableView = tableView.convertPoint(point, fromView: nil)

        if pointInTableView.y < tableView.bounds.minY {
            destinationRow = 0
        } else if pointInTableView.y > tableView.bounds.maxY {
            destinationRow = tableView.numberOfRows - 1
        } else {
            destinationRow = tableView.rowAtPoint(pointInTableView)
        }

        if canMoveRow(sourceRow, toRow: destinationRow) {
            list.items.move(from: sourceRow, to: destinationRow)

            NSView.animate {
                // Disable implicit animations because tableView animates reordering via animator proxy
                NSAnimationContext.currentContext().allowsImplicitAnimation = false
                tableView.moveRowAtIndex(sourceRow, toIndex: destinationRow)
            }
        }
    }

    private func canMoveRow(sourceRow: Int, toRow destinationRow: Int) -> Bool {
        guard destinationRow >= 0 && destinationRow != sourceRow else {
            return false
        }

        return !list.items[destinationRow].completed
    }

    private func endReordering() {
        guard reordering else {
            return
        }

        NSView.animate(animations: {
            currentlyMovingRowSnapshotView?.frame = view.convertRect(currentlyMovingRowView!.frame, fromView: tableView)
        }) {
            self.currentlyMovingRowView?.alphaValue = 1
            self.currentlyMovingRowView = nil

            self.currentlyMovingRowSnapshotView?.removeFromSuperview()
            self.currentlyMovingRowSnapshotView = nil

            self.tableView.enumerateAvailableRowViewsUsingBlock { _, row in
                if let view = self.tableView.viewAtColumn(0, row: row, makeIfNecessary: false) as? ItemCellView {
                    view.isUserInteractionEnabled = true
                }
            }

            self.updateColors()
        }

        commitUIWrite()
    }

    private dynamic func handlePressGestureRecognizer(recognizer: NSPressGestureRecognizer) {
        switch recognizer.state {
        case .Began:
            beginReorderingRow(tableView.rowAtPoint(recognizer.locationInView(tableView)), screenPoint: recognizer.locationInView(nil))
        case .Ended, .Cancelled:
            endReordering()
        default:
            break
        }
    }

    private dynamic func handlePanGestureRecognizer(recognizer: NSPressGestureRecognizer) {
        switch recognizer.state {
        case .Began:
            startAutoscrolling()
        case .Changed:
            handleReorderingForScreenPoint(recognizer.locationInView(nil))
        case .Ended:
            stopAutoscrolling()
        default:
            break
        }
    }

    private func startAutoscrolling() {
        guard autoscrollTimer == nil else {
            return
        }

        autoscrollTimer = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: #selector(handleAutoscrolling), userInfo: nil, repeats: true)
    }

    private dynamic func handleAutoscrolling() {
        if let event = NSApp.currentEvent {
            if tableView.autoscroll(event) {
                handleReorderingForScreenPoint(event.locationInWindow)
            }
        }
    }

    private func stopAutoscrolling() {
        autoscrollTimer?.invalidate()
        autoscrollTimer = nil
    }

    // MARK: Editing

    var editing: Bool {
        return currentlyEditingCellView != nil
    }

    private func beginEditingCell(cellView: ItemCellView) {
        NSView.animate(animations: {
            tableView.scrollRowToVisible(tableView.rowForView(cellView))

            tableView.enumerateAvailableRowViewsUsingBlock { _, row in
                if let view = tableView.viewAtColumn(0, row: row, makeIfNecessary: false) as? ItemCellView where view != cellView {
                    view.alphaValue = 0.3
                    view.isUserInteractionEnabled = false
                }
            }
        }) {
            self.view.window?.update()
        }

        cellView.editable = true
        view.window?.makeFirstResponder(cellView.textView)

        currentlyEditingCellView = cellView

        beginUIWrite()
    }

    private func endEditingCells() {
        guard
            let cellView = currentlyEditingCellView,
            let (_, index) = findItemForCellView(cellView)
        else {
            return
        }

        var item = list.items[index]

        if cellView.text.isEmpty {
            item.realm!.delete(item)
            tableView.removeRowsAtIndexes(NSIndexSet(index: index), withAnimation: .SlideUp)
        } else if cellView.text != item.text {
            item.text = cellView.text
        }

        currentlyEditingCellView = nil

        view.window?.makeFirstResponder(self)
        view.window?.update()

        commitUIWrite()

        NSView.animate(animations: {
            tableView.enumerateAvailableRowViewsUsingBlock { _, row in
                if let view = tableView.viewAtColumn(0, row: row, makeIfNecessary: false) as? ItemCellView {
                    view.alphaValue = 1
                }
            }
        }) {
            self.tableView.enumerateAvailableRowViewsUsingBlock { _, row in
                if let view = self.tableView.viewAtColumn(0, row: row, makeIfNecessary: false) as? ItemCellView {
                    view.isUserInteractionEnabled = true
                }
            }
        }
    }

    // MARK: NSGestureRecognizerDelegate

    func gestureRecognizer(gestureRecognizer: NSGestureRecognizer,
                           shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        return gestureRecognizer is NSPanGestureRecognizer
    }

    func gestureRecognizerShouldBegin(gestureRecognizer: NSGestureRecognizer) -> Bool {
        guard !editing else {
            return false
        }

        switch gestureRecognizer {
        case is NSPressGestureRecognizer:
            let targetRow = tableView.rowAtPoint(gestureRecognizer.locationInView(tableView))

            guard targetRow >= 0 else {
                return false
            }

            return !list.items[targetRow].completed
        case is NSPanGestureRecognizer:
            return reordering
        default:
            return true
        }
    }

    // MARK: NSTableViewDataSource

    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return list.items.count
    }

    // MARK: NSTableViewDelegate

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = list.items[row]

        let cellViewIdentifier: String
        let cellViewType: ItemCellView.Type
        let cellView: ItemCellView

        switch item {
        case is TaskList:
            cellViewIdentifier = listCellIdentifier
            cellViewType = ListCellView.self
        case is Task:
            cellViewIdentifier = taskCellIdentifier
            cellViewType = TaskCellView.self
        default:
            fatalError("Unknown item type")
        }

        if let view = tableView.makeViewWithIdentifier(cellViewIdentifier, owner: self) as? ItemCellView {
            cellView = view
        } else {
            cellView = cellViewType.init(identifier: listCellIdentifier)
        }

        cellView.configure(item)
        cellView.backgroundColor = colorForRow(row)
        cellView.delegate = self

        return cellView
    }

    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if let cellView = currentlyEditingCellView {
            prototypeCell.configure(cellView)
        } else {
            prototypeCell.configure(list.items[row])
        }

        return prototypeCell.fittingHeightForConstrainedWidth(tableView.bounds.width)
    }

    func tableViewSelectionDidChange(notification: NSNotification) {
        let index = tableView.selectedRow

        guard 0 <= index && index < list.items.count else {
            endEditingCells()
            return
        }

        guard !list.items[index].completed else {
            endEditingCells()
            return
        }

        guard let cellView = tableView.viewAtColumn(0, row: index, makeIfNecessary: false) as? ItemCellView where cellView != currentlyEditingCellView else {
            return
        }

        guard currentlyEditingCellView == nil else {
            endEditingCells()
            return
        }

        if let listCellView = cellView as? ListCellView where !listCellView.acceptsEditing, let list = list.items[index] as? TaskList {
            (parentViewController as? ContainerViewController)?.presentViewControllerForList(list)
        } else if cellView.isUserInteractionEnabled {
            beginEditingCell(cellView)
        }
    }

    func tableView(tableView: NSTableView, didAddRowView rowView: NSTableRowView, forRow row: Int) {
        updateColors()
    }

    func tableView(tableView: NSTableView, didRemoveRowView rowView: NSTableRowView, forRow row: Int) {
        updateColors()
    }

    private func updateColors() {
        tableView.enumerateAvailableRowViewsUsingBlock { rowView, row in
            // For some reason tableView.viewAtColumn:row: returns nil while animating, will use view hierarchy instead
            if let cellView = rowView.subviews.first as? ItemCellView {
                NSView.animate {
                    cellView.backgroundColor = colorForRow(row)
                }
            }
        }
    }

    private func colorForRow(row: Int) -> NSColor {
        let colors = ItemType.self is Task.Type ? NSColor.taskColors() : NSColor.listColors()
        let fraction = Double(row) / Double(max(13, list.items.count))

        return colors.gradientColorAtFraction(fraction)
    }

    // MARK: ItemCellViewDelegate

    func cellView(view: ItemCellView, didComplete complete: Bool) {
        guard let itemAndIndex = findItemForCellView(view) else {
            return
        }

        var item = itemAndIndex.0
        let index = itemAndIndex.1
        let destinationIndex: Int

        if complete {
            // move cell to bottom
            destinationIndex = list.items.count - 1
        } else {
            // move cell just above the first completed item
            let completedCount = list.items.filter("completed = true").count
            destinationIndex = list.items.count - completedCount
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
            self.uiWrite {
                item.completed = complete

                if index != destinationIndex {
                    self.list.items.removeAtIndex(index)
                    self.list.items.insert(item, atIndex: destinationIndex)
                }
            }

            NSView.animate(animations: {
                NSAnimationContext.currentContext().allowsImplicitAnimation = false
                self.tableView.moveRowAtIndex(index, toIndex: destinationIndex)
            }) {
                self.updateColors()
            }
        }
    }

    func cellViewDidDelete(view: ItemCellView) {
        guard let (item, index) = findItemForCellView(view) else {
            return
        }

        uiWrite {
            list.realm?.delete(item)
        }

        NSView.animate {
            NSAnimationContext.currentContext().allowsImplicitAnimation = false
            tableView.removeRowsAtIndexes(NSIndexSet(index: index), withAnimation: .SlideLeft)
        }
    }

    func cellViewDidChangeText(view: ItemCellView) {
        if view == currentlyEditingCellView {
            updateTableViewHeightOfRows(NSIndexSet(index: tableView.rowForView(view)))
            view.window?.update()
        }
    }

    func cellViewDidEndEditing(view: ItemCellView) {
        endEditingCells()

        // In case if Return key was pressed we need to reset table view selection
        tableView.deselectAll(nil)
    }

    private func findItemForCellView(view: NSView) -> (item: ItemType, index: Int)? {
        let index = tableView.rowForView(view)

        if index < 0 {
            return nil
        }

        return (list.items[index], index)
    }

}

// MARK: Private Classes

private final class PrototypeCellView: ItemCellView {

    private var widthConstraint: NSLayoutConstraint?

    func configure(cellView: ItemCellView) {
        text = cellView.text
    }

    func fittingHeightForConstrainedWidth(width: CGFloat) -> CGFloat {
        if let widthConstraint = widthConstraint {
            widthConstraint.constant = width
        } else {
            widthConstraint = NSLayoutConstraint(item: self, attribute: .Width, relatedBy: .Equal, toItem: nil,
                                                 attribute: .NotAnAttribute, multiplier: 1, constant: width)
            addConstraint(widthConstraint!)
        }

        layoutSubtreeIfNeeded()

        // NSTextField's content size must be recalculated after cell size is changed
        textView.invalidateIntrinsicContentSize()
        layoutSubtreeIfNeeded()

        return fittingSize.height
    }

}

private final class SnapshotView: NSView {

    init(sourceView: NSView) {
        super.init(frame: sourceView.frame)

        let imageRepresentation = sourceView.bitmapImageRepForCachingDisplayInRect(sourceView.bounds)!
        sourceView.cacheDisplayInRect(sourceView.bounds, toBitmapImageRep: imageRepresentation)

        let snapshotImage = NSImage(size: sourceView.bounds.size)
        snapshotImage.addRepresentation(imageRepresentation)

        wantsLayer = true
        shadow = NSShadow() // Workaround to activate layer-backed shadow

        layer?.contents = snapshotImage
        layer?.shadowColor = NSColor.blackColor().CGColor
        layer?.shadowOpacity = 1
        layer?.shadowRadius = 5
        layer?.shadowOffset = CGSize(width: -5, height: 0)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

// MARK: Private Extensions

private extension CollectionType where Generator.Element == Int {

    func toIndexSet() -> NSIndexSet {
        return reduce(NSMutableIndexSet()) { $0.addIndex($1); return $0 }
    }

}
