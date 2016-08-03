/*************************************************************************
 *
 * REALM CONFIDENTIAL
 * __________________
 *
 *  [2016] Realm Inc
 *  All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of Realm Incorporated and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Realm Incorporated
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Realm Incorporated.
 *
 **************************************************************************/

import AudioToolbox
import Cartography
import UIKit

// MARK: Shared Functions

func vibrate() {
    if isDevice {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

// MARK: Private Declarations

private enum ReleaseAction {
    case Complete, Delete
}

private let isDevice = TARGET_OS_SIMULATOR == 0

// MARK: Table View Cell

final class TableViewCell<Item: CellPresentable>: UITableViewCell, UITextViewDelegate {

    // MARK: Properties

    // Stored Properties
    let textView = ToDoItemTextView()
    var temporarilyIgnoreSaveChanges = false
    var item: Item! {
        didSet {
            textView.text = item.cellText
            setCompleted(item.completed)
        }
    }

    // Callbacks
    var itemCompleted: ((Item) -> ())? = nil
    var itemDeleted: ((Item) -> ())? = nil
    var cellDidBeginEditing: ((TableViewCell) -> ())? = nil
    var cellDidEndEditing: ((TableViewCell) -> ())? = nil
    var cellDidChangeText: ((TableViewCell) -> ())? = nil

    // Private Properties
    private var originalDoneIconCenter = CGPoint()
    private var originalDeleteIconCenter = CGPoint()

    private var releaseAction: ReleaseAction?
    private let overlayView = UIView()

    // Assets
    private let doneIconView = UIImageView(image: UIImage(named: "DoneIcon"))
    private let deleteIconView = UIImageView(image: UIImage(named: "DeleteIcon"))

    // MARK: Initializers

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .None

        setupUI()
        setupPanGestureRecognizer()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UI

    private func setupUI() {
        setupBackgroundView()
        setupIconViews()
        setupOverlayView()
        setupTextView()
        setupBorders()
    }

    private func setupBackgroundView() {
        backgroundColor = .clearColor()

        backgroundView = UIView()
        constrain(backgroundView!) { backgroundView in
            backgroundView.edges == backgroundView.superview!.edges
        }
    }

    private func setupIconViews() {
        doneIconView.center = center
        doneIconView.frame.origin.x = 20
        doneIconView.alpha = 0
        doneIconView.autoresizingMask = [.FlexibleRightMargin, .FlexibleTopMargin, .FlexibleBottomMargin]
        insertSubview(doneIconView, belowSubview: contentView)

        deleteIconView.center = center
        deleteIconView.frame.origin.x = bounds.width - deleteIconView.bounds.width - 20
        deleteIconView.alpha = 0
        deleteIconView.autoresizingMask = [.FlexibleLeftMargin, .FlexibleTopMargin, .FlexibleBottomMargin]
        insertSubview(deleteIconView, belowSubview: contentView)
    }

    private func setupOverlayView() {
        overlayView.backgroundColor = .completeDimBackgroundColor()
        overlayView.hidden = true
        contentView.addSubview(overlayView)
        constrain(overlayView) { backgroundOverlayView in
            backgroundOverlayView.edges == backgroundOverlayView.superview!.edges
        }
    }

    private func setupTextView() {
        textView.delegate = self
        contentView.addSubview(textView)
        constrain(textView) { textView in
            textView.left == textView.superview!.left + 8
            textView.top == textView.superview!.top + 8
            textView.bottom == textView.superview!.bottom - 8
            textView.right == textView.superview!.right - 8
        }
    }

    private func setupBorders() {
        let singlePixelInPoints = 1 / UIScreen.mainScreen().scale

        let highlightLine = UIView()
        highlightLine.backgroundColor = UIColor(white: 1, alpha: 0.05)
        addSubview(highlightLine)
        constrain(highlightLine) { highlightLine in
            highlightLine.top == highlightLine.superview!.top
            highlightLine.left == highlightLine.superview!.left
            highlightLine.right == highlightLine.superview!.right
            highlightLine.height == singlePixelInPoints
        }

        let shadowLine = UIView()
        shadowLine.backgroundColor = UIColor(white: 0, alpha: 0.05)
        addSubview(shadowLine)
        constrain(shadowLine) { shadowLine in
            shadowLine.bottom == shadowLine.superview!.bottom
            shadowLine.left == shadowLine.superview!.left
            shadowLine.right == shadowLine.superview!.right
            shadowLine.height == singlePixelInPoints
        }
    }

    // MARK: Pan Gesture Recognizer

    private func setupPanGestureRecognizer() {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    func handlePan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .Began:
            originalDeleteIconCenter = deleteIconView.center
            originalDoneIconCenter = doneIconView.center

            releaseAction = nil
        case .Changed:
            let translation = recognizer.translationInView(self)
            recognizer.setTranslation(translation, inView: self)

            contentView.frame.origin.x = translation.x

            let fractionOfThreshold = min(1, Double(abs(translation.x) / (bounds.size.width / 4)))
            releaseAction = fractionOfThreshold >= 1 ? (translation.x > 0 ? .Complete : .Delete) : nil

            if abs(translation.x) > (frame.size.width / 4) {
                let x = abs(translation.x) - (frame.size.width / 4)
                doneIconView.center = CGPoint(x: originalDoneIconCenter.x + x, y: originalDoneIconCenter.y)
                deleteIconView.center = CGPoint(x: originalDeleteIconCenter.x - x, y: originalDeleteIconCenter.y)
            }

            if translation.x > 0 {
                if item.isCompletable {
                    doneIconView.alpha = CGFloat(fractionOfThreshold)
                }
            } else {
                deleteIconView.alpha = CGFloat(fractionOfThreshold)
            }

            guard item.isCompletable else {
                if releaseAction == .Complete { releaseAction = nil }
                break
            }

            if !item.completed {
                overlayView.backgroundColor = .completeGreenBackgroundColor()
                overlayView.hidden = releaseAction != .Complete
                if contentView.frame.origin.x > 0 {
                    textView.unstrike()
                    textView.strike(fractionOfThreshold)
                } else {
                    releaseAction == .Complete ? textView.strike() : textView.unstrike()
                }
            } else {
                overlayView.hidden = releaseAction == .Complete
                textView.alpha = releaseAction == .Complete ? 1 : 0.3
                if contentView.frame.origin.x > 0 {
                    textView.unstrike()
                    textView.strike(1 - fractionOfThreshold)
                } else {
                    releaseAction == .Complete ? textView.unstrike() : textView.strike()
                }
            }
        case .Ended:
            let animationBlock: () -> ()
            let completionBlock: () -> ()

            // If not deleting, slide it back into the middle
            // If we are deleting, slide it all the way out of the view
            switch releaseAction {
            case .Complete?:
                animationBlock = {
                    self.contentView.frame.origin.x = 0
                }
                completionBlock = {
                    self.setCompleted(!self.item.completed, animated: true)
                }
            case .Delete?:
                animationBlock = {
                    self.alpha = 0
                    self.contentView.alpha = 0

                    self.contentView.frame.origin.x = -self.contentView.bounds.width - (self.bounds.size.width / 4)
                    self.deleteIconView.frame.origin.x = -(self.bounds.size.width / 4) + self.deleteIconView.bounds.width + 20
                }
                completionBlock = {
                    self.itemDeleted?(self.item)
                }
            case nil:
                item.completed ? textView.strike() : textView.unstrike()
                animationBlock = {
                    self.contentView.frame.origin.x = 0
                }
                completionBlock = {}
            }

            UIView.animateWithDuration(0.2, animations: animationBlock) { _ in
                completionBlock()

                self.doneIconView.frame.origin.x = 20
                self.doneIconView.alpha = 0

                self.deleteIconView.frame.origin.x = self.bounds.width - self.deleteIconView.bounds.width - 20
                self.deleteIconView.alpha = 0
            }
        default:
            break
        }
    }

    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer else {
            return false
        }
        let translation = panGestureRecognizer.translationInView(superview!)
        return fabs(translation.x) > fabs(translation.y)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        alpha = 1
        contentView.alpha = 1
        temporarilyIgnoreSaveChanges = false
    }

    // MARK: Actions

    private func setCompleted(completed: Bool, animated: Bool = false) {
        completed ? textView.strike() : textView.unstrike()
        overlayView.hidden = !completed
        let updateColor = { [unowned self] in
            self.overlayView.backgroundColor = completed ?
                .completeDimBackgroundColor() : .completeGreenBackgroundColor()
            self.textView.alpha = completed ? 0.3 : 1
        }
        if animated {
            try! item.realm?.write {
                item.completed = completed
            }
            vibrate()
            UIView.animateWithDuration(0.2, animations: updateColor)
            itemCompleted?(item)
        } else {
            updateColor()
        }
    }

    // MARK: UITextViewDelegate methods

    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    func textViewShouldBeginEditing(textView: UITextView) -> Bool {
        // disable editing of completed to-do items
        return !item.completed
    }

    func textViewDidBeginEditing(textView: UITextView) {
        cellDidBeginEditing?(self)
    }

    func textViewDidEndEditing(textView: UITextView) {
        if !temporarilyIgnoreSaveChanges {
            try! item.realm!.write {
                item.cellText = textView.text
            }
        }
        textView.userInteractionEnabled = false
        cellDidEndEditing?(self)
    }

    func textViewDidChange(textView: UITextView) {
        cellDidChangeText?(self)
    }
}
