//
//  ToDoTextView.swift
//  RealmTasks
//
//  Created by JP Simard on 4/11/16.
//  Copyright © 2016 Realm. All rights reserved.
//

import UIKit

final class ToDoItemTextView: UITextView {

    // MARK: Initializers

    init() {
        super.init(frame: .null, textContainer: nil)
        editable = true
        textColor = .whiteColor()
        font = .systemFontOfSize(18)
        backgroundColor = .clearColor()
        userInteractionEnabled = false
        keyboardAppearance = .Dark
        returnKeyType = .Done
        scrollEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Actions

    func strike(fraction: Double = 1) {
        let mutableAttributedString = attributedText!.mutableCopy() as! NSMutableAttributedString
        mutableAttributedString.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, Int(fraction * Double(mutableAttributedString.length))))
        attributedText = mutableAttributedString.copy() as? NSAttributedString
    }

    func unstrike() {
        var mutableTypingAttributes = typingAttributes
        mutableTypingAttributes.removeValueForKey(NSStrikethroughStyleAttributeName)
        typingAttributes = mutableTypingAttributes
        let mutableAttributedString = attributedText!.mutableCopy() as! NSMutableAttributedString
        mutableAttributedString.removeAttribute(NSStrikethroughStyleAttributeName, range: NSMakeRange(0, mutableAttributedString.length))
        attributedText = mutableAttributedString.copy() as? NSAttributedString
    }
}
