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

protocol ItemCellViewDelegate: class {

    func cellView(view: ItemCellView, didComplete complete: Bool)
    func cellViewDidDelete(view: ItemCellView)

    func cellViewDidChangeText(view: ItemCellView)
    func cellViewDidEndEditing(view: ItemCellView)

}

private let iconWidth: CGFloat = 40
private let iconOffset = iconWidth / 2
private let swipeThreshold = iconWidth * 2

class ItemCellView: NSTableCellView {

    weak var delegate: ItemCellViewDelegate?

    var text: String {
        set {
            textView.stringValue = newValue
        }

        get {
            return textView.stringValue
        }
    }

    var completed = false {
        didSet {
            completed ? textView.strike() : textView.unstrike()
            overlayView.hidden = !completed
            overlayView.backgroundColor = completed ? .completeDimBackgroundColor() : .completeGreenBackgroundColor()
            textView.alphaValue = completed ? 0.3 : 1
        }
    }

    var editable: Bool {
        set {
            textView.editable = newValue
        }

        get {
            return textView.editable
        }
    }

    var isUserInteractionEnabled = true {
        didSet {
            highlightView.hidden = true
            updateTrackingAreas()
        }
    }

    var backgroundColor: NSColor {
        set {
            contentView.backgroundColor = newValue
        }

        get {
            return contentView.backgroundColor
        }
    }

    let contentView = ColorView()

    let textView: NSTextField = ItemTextField()
    let textViewConstraintGroup = ConstraintGroup()

    private let highlightView = HighlightView()
    private let overlayView = ColorView()

    private let doneIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(named: "DoneIcon")
        return imageView
    }()

    private let deleteIconView: NSImageView = {
        let imageView = NSImageView()
        imageView.image = NSImage(named: "DeleteIcon")
        return imageView
    }()

    private var releaseAction: ReleaseAction?

    required init(identifier: String) {
        super.init(frame: .zero)
        self.identifier = identifier

        setupUI()
        setupGestures()

        setTrackingAreaWithRect(bounds, options: [.MouseEnteredAndExited, .ActiveInKeyWindow])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: CellPresentable) {
        text = item.text
        completed = item.completed
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        alphaValue = 1
        contentView.frame.origin.x = 0
        editable = false
        highlightView.hidden = true
        isUserInteractionEnabled = true
    }

    override func updateTrackingAreas() {
        if isUserInteractionEnabled {
            setTrackingAreaWithRect(bounds, options: [.MouseEnteredAndExited, .ActiveInKeyWindow])
        } else {
            resetTrackingAreas()
        }
    }

    private func setupUI() {
        setupIconViews()
        setupContentView()
        setupBorders()
        setupHighlightView()
        setupOverlayView()
        setupTextView()
    }

    private func setupIconViews() {
        doneIconView.frame.size.width = iconWidth
        doneIconView.frame.origin.x = iconOffset
        doneIconView.autoresizingMask = [.ViewMaxXMargin, .ViewHeightSizable]
        addSubview(doneIconView, positioned: .Below, relativeTo: contentView)

        deleteIconView.frame.size.width = iconWidth
        deleteIconView.frame.origin.x = bounds.width - deleteIconView.bounds.width - iconOffset
        deleteIconView.autoresizingMask = [.ViewMinXMargin, .ViewHeightSizable]
        addSubview(deleteIconView, positioned: .Below, relativeTo: contentView)
    }

    private func setupContentView() {
        addSubview(contentView)

        contentView.frame = bounds
        contentView.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
    }

    private func setupHighlightView() {
        addSubview(highlightView)

        constrain(highlightView) { highlightView in
            highlightView.edges == highlightView.superview!.edges
        }

        highlightView.hidden = true
    }

    private func setupBorders() {
        let highlightLine = ColorView(backgroundColor: NSColor(white: 1, alpha: 0.05))
        let shadowLine = ColorView(backgroundColor: NSColor(white: 0, alpha: 0.05))

        contentView.addSubview(highlightLine)
        contentView.addSubview(shadowLine)

        constrain(highlightLine, shadowLine) { highlightLine, shadowLine in
            highlightLine.top == highlightLine.superview!.top
            highlightLine.left == highlightLine.superview!.left
            highlightLine.right == highlightLine.superview!.right
            highlightLine.height == 1

            shadowLine.bottom == shadowLine.superview!.bottom
            shadowLine.left == shadowLine.superview!.left
            shadowLine.right == shadowLine.superview!.right
            shadowLine.height == 1
        }
    }

    private func setupOverlayView() {
        contentView.addSubview(overlayView)

        constrain(overlayView) { overlayView in
            overlayView.edges == overlayView.superview!.edges
        }
    }

    private func setupTextView() {
        textView.delegate = self

        contentView.addSubview(textView)

        constrain(textView, replace: textViewConstraintGroup) { textView in
            textView.edges == inset(textView.superview!.edges, 13, 11)
        }
    }

    private func setupGestures() {
        let recognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePan))
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    override func mouseEntered(theEvent: NSEvent) {
        super.mouseEntered(theEvent)

        guard !completed && !editable else {
            return
        }

        NSView.animate(duration: 0.1) {
            highlightView.hidden = false
        }
    }

    override func mouseExited(theEvent: NSEvent) {
        super.mouseExited(theEvent)

        guard !completed && !editable else {
            return
        }

        NSView.animate(duration: 0.1) {
            highlightView.hidden = true
        }
    }

}

