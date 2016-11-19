//
//  TextFieldCell.swift
//  cutecmd-mac
//
//  Created by Mac on 16/11/18.
//  Copyright © 2016年 wuniu. All rights reserved.
//

import Foundation
import AppKit

class TextFieldCell : NSTextFieldCell {
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return NSMakeRect(rect.origin.x+5, rect.origin.y+10, rect.size.width, rect.size.height)
    }
    

}


