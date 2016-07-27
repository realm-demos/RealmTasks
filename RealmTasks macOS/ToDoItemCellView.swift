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

import Cocoa

class ToDoItemCellView: NSTableCellView {
    
    var backgroundColor = NSColor.clearColor() {
        didSet {
            needsDisplay = true
        }
    }
    
    func configureWithToDoItem(item: ToDoItem) {
        textField?.stringValue = item.text
        
        if item.completed {
            backgroundColor = .completeDimBackgroundColor()
            textField?.animator().alphaValue = 0.3
        } else {
            backgroundColor = .clearColor()
            textField?.animator().alphaValue = 1.0
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        backgroundColor.setFill()
        NSRectFillUsingOperation(dirtyRect, .CompositeSourceOver)
    }

}