// MARK: ItemTextFieldDelegate

extension ItemCellView: ItemTextFieldDelegate {

    func textFieldDidBecomeFirstResponder(textField: NSTextField) {
        highlightView.hidden = true
    }

    override func controlTextDidChange(obj: NSNotification) {
        delegate?.cellViewDidChangeText(self)
    }

    override func controlTextDidEndEditing(obj: NSNotification) {
        if editable {
            editable = false
            delegate?.cellViewDidEndEditing(self)
        }
    }

    // Called when esc key was pressesed
    override func cancelOperation(sender: AnyObject?) {
        textView.abortEditing()

        if editable {
            editable = false
            delegate?.cellViewDidEndEditing(self)
        }
    }

}

// MARK: NSGestureRecognizerDelegate

extension ItemCellView: NSGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(gestureRecognizer: NSGestureRecognizer) -> Bool {
        let currentlyEditingTextField = (window?.firstResponder as? NSText)?.delegate as? NSTextField

        guard currentlyEditingTextField != textView else {
            return false
        }

        return isUserInteractionEnabled
    }

    // FIXME: This could easily be refactored to avoid such a high CC.
    // swiftlint:disable:next cyclomatic_complexity
    private dynamic func handlePan(recognizer: NSPanGestureRecognizer) {
        let originalDoneIconOffset = iconOffset
        let originalDeleteIconOffset = bounds.width - deleteIconView.bounds.width - iconOffset

        switch recognizer.state {
        case .Began:
            isUserInteractionEnabled = false
            releaseAction = nil
        case .Changed:
            let translation = recognizer.translationInView(self)
            recognizer.setTranslation(translation, inView: self)

            contentView.frame.origin.x = translation.x

            if abs(translation.x) > swipeThreshold {
                doneIconView.frame.origin.x = originalDoneIconOffset + translation.x - swipeThreshold
                deleteIconView.frame.origin.x = originalDeleteIconOffset + translation.x + swipeThreshold
            } else {
                doneIconView.frame.origin.x = originalDoneIconOffset
                deleteIconView.frame.origin.x = originalDeleteIconOffset
            }

            let fractionOfThreshold = min(1, Double(abs(translation.x) / swipeThreshold))

            doneIconView.alphaValue = CGFloat(fractionOfThreshold)
            deleteIconView.alphaValue = CGFloat(fractionOfThreshold)

            releaseAction = fractionOfThreshold == 1 ? (translation.x > 0 ? .Complete : .Delete) : nil

            if completed {
                overlayView.hidden = releaseAction == .Complete
                textView.alphaValue = releaseAction == .Complete ? 1 : 0.3

                if contentView.frame.origin.x > 0 {
                    textView.strike(1 - fractionOfThreshold)
                }
            } else {
                overlayView.backgroundColor = .completeGreenBackgroundColor()
                overlayView.hidden = releaseAction != .Complete

                if contentView.frame.origin.x > 0 {
                    textView.strike(fractionOfThreshold)
                }
            }
        case .Ended:
            let animationBlock: () -> Void
            let completionBlock: () -> Void

            // If not deleting, slide it back into the middle
            // If we are deleting, slide it all the way out of the view
            switch releaseAction {
            case .Complete?:
                animationBlock = {
                    self.contentView.frame.origin.x = 0
                }

                completionBlock = {
                    NSView.animate(animations: {
                        self.completed = !self.completed
                    }) {
                        self.delegate?.cellView(self, didComplete: self.completed)
                    }
                }
            case .Delete?:
                animationBlock = {
                    self.alphaValue = 0

                    self.contentView.frame.origin.x = -self.contentView.bounds.width - swipeThreshold
                    self.deleteIconView.frame.origin.x = -swipeThreshold + self.deleteIconView.bounds.width + iconOffset
                }

                completionBlock = {
                    self.delegate?.cellViewDidDelete(self)
                }
            case nil:
                completed ? textView.strike() : textView.unstrike()

                animationBlock = {
                    self.contentView.frame.origin.x = 0
                }

                completionBlock = {}
            }

            NSView.animate(animations: animationBlock) {
                completionBlock()

                self.doneIconView.frame.origin.x = originalDoneIconOffset
                self.deleteIconView.frame.origin.x = originalDeleteIconOffset

                self.isUserInteractionEnabled = true
            }
        default:
            break
        }
    }

}

