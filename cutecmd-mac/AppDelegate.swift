//
//  AppDelegate.swift
//  cutecmd-mac
//
//  Created by pro on 16/11/17.
//  Copyright © 2016年 wuniu. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSTextViewDelegate, AutoCompleteTableViewDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    var input: AutoCompleteTextField!
    
    // Cmd-S to switch between sapce mode
    var isSpaceMode = false
    
    var popupTimer:Timer?
    
    // suggestion dropDown is showing?
    var isCompleting = false
    
    let wordRegEx = "[0-9a-zA-Z_]+$"
    
    let directoryURL = try? FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    static var isWindowShow = false
    
    var AppList:[String] = []
    
    func loadAppList () {
        AppList = AppDelegate.getAppsInFolders(["/Applications", "/Applications/Utilities"])
    }

    func openUserScriptsFolder (){
        if let folder = directoryURL {
            NSWorkspace.shared().open(folder)
        }
        
    }
    
    func runScript(filename: String){
        let surl = directoryURL!.appendingPathComponent(filename + ".scpt")

        hideApp()

        do {
            if try surl.checkResourceIsReachable() {
                _ = try? NSUserAppleScriptTask(url: surl).execute(withAppleEvent: nil, completionHandler: nil)
            }
        } catch {
            print("script not found")
            
            let args = splitCommandLine(str: filename, by:[" "])
            
            // first try run as a Applicaiton
            if( runShell(["open \'\(filename)\'"]) > 0
                && runShell(["open -a \'\(filename)\'"]) > 0
//                && runShell( args ) > 0
                ) {
                
                print("Command execute error", args, input.string!)
                
            }
        }
    }
    
    @discardableResult
    func runShell(_ args: [String], raw rawString: String = "") -> Int32 {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c"] + args
        task.launch()
        task.waitUntilExit()
//        print(task.terminationStatus, task.terminationReason.rawValue)
        return task.terminationStatus
    }
    
    func showApp (){
        
        AppDelegate.isWindowShow = true
        
        updateSize()
        
        if(NSApp.isHidden) {
            NSApp.unhide(self)
        }
        window.center()
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(input)
        
    }
    
    
    func hideApp (){
        
        input.autoCompletePopover?.close()

        stopPopupTimer()
        
        //        window.orderOut(self)

        NSApp.hide(self)
        
        isSpaceMode = false
        updateInputMode()
        
        AppDelegate.isWindowShow = false
        HookKeyEvent.shared.resetState()
        HookKeyEvent.shared.isControlDown = false

    }
    
    func quitApp(){
        exit(0)
    }

    // split command line with space, regard Quote
    // The result don't contain Quote at first/end
    func splitCommandLine(str: String, by characterSet: CharacterSet) -> [String] {
        let quoteStr = "\'\""
        let quoteSet = CharacterSet.init(charactersIn: quoteStr)
        var apperQuote = false
        let result = str.utf16.split(maxSplits: Int.max, omittingEmptySubsequences: true) { x in
            if quoteSet.contains(UnicodeScalar(x)!) {
                apperQuote = !apperQuote
            }
            if apperQuote {
                return false
            } else {
                return characterSet.contains(UnicodeScalar(x)!)
            }
            }.flatMap(String.init)
        
        return result.map({x in
            var isQuoted = false
            var unQuoted = x
            for (_, quote) in str.characters.enumerated() {
                isQuoted = x.hasPrefix(String(quote)) && x.hasSuffix(String(quote))
                if isQuoted && x.characters.count > 1 {
                    // when only one char in x, below will throw error
                    unQuoted = x[x.index(x.startIndex, offsetBy: 1)..<x.index(x.endIndex, offsetBy: -1) ]
                    break
                }
            }
            //            x.characters.dropLast().dropLast()

            return unQuoted
        })
        
    }

    
    func updateInputMode() {
        window.backgroundColor = isSpaceMode ? NSColor.darkGray : NSColor.init(hue: 0, saturation: 0, brightness: 0.85, alpha: 1)
        try input.textColor = isSpaceMode ? NSColor.blue : NSColor.textColor
        try input.backgroundColor = isSpaceMode ? NSColor.lightGray : NSColor.controlBackgroundColor
    }
    
    
    func ExecuteCommand (key: String) {
        if(key == "") {
            return
        }
        switch (key) {
        case ":quit":
            quitApp()
        case ":reload":
            loadAppList()
        case ":setup":
            openUserScriptsFolder()
        default:
            runScript(filename: key)
        }
        self.input.string!.removeAll()
    }
    
    
    /* Delegate methods */
    
    func applicationWillResignActive(_ notification: Notification) {
        hideApp()
        
    }
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        checkSingleton()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        loadAppList()
        
        window.isMovableByWindowBackground  = true
        window.titleVisibility = NSWindowTitleVisibility.hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)
        window.titlebarAppearsTransparent = true
        window.level = Int(CGWindowLevelKey.maximumWindow.rawValue)
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary]

        let top = (window.frame.height - 48)/2
        input = AutoCompleteTextField(frame: NSMakeRect(20, top, window.frame.width-40, 48))
        
        input.textContainerInset = NSSize(width: 10, height: 10)
        input.font = NSFont(name:"Helvetica", size:24)
        input.isEditable = true
        input.isSelectable = true
        
        // prevent quote etc. be replaced
        input.enabledTextCheckingTypes = 0
        
        input.tableViewDelegate = self
        input.delegate = self
                        
        window.contentView!.addSubview(input)
        
        // wait for the event loop to activate
        DispatchQueue.main.async {
            self.showApp()
            self.updateInputMode()
            HookKeyEvent.setupHook(trigger: self.showApp)
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler:localEventMonitor )
        
    }
    
    
    
    func localEventMonitor(event: NSEvent) -> NSEvent? {
        
//        print(event.keyCode, UnicodeScalar(event.characters!), event.charactersIgnoringModifiers )
        
        let autoCompleteView = input.autoCompleteTableView!
        let row:Int = autoCompleteView.selectedRow
        let isShow = input.autoCompletePopover!.isShown
        let keyCode = event.keyCode

        // CTRL-n
        if(isShow && event.modifierFlags.contains(.control) && keyCode==45
            || keyCode == 125 ){
            autoCompleteView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
            autoCompleteView.scrollRowToVisible((autoCompleteView.selectedRow))
            return nil
        }
        
        // CTRL-p
        if(isShow && event.modifierFlags.contains(.control) && keyCode==35
            || keyCode == 126){
            autoCompleteView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
            autoCompleteView.scrollRowToVisible((autoCompleteView.selectedRow))
            return nil
        }
        
        // TAB
        if(keyCode == 48){
            self.input.insert(input)
            self.ExecuteCommand(key: self.input.string!)
            return nil
        }
        
        // CMD-Space will insert SPACE
        if(keyCode == 49 && event.modifierFlags.contains(.command)){
            self.input.string! += " "
            return nil
        }
        
        // CMD-S will switch SpaceMode
        if(event.charactersIgnoringModifiers == "s" && event.modifierFlags.contains(.command)){
            self.isSpaceMode = !self.isSpaceMode
            self.updateInputMode()
            return nil
        }
        
        if(!self.isSpaceMode && keyCode == 49 || keyCode == 36) {  // SPACE or Enter
            
            self.ExecuteCommand(key: self.input.string!)
            return nil
        }
        
        if(keyCode == 53  //ESC or Ctrl-G
            || event.charactersIgnoringModifiers == "g" && event.modifierFlags.contains(.control)) {
            self.input.string!.removeAll()
            self.hideApp()
            return nil
        }
        
        return event
    }
    
    
}

