//
//  AutoCompleteTextField.swift
//  AutoCompleteTextFieldDemo
//
//  Created by fancymax on 15/12/12.
//  Copyright © 2015年 fancy. All rights reserved.
//

import Cocoa

@objc protocol AutoCompleteTableViewDelegate:NSObjectProtocol{
    func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String]
    @objc optional func didSelectItem(_ selectedItem: String)
}

class AutoCompleteTableRowView:NSTableRowView{
    override func drawSelection(in dirtyRect: NSRect) {
        if self.selectionHighlightStyle != .none{
            let selectionRect = NSInsetRect(self.bounds, 0.5, 0.5)
            NSColor.selectedMenuItemColor.setStroke()
            NSColor.selectedMenuItemColor.setFill()
            let selectionPath = NSBezierPath(roundedRect: selectionRect, xRadius: 0.0, yRadius: 0.0)
            selectionPath.fill()
            selectionPath.stroke()
        }
    }
    
    override var interiorBackgroundStyle:NSBackgroundStyle{
        get{
            if self.isSelected {
                return NSBackgroundStyle.dark
            }
            else{
                return NSBackgroundStyle.light
            }
        }
    }
}

class AutoCompleteTextField:NSTextView{
    weak var tableViewDelegate:AutoCompleteTableViewDelegate?
    var popOverWidth:CGFloat = 200
    let popOverPadding:CGFloat = 0.0
    let maxResults = 10
    
    var autoCompletePopover:NSPopover?
    weak var autoCompleteTableView:NSTableView?
    var matches:[String]?
    
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        popOverWidth =  frameRect.size.width
        
        let column1 = NSTableColumn(identifier: "text")
        column1.isEditable = false
        column1.width = popOverWidth - 2 * popOverPadding
        
        let tableView = NSTableView(frame: NSZeroRect)
        tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyle.regular
        tableView.backgroundColor = NSColor.clear
        tableView.rowSizeStyle = NSTableViewRowSizeStyle.small
        tableView.intercellSpacing = NSMakeSize(10.0, 0.0)
        tableView.headerView = nil
        tableView.refusesFirstResponder = true
        tableView.target = self
        tableView.doubleAction = #selector(AutoCompleteTextField.insert(_:))
        tableView.addTableColumn(column1)
        tableView.delegate = self
        tableView.dataSource = self
        self.autoCompleteTableView = tableView
        
        let tableSrollView = NSScrollView(frame: NSZeroRect)
        tableSrollView.drawsBackground = false
        tableSrollView.documentView = tableView
        tableSrollView.hasVerticalScroller = true
        
        // see issue #1, popover throws when contentView's height=0, CoreGraphics bug?
        let contentView:NSView = NSView(frame: NSRect.init(x: 0, y: 0, width: popOverWidth, height: 1))
        contentView.addSubview(tableSrollView)
        
        let contentViewController = NSViewController()
        contentViewController.view = contentView
        
        self.autoCompletePopover = NSPopover()
        self.autoCompletePopover?.appearance = NSAppearance(named: NSAppearanceNameVibrantLight)
        self.autoCompletePopover?.animates = false
        self.autoCompletePopover?.contentViewController = contentViewController
        self.autoCompletePopover?.delegate = self

        self.matches = [String]()
    }
    
    
    func insert(_ sender:AnyObject){
        let selectedRow = self.autoCompleteTableView!.selectedRow
        let matchCount = self.matches!.count
        if selectedRow >= 0 && selectedRow < matchCount{
            self.string = self.matches![selectedRow]
            if self.tableViewDelegate!.responds(to: #selector(AutoCompleteTableViewDelegate.didSelectItem(_:))){
                self.tableViewDelegate!.didSelectItem!(self.string!)
            }
        }
        self.autoCompletePopover?.close()
    }
    
    override func complete(_ sender: Any?) {
        let lengthOfWord = self.string!.characters.count
        let subStringRange = NSMakeRange(0, lengthOfWord)
        
        //This happens when we just started a new word or if we have already typed the entire word
        if subStringRange.length == 0 || lengthOfWord == 0 {
            self.autoCompletePopover?.close()
            return
        }
        
        var index = 0
        self.matches = self.getCompletionArray(subStringRange, indexOfSelectedItem: &index)
        
        if self.matches!.count > 0 {
            self.autoCompleteTableView?.reloadData()
            self.autoCompleteTableView?.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            self.autoCompleteTableView?.scrollRowToVisible(index)
            
            
            let rect = self.visibleRect
            self.autoCompletePopover?.show(relativeTo: rect, of: self, preferredEdge: NSRectEdge.maxY)
        }
        else{
            self.autoCompletePopover?.close()
        }
    }
    
    
    func getCompletionArray(_ charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) ->[String]{
        if self.tableViewDelegate!.responds(
            
            to: #selector(AutoCompleteTableViewDelegate.textView(_:completions:forPartialWordRange:indexOfSelectedItem:))){
            return self.tableViewDelegate!.textView(self, completions: [], forPartialWordRange: charRange, indexOfSelectedItem: index)
        }
        return []
    }
    
    
}

// MARK: - NSPopoverDelegate
extension AutoCompleteTextField: NSPopoverDelegate{
    
    // caclulate contentSize only before it will show, to make it more stable
    func popoverWillShow(_ notification: Notification) {
        
        let numberOfRows = min(self.autoCompleteTableView!.numberOfRows, maxResults)
        let height = (self.autoCompleteTableView!.rowHeight + self.autoCompleteTableView!.intercellSpacing.height) * CGFloat(numberOfRows) + 2 * 0.0
        let frame = NSMakeRect(0, 0, popOverWidth, height)
        self.autoCompleteTableView?.enclosingScrollView?.frame = NSInsetRect(frame, popOverPadding, popOverPadding)
        self.autoCompletePopover?.contentSize = NSMakeSize(NSWidth(frame), NSHeight(frame))
        
    }
    
}

// MARK: - NSTableViewDelegate
extension AutoCompleteTextField:NSTableViewDelegate{
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return AutoCompleteTableRowView()
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellView = tableView.make(withIdentifier: "MyView", owner: self) as? NSTableCellView
        if cellView == nil{
            cellView = NSTableCellView(frame: NSZeroRect)
            let textField = NSTextField(frame: NSZeroRect)
            textField.isBezeled = false
            textField.drawsBackground = false
            textField.isEditable = false
            textField.isSelectable = false
            cellView!.addSubview(textField)
            cellView!.textField = textField
            cellView!.identifier = "MyView"
        }
        let attrs = [NSForegroundColorAttributeName:NSColor.black,NSFontAttributeName:NSFont.systemFont(ofSize: 13)]
        let mutableAttriStr = NSMutableAttributedString(string: self.matches![row], attributes: attrs)
        cellView!.textField!.attributedStringValue = mutableAttriStr
        
        return cellView
    }
}

// MARK: - NSTableViewDataSource
extension AutoCompleteTextField:NSTableViewDataSource{
    func numberOfRows(in tableView: NSTableView) -> Int {
        if self.matches == nil{
            return 0
        }
        return self.matches!.count
    }
}