// MARK: Private Classes

private enum ReleaseAction {
    case Complete, Delete
}

private class HighlightView: NSView {

    private override func drawRect(dirtyRect: NSRect) {
        let shadowColor = NSColor(white: 0, alpha: 0.2)
        let backgroundColor = NSColor(white: 0, alpha: 0.05)

        let gradient = NSGradient(colorsAndLocations: (shadowColor, 0), (backgroundColor, 0.08), (backgroundColor, 0.92), (shadowColor, 1))
        gradient?.drawInRect(bounds, angle: 90)
    }

}

protocol ItemTextFieldDelegate: NSTextFieldDelegate {

    func textFieldDidBecomeFirstResponder(textField: NSTextField)

}

private class ItemTextField: NSTextField {

    override class func cellClass() -> AnyClass? {
        return ItemTextFieldCell.self
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        bordered = false
        focusRingType = .None
        font = .systemFontOfSize(18)
        textColor = .whiteColor()
        backgroundColor = .clearColor()
        lineBreakMode = .ByWordWrapping
        selectable = false
        editable = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private override func becomeFirstResponder() -> Bool {
        (delegate as? ItemTextFieldDelegate)?.textFieldDidBecomeFirstResponder(self)

        let result = super.becomeFirstResponder()

        currentEditor()?.selectedRange = NSRange(location: stringValue.characters.count, length: 0)

        return result
    }

    override var intrinsicContentSize: NSSize {
        // By default editable NSTextField doesn't respect wrapping while calculating intrinsic content size,
        // let's calculate the correct one by ourselves
        let placeholderFrame = NSRect(origin: .zero, size: NSSize(width: frame.width, height: .max))
        let calculatedHeight = cell!.cellSizeForBounds(placeholderFrame).height

        return NSSize(width: frame.width, height: calculatedHeight)
    }

    override func textDidChange(notification: NSNotification) {
        super.textDidChange(notification)

        // Update height on text change
        invalidateIntrinsicContentSize()
    }

}

private class ItemTextFieldCell: NSTextFieldCell {

    private var cachedStringValue = ""

    override var stringValue: String {
        set {
            cachedStringValue = newValue
            super.stringValue = newValue
        }

        get {
            // By default `NSTextCell` in some reason calls setter from `stringValue` getter that
            // in some cases fires some Accessibility API notification that couses
            // `[NSTableView viewAtColumn:row:makeIfNecessary:]` be called. This leads to a crash
            // if `stringValue` was requested from table view `heightOfRow` delegate method,
            // see more at https://github.com/realm/RealmTasks/issues/344
            return cachedStringValue
        }
    }

}
