/*
 Project by Hugo Cardante
 17/02/2024 :-)
*/

import Cocoa
import IOKit.ps

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusBarItem: NSStatusItem!
    var batteryStatusTimer: Timer?
    var lastUnpluggedTime: Date?  // Time when the computer was last unplugged
    var hasBeenChargedSinceStart: Bool = false
    var screenOnTimeSinceLastUnplugged: TimeInterval = 0
    var activeDisplayMenuItem: NSMenuItem!
    var totalSleepDuration: TimeInterval = 0
    var sleepStartTime: Date?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.title = "Calculating..."

        loadState()

        setupMenu()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)

        batteryStatusTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(updateBatteryStatusAndCheckPowerSource),
            userInfo: nil,
            repeats: true)
    }

    func setupMenu() {
        let menu = NSMenu()

        activeDisplayMenuItem = NSMenuItem(
            title: "Screen On Time: Calculating...", action: nil, keyEquivalent: "")
        activeDisplayMenuItem.isEnabled = false
        menu.addItem(activeDisplayMenuItem)

        let creatorMenuItem = NSMenuItem(
            title: "Created by: Hugo Cardante", action: nil, keyEquivalent: "")
        creatorMenuItem.isEnabled = false
        menu.addItem(creatorMenuItem)

        menu.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitMenuItem)

        statusBarItem.menu = menu
    }

    @objc func updateBatteryStatusAndCheckPowerSource() {
        let powerSourceInfo = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let powerSources: NSArray = IOPSCopyPowerSourcesList(powerSourceInfo).takeRetainedValue()

        var isCurrentlyCharging: Bool = false
        var isOnBattery: Bool = false
        for powerSource in powerSources {
            if let info = IOPSGetPowerSourceDescription(powerSourceInfo, powerSource as CFTypeRef)
                .takeUnretainedValue() as? [String: Any],
               let isCharging = info[kIOPSIsChargingKey] as? Bool,
               let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {
                isCurrentlyCharging = isCharging
                isOnBattery = (powerSourceState == kIOPSBatteryPowerValue)
                break
            }
        }

        DispatchQueue.main.async {
            self.updateUI(isOnBattery: isOnBattery, isCurrentlyCharging: isCurrentlyCharging)
        }
    }

    func updateUI(isOnBattery: Bool, isCurrentlyCharging: Bool) {
        if isCurrentlyCharging {
            statusBarItem.button?.title = "Charging..."
        } else if isOnBattery {
            let hours = Int(screenOnTimeSinceLastUnplugged) / 3600
            let minutes = (Int(screenOnTimeSinceLastUnplugged) % 3600) / 60
            statusBarItem.button?.title = "Screen On: \(hours)h \(minutes)m"
            activeDisplayMenuItem.title = "Screen On: \(hours)h \(minutes)m"
        } else {
            statusBarItem.button?.title = "Plugged In"
        }
    }

    @objc func systemWillSleep(notification: Notification) {
        sleepStartTime = Date()
    }

    @objc func systemDidWake(notification: Notification) {
        guard let sleepStart = sleepStartTime else { return }
        let sleepDuration = Date().timeIntervalSince(sleepStart)
        totalSleepDuration += sleepDuration
        sleepStartTime = nil
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        saveState()
    }

    func saveState() {
        UserDefaults.standard.set(screenOnTimeSinceLastUnplugged, forKey: "screenOnTimeSinceLastUnplugged")
    }

    func loadState() {
        screenOnTimeSinceLastUnplugged = UserDefaults.standard.double(forKey: "screenOnTimeSinceLastUnplugged")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}


?????