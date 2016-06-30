//
//  TableViewCell.swift
//  RealmClear
//
//  Created by JP Simard on 4/11/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import AudioToolbox
import Cartography
import UIKit

// MARK: Shared Functions

func vibrate() {
    if isDevice {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

// MARK: Protocols

protocol TableViewCellDelegate {
    func itemCompleted(item: ToDoItem)
    func itemDeleted(item: ToDoItem)
    func cellDidBeginEditing(editingCell: TableViewCell)
    func cellDidEndEditing(editingCell: TableViewCell)
}

// MARK: Private Declarations

extension UIColor {
    private static func completeDimBackgroundColor() -> UIColor {
        return UIColor(white: 0.2, alpha: 1)
    }

    private static func completeGreenBackgroundColor() -> UIColor {
        return UIColor(red: 0, green: 0.6, blue: 0, alpha: 1)
    }
}

private enum ReleaseAction {
    case Complete, Delete
}

private let isDevice = TARGET_OS_SIMULATOR == 0

// MARK: Table View Cell

final class TableViewCell: UITableViewCell, UITextViewDelegate {

    // Properties
    var deviceIdentifier: String?
    
    var item: ToDoItem! {
        didSet {
            textView.text = item.text
            setCompleted(item.completed)
        }
    }
    var delegate: TableViewCellDelegate?
    let textView = ToDoItemTextView()

    // Private Properties

    private var originalCenter = CGPoint()
    private var originalDoneIconCenter = CGPoint()
    private var originalDeleteIconCenter = CGPoint()
    
    private var releaseAction: ReleaseAction?
    private let backgroundOverlayView = UIView()

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
        setupIconViews()
        setupBackgroundView()
        setupBackgroundOverlayView()
        setupTextView()
        setupBorders()
    }
    
    private func setupBackgroundView() {
        self.backgroundColor = nil
        
        backgroundView = UIView()
        constrain(backgroundView!) { backgroundView in
            backgroundView.edges == backgroundView.superview!.edges
        }
        insertSubview(deleteIconView, atIndex: 0)
        insertSubview(doneIconView, atIndex: 0)
    }

    private func setupBackgroundOverlayView() {
        backgroundOverlayView.backgroundColor = .completeDimBackgroundColor()
        backgroundOverlayView.hidden = true
        addSubview(backgroundOverlayView)
        constrain(backgroundOverlayView) { backgroundOverlayView in
            backgroundOverlayView.edges == backgroundOverlayView.superview!.edges
        }
    }
    
    private func setupIconViews() {
        addSubview(doneIconView)
        constrain(doneIconView) { doneIconView in
            doneIconView.left == doneIconView.superview!.left + 8
            doneIconView.centerY == doneIconView.superview!.centerY
        }
        
        addSubview(deleteIconView)
        constrain(deleteIconView) { deleteIconView in
            deleteIconView.right == deleteIconView.superview!.right - 12
            deleteIconView.centerY == deleteIconView.superview!.centerY
        }
    }

    private func setupTextView() {
        textView.delegate = self
        addSubview(textView)
        constrain(textView) { textView in
            textView.left == textView.superview!.left + 8
            textView.top == textView.superview!.top + 8
            textView.bottom == textView.superview!.bottom
            textView.right == textView.superview!.right
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
            originalCenter = center
            
            originalDeleteIconCenter = deleteIconView.center
            deleteIconView.translatesAutoresizingMaskIntoConstraints = true
            
            originalDoneIconCenter = doneIconView.center
            doneIconView.translatesAutoresizingMaskIntoConstraints = true
            
            releaseAction = nil
            break
        case .Changed:
            let translation = recognizer.translationInView(self)
            center = CGPoint(x: originalCenter.x + translation.x, y: originalCenter.y)
            let fractionOfThreshold = min(1, Double(abs(frame.origin.x) / (frame.size.width / 4)))
            releaseAction = fractionOfThreshold >= 1 ? (frame.origin.x > 0 ? .Complete : .Delete) : nil

            let offsetDelta = min(abs(translation.x), (frame.size.width / 4))
            doneIconView.center = CGPoint(x: originalDoneIconCenter.x - offsetDelta, y: originalDoneIconCenter.y)
            deleteIconView.center = CGPoint(x: originalDeleteIconCenter.x + offsetDelta, y: originalDeleteIconCenter.y)
            
            doneIconView.alpha = CGFloat(fractionOfThreshold)
            deleteIconView.alpha = CGFloat(fractionOfThreshold)
            
            if !item.completed {
                backgroundOverlayView.backgroundColor = .completeGreenBackgroundColor()
                backgroundOverlayView.hidden = releaseAction != .Complete
                if frame.origin.x > 0 {
                    textView.unstrike()
                    textView.strike(fractionOfThreshold)
                } else {
                    releaseAction == .Complete ? textView.strike() : textView.unstrike()
                }
            } else {
                backgroundOverlayView.hidden = releaseAction == .Complete
                textView.alpha = releaseAction == .Complete ? 1 : 0.3
                if frame.origin.x > 0 {
                    textView.unstrike()
                    textView.strike(1 - fractionOfThreshold)
                } else {
                    releaseAction == .Complete ? textView.unstrike() : textView.strike()
                }
            }
            break
        case .Ended:
            var deletedAction = false
            
            switch releaseAction {
            case .Some(.Complete):
                setCompleted(!item.completed, animated: true)
                break
            case .Some(.Delete):
                deletedAction = true
                delegate?.itemDeleted(item)
                break
            case nil:
                item.completed ? textView.strike() : textView.unstrike()
                break
            }
            
            // If not deleting, slide it back into the middle
            // If we are deleting, slide it all the way out of the view
            var targetFrame = CGRectZero
            if deletedAction == false {
                targetFrame = CGRect(x: 0, y: frame.origin.y, width: bounds.size.width, height: bounds.size.height)
            }
            else {
                targetFrame = CGRect(x: -bounds.size.width, y: frame.origin.y, width: bounds.size.width, height: bounds.size.height)
            }
            
            UIView.animateWithDuration(0.2, animations: { [weak self] in
                self?.frame = targetFrame
            },
            completion: { complete in
                self.doneIconView.translatesAutoresizingMaskIntoConstraints = false
                self.deleteIconView.translatesAutoresizingMaskIntoConstraints = false
            })
            
            break
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

    // MARK: Actions

    private func setCompleted(completed: Bool, animated: Bool = false) {
        completed ? textView.strike() : textView.unstrike()
        backgroundOverlayView.hidden = !completed
        let updateColor = { [weak self] in
            self?.backgroundOverlayView.backgroundColor = completed ?
                .completeDimBackgroundColor() : .completeGreenBackgroundColor()
            self?.textView.alpha = completed ? 0.3 : 1
        }
        if animated {
            try! item.realm?.write {
                item.completed = completed
            }
            vibrate()
            UIView.animateWithDuration(0.2, animations: updateColor)
            delegate?.itemCompleted(item)
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
        delegate?.cellDidBeginEditing(self)
    }

    func textViewDidEndEditing(textView: UITextView) {
        if let realm = item.realm {
            try! realm.write {
                item.text = textView.text
            }
        } else {
            item.text = textView.text
        }
        textView.userInteractionEnabled = false
        delegate?.cellDidEndEditing(self)
    }
}