extension AppDelegate {
    /* --- Some util func --- */
    
    func setTimeout(delay:TimeInterval, block:@escaping ()->Void) -> Timer {
        return Timer.scheduledTimer(timeInterval: delay, target: BlockOperation(block: block), selector: #selector(Operation.main), userInfo: nil, repeats: false)
    }
    
    /* Application Singleton */
    
    func checkSingleton (){
        
        // Check if another instance of this app is running
        let bundleID = Bundle.main.bundleIdentifier!
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        
        if apps.count > 1 {
            
            // Activate the other instance and terminate this instance
            for app in apps {
                if app != NSRunningApplication.current() {
                    app.activate(options: [.activateIgnoringOtherApps])
                    break
                }
            }
            NSApp.terminate(nil)
        }
        
    }
    
    
    func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
    
    static func getAppsInFolders (_ folders: [String]) -> [String] {
        let filemanager:FileManager = FileManager()
        var apps = [String]()
        
        for folder in folders {
            
            let files = try? filemanager.contentsOfDirectory(atPath: folder)
            if let filesArr = files {
                apps.append(contentsOf: filesArr.filter{
                        // only .app folders
                        $0.hasSuffix(".app")
                    
                    }.map{ x in
                        // without .app extension
                        x[x.startIndex..<x.index(x.endIndex, offsetBy: -4) ]
                } )
            }

        }
        
        return apps
    }
    
}


extension AppDelegate {

