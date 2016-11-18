//
//  AppDelegate.swift
//  cutecmd-mac
//
//  Created by pro on 16/11/17.
//  Copyright © 2016年 wuniu. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var input: NSTextField!
    
    let directoryURL = try? FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    

    func openUserScriptsFolder (){
        if let folder = directoryURL {
            NSWorkspace.shared().open(folder)
        }
    }
    
    func runScript(filename: String){
        let surl = directoryURL!.appendingPathComponent(filename + ".scpt")
        
        do {
            if try surl.checkResourceIsReachable() {
                _ = try? NSUserAppleScriptTask(url: surl).execute(withAppleEvent: nil, completionHandler: nil)
                self.hideApp()
            }
        } catch {
            print("url invalid")
            runShell(filename.components(separatedBy: "\t"))
        }
    }
    
    @discardableResult
    func runShell(_ args: [String]) {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = args
        task.launch()
        task.waitUntilExit()
//        print(task.terminationStatus, task.terminationReason.rawValue)
        if( task.terminationStatus > 0 ) {
            if(args[0] != "open"){
                return runShell(["open"] + args)
            } else if(args.count > 1 && args[1] != "-a") {
                var newArgs = [] + args
                newArgs.insert("-a", at: 1)
                return runShell( newArgs )
            }
            
        }
    }
    
    func showApp (){
        if(NSApp.isHidden) {
            NSApp.unhide(self)
        }
        window.center()
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
        
        //        window.makeFirstResponder(input)
    }
    
    func hideApp (){
        //        window.orderOut(self)
        NSApp.hide(self)
        
    }
    
    func quitApp(){
        exit(0)
    }
    
    
    func ExecuteCommand (key: String) {
        if(key == "") {
            return
        }
        switch (key) {
        case "quit":
            quitApp()
        case "setup":
            openUserScriptsFolder()
        default:
            runScript(filename: key)
        }
        self.input.stringValue.removeAll()
    }
    
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
    
    
    /* Delegate methods */
    
    func applicationWillResignActive(_ notification: Notification) {
        hideApp()
        
    }
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        checkSingleton()
        
        HookKeyEvent.setupHook(trigger: showApp)
        
        
        window.isMovableByWindowBackground  = true
        window.titleVisibility = NSWindowTitleVisibility.hidden
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.closable)
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)
        window.titlebarAppearsTransparent = true
        window.level = Int(CGWindowLevelKey.maximumWindow.rawValue)
        window.collectionBehavior = [.stationary, .canJoinAllSpaces, .fullScreenAuxiliary]
        window.setIsVisible(false)
        
        hideApp()
        
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event: NSEvent) in
            
            // Command-Space will insert SPACE
            if(event.keyCode == 49 && event.modifierFlags.contains(.command)){
                self.input.stringValue += " "
                return nil
            }
            
            if(event.keyCode == 48){
                self.input.stringValue += "\t"
                return nil
            }
            
            if(event.keyCode == 49 || event.keyCode == 36) {  // SPACE or Enter
                
                self.ExecuteCommand(key: self.input.stringValue)
                return nil
            }
            
            if(event.keyCode == 53  //ESC or Ctrl-G
                || event.charactersIgnoringModifiers == "g" && event.modifierFlags.contains(.control)) {
                self.input.stringValue.removeAll()
                self.hideApp()
                return nil
            }
            
            return event
        })
        
    }
    
}




private class HookKeyEvent {
    
    public static let shared = HookKeyEvent()
    
    var delayTime = 0.5 * 1e9  // 0.5 sec
    var prevTime:UInt64 = 0
    var isTriggered = false
    var isControlDown = false
    
    var count = 0
    
    static var handler:(()->Void)?
    
    static func setupHook(trigger: @escaping (()->Void)){
        handler = trigger
        let eventMask = CGEventMask((1 << CGEventType.flagsChanged.rawValue))
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
        
        // totalHash==0  equal to isKeyUp ??
        if totalHash > 1 {
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


