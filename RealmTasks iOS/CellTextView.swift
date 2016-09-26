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

import UIKit

final class CellTextView: UITextView {

    // MARK: Initializers

    init() {
        super.init(frame: .null, textContainer: nil)
        editable = true
        textColor = .whiteColor()
        font = .systemFontOfSize(18)
        backgroundColor = .clearColor()
        userInteractionEnabled = false
        keyboardAppearance = .Dark
        autocapitalizationType = .Words
        returnKeyType = .Done
        scrollEnabled = false
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Actions

    func strike(fraction: Double = 1) {
        let mutableAttributedString = attributedText!.mutableCopy() as! NSMutableAttributedString
        let range = NSRange(location: 0, length: Int(fraction * Double(mutableAttributedString.length)))
        mutableAttributedString.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: range)
        attributedText = mutableAttributedString.copy() as? NSAttributedString
    }

    func unstrike() {
        var mutableTypingAttributes = typingAttributes
        mutableTypingAttributes.removeValueForKey(NSStrikethroughStyleAttributeName)
        typingAttributes = mutableTypingAttributes
        let mutableAttributedString = attributedText!.mutableCopy() as! NSMutableAttributedString
        let range = NSRange(location: 0, length: mutableAttributedString.length)
        mutableAttributedString.removeAttribute(NSStrikethroughStyleAttributeName, range: range)
        attributedText = mutableAttributedString.copy() as? NSAttributedString
    }
}