    /* NSTextView Delegate part */
    
    func stopPopupTimer (){
        if let timer = popupTimer {
            if(timer.isValid) {
                timer.invalidate()
            }
            popupTimer = nil
        }
    }

    // when text changed, frames may enlarge to multiline
    func textDidChange(_ notification: Notification) {
        
        updateSize()
        
        stopPopupTimer()
        
        popupTimer = setTimeout(delay: 0.2, block: { () -> Void in
            // delay popup completion window
            if (!self.isCompleting) {
                // to prevent infinite loop
                self.isCompleting = true
                self.input.complete(self.input)
                self.isCompleting = false
            }
        })
        
    }
    
    
    func textView(_ textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String] {
        
        let str = input.string!
        let range = input.selectedRange()
        
        if(str.isEmpty) {
            return []
        }
        
        let strOfCaret = str.substring(to: str.index(str.startIndex, offsetBy: range.location))
        let word = self.matches(for: wordRegEx, in: strOfCaret).last ?? ""
        
        let retArr = word.isEmpty ? [] : [] + AppList
        
        return retArr.filter({x in x.score(str)>0}).sorted(by: { (a, b) in
            a.score(str) > b.score(str)
        })
    }
    
    func updateSize(){
        var frame = window.frame
        var inputOrigin = input.frame.origin
        let oldHeight = frame.size.height
        
        let inputHeight = input.frame.height
        let winHeight = inputHeight + 40
        inputOrigin.y = (winHeight - inputHeight)/2
        
        frame.size.height = winHeight
        frame.origin.y -= (winHeight - oldHeight)
        
        window.setFrame(frame, display: true)
        input.setFrameOrigin(inputOrigin)
    }

}



private class HookKeyEvent {
    
    /* Hook key in global */
    
    public static let shared = HookKeyEvent()
    
    var delayTime = 0.5 * 1e9  // 0.5 sec
    var prevTime:UInt64 = 0
    var isTriggered = false
    var isControlDown = false
    
    var count = 0
    
    static var handler:(()->Void)?
    
    static func setupHook(trigger: @escaping (()->Void)){
        handler = trigger
        let eventMask = CGEventMask((
            1 << CGEventType.flagsChanged.rawValue))
        guard let eventTap = CGEvent.tapCreate(tap: .cghidEventTap,
                                               place: .headInsertEventTap,
                                               options: .listenOnly,
                                               eventsOfInterest: eventMask,
                                               callback: { (_,_,event,_) in return HookKeyEvent.shared.checkEvent(event) },
                                               userInfo: nil) else {
                                                print("failed to create event tap")
                                                exit(1)
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        CFRunLoopRun()
        
    }
    
    
    func checkEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        
        let flags = event.flags
        
        let isKeyUp = event.flags.rawValue <= 256
        
        let commandTapped = flags.contains(.maskCommand)
        let shiftTapped = flags.contains(.maskShift)
        let controlTapped = flags.contains(.maskControl)
        let altTapped = flags.contains(.maskAlternate)
        
        // Make sure only one modifier key
        let totalHash = commandTapped.hashValue + altTapped.hashValue + shiftTapped.hashValue + controlTapped.hashValue
        
        // totalHash==0  equal to isKeyUp ??, or window already shown
        if totalHash > 1 || AppDelegate.isWindowShow {
            resetState()
            return Unmanaged.passRetained(event)
        }
        
        if(!isKeyUp){
            isControlDown = controlTapped
            return Unmanaged.passRetained(event)
        }
        
        
        if(isControlDown) {
            
            isTriggered = DispatchTime.now().rawValue - prevTime < UInt64(delayTime)
            prevTime = DispatchTime.now().rawValue
            
        } else {
            resetState()
        }
        
        if isTriggered {
            doubleTapped()
            resetState()
        }
        
        return Unmanaged.passRetained(event)
    }
    
    func resetState(){
        prevTime = 0
        isTriggered = false
    }
    
    func doubleTapped() {
        count += 1
        print("triggered", count)
        HookKeyEvent.handler?()
    }
    
}


