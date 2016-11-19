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
    
    
}
