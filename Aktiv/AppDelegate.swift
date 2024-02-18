/*
 Project by Hugo Cardante
 Started on: 17/02/2024
 Last updated on: 18/02/2024
*/

import Cocoa
import IOKit.ps

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusBarItem: NSStatusItem!
    var batteryStatusTimer: Timer?
    var screenOnTimeSinceLastUnplugged: TimeInterval = 0
    var totalUptimeSinceAppStarted: TimeInterval = 0
    var appStartTime: Date?
    var activeDisplayMenuItem: NSMenuItem!
    var totalUptimeMenuItem: NSMenuItem!
    var lastUpdateTime: Date?
    var isSleeping: Bool = false
    var isCharging: Bool = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.button?.title = "Calculating..."
        
        appStartTime = Date()
        lastUpdateTime = appStartTime // Initialize the last update time
        
        setupMenu()
        registerForNotifications()
        startTimer()
        loadState() // Load saved state, if any
    }

    func setupMenu() {
        let menu = NSMenu()

        activeDisplayMenuItem = NSMenuItem(title: "Screen On Time: Calculating...", action: nil, keyEquivalent: "")
        totalUptimeMenuItem = NSMenuItem(title: "Total Uptime: Calculating...", action: nil, keyEquivalent: "")
        let creatorMenuItem = NSMenuItem(title: "Created by: Hugo Cardante", action: nil, keyEquivalent: "")
        creatorMenuItem.isEnabled = false // Make non-selectable
        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        
        menu.addItem(activeDisplayMenuItem)
        menu.addItem(totalUptimeMenuItem)
        menu.addItem(creatorMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitMenuItem)

        statusBarItem.menu = menu
    }

    func registerForNotifications() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
    }

    func startTimer() {
        batteryStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeTracking()
        }
    }

    @objc func updateTimeTracking() {
        guard let lastUpdate = lastUpdateTime else { return }
        let now = Date()
        let elapsedTime = now.timeIntervalSince(lastUpdate)
        lastUpdateTime = now

        // Update total uptime regardless of sleeping or charging status
        totalUptimeSinceAppStarted += elapsedTime

        // Only update screen on time if not sleeping and not charging
        if !isSleeping && !isCharging {
            screenOnTimeSinceLastUnplugged += elapsedTime
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }

    func updateUI() {
        let screenOnHours = Int(screenOnTimeSinceLastUnplugged) / 3600
        let screenOnMinutes = (Int(screenOnTimeSinceLastUnplugged) % 3600) / 60
        statusBarItem.button?.title = "Aktiv: \(screenOnHours)h \(screenOnMinutes)m"
        activeDisplayMenuItem.title = "Screen On: \(screenOnHours)h \(screenOnMinutes)m"

        let uptimeHours = Int(totalUptimeSinceAppStarted) / 3600
        let uptimeMinutes = (Int(totalUptimeSinceAppStarted) % 3600) / 60
        totalUptimeMenuItem.title = "Total Uptime: \(uptimeHours)h \(uptimeMinutes)m"
    }

    @objc func systemWillSleep(notification: Notification) {
        isSleeping = true
    }

    @objc func systemDidWake(notification: Notification) {
        isSleeping = false
        lastUpdateTime = Date() // Reset update time on wake
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        saveState()
    }

    func saveState() {
        UserDefaults.standard.set(screenOnTimeSinceLastUnplugged, forKey: "screenOnTimeSinceLastUnplugged")
        UserDefaults.standard.set(totalUptimeSinceAppStarted, forKey: "totalUptimeSinceAppStarted")
    }

    func loadState() {
        screenOnTimeSinceLastUnplugged = UserDefaults.standard.double(forKey: "screenOnTimeSinceLastUnplugged")
        totalUptimeSinceAppStarted = UserDefaults.standard.double(forKey: "totalUptimeSinceAppStarted")
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
