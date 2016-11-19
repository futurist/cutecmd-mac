//
//  TextView.swift
//  cutecmd-mac
//
//  Created by pro on 16/11/19.
//  Copyright © 2016年 wuniu. All rights reserved.
//

import Foundation
import AppKit

class TextView: NSTextView {
    
    override func drawInsertionPoint(in rect: NSRect, color: NSColor, turnedOn flag: Bool) {
        color.set()
        NSRectFill(NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width+1, height: rect.size.height) )
    }
    
    // prevent rich text pasting break format
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
    
    // when text changed, frames may enlarge to multiline
    override func controlTextDidChange(_ obj: Notification) {
        let window = self.window!
        
        let height = self.frame.height
        let top = (window.frame.height - height)/2
    }
    
}
