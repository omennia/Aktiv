/*
 Project by Hugo Cardante
 17/02/2024
 */

import Cocoa
import IOKit.ps

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  var statusBar: NSStatusBar!
  var statusBarItem: NSStatusItem!
  var batteryStatusTimer: Timer?
  var lastUnpluggedTime: Date?  // The time when the computer was last unplugged
  var hasBeenChargedSinceStart: Bool = false
  var displayActiveSinceLastUnplugged: TimeInterval = 0
  var activeDisplayMenuItem: NSMenuItem!
  var totalSleepDuration: TimeInterval = 0
  var sleepStartTime: Date?

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Initialize the status bar item
    statusBar = NSStatusBar.system
    statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
    statusBarItem.button?.title = "Calculating..."

    // Load saved state
    loadState()

    // Set up the menu
    let menu = NSMenu()

    // Add a menu item for the active display time
    activeDisplayMenuItem = NSMenuItem(
      title: "Active Display Time: Calculating...", action: nil, keyEquivalent: "")
    activeDisplayMenuItem.isEnabled = false  // Make it non-selectable
    menu.addItem(activeDisplayMenuItem)

    // Add a menu item for the creator text
    let creatorMenuItem = NSMenuItem(
      title: "Created by: Hugo Cardante", action: nil, keyEquivalent: "")
    creatorMenuItem.isEnabled = false  // Make it non-selectable
    menu.addItem(creatorMenuItem)

    menu.addItem(NSMenuItem.separator())

    let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
    menu.addItem(quitMenuItem)

    statusBarItem.menu = menu

    // sleep/wake notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(
      self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification,
      object: nil)

    // Timer to update the battery status every second
    batteryStatusTimer = Timer.scheduledTimer(
      timeInterval: 1.0,
      target: self,
      selector: #selector(updateBatteryStatusAndCheckPowerSource),
      userInfo: nil,
      repeats: true)
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
        let powerSourceState = info[kIOPSPowerSourceStateKey] as? String
      {
        isCurrentlyCharging = isCharging
        isOnBattery = (powerSourceState == kIOPSBatteryPowerValue)
        break
      }
    }

    DispatchQueue.main.async {
      if isCurrentlyCharging || !isOnBattery {
        self.totalSleepDuration = 0
      }

      if isOnBattery && !isCurrentlyCharging && self.lastUnpluggedTime == nil {
        self.lastUnpluggedTime = Date()
        print("Set lastUnpluggedTime")
      }

      self.updateUI(isOnBattery: isOnBattery, isCurrentlyCharging: isCurrentlyCharging)
    }
  }

  func updateUI(isOnBattery: Bool, isCurrentlyCharging: Bool) {
    let elapsedTime: TimeInterval

    // Check if the computer is charging
    if isCurrentlyCharging {
      self.statusBarItem.button?.title = "Charging..."
    } else if isOnBattery {
      // Display logic for when on battery and not charging
      if let lastUnpluggedTime = self.lastUnpluggedTime, isOnBattery && !isCurrentlyCharging {
        // Only calculate elapsed time if we're on battery and not charging
        elapsedTime = Date().timeIntervalSince(lastUnpluggedTime)
      } else {
        elapsedTime = 0
      }

      let activeTimeWithoutSleep = max(elapsedTime - totalSleepDuration, 0)
      let hoursActiveWithoutSleep = Int(activeTimeWithoutSleep) / 3600
      let minutesActiveWithoutSleep = (Int(activeTimeWithoutSleep) % 3600) / 60

      // Display total active time since unplugged in the top bar
      let hoursTotal = Int(elapsedTime) / 3600
      let minutesTotal = (Int(elapsedTime) % 3600) / 60
      self.statusBarItem.button?.title = "Active: \(hoursTotal)h \(minutesTotal)m"

      // Display active time minus sleep time in the menu
      self.activeDisplayMenuItem.title =
        "Display On: \(hoursActiveWithoutSleep)h \(minutesActiveWithoutSleep)m"
    } else {
      // Display logic for when plugged in but not charging
      self.statusBarItem.button?.title = "Plugged In"
    }
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    saveState()
    // Invalidate the timer when the application is about to terminate
    batteryStatusTimer?.invalidate()
  }

  @objc func systemWillSleep(notification: Notification) {
    sleepStartTime = Date()
    print("System will sleep at: \(String(describing: sleepStartTime))")
  }

  @objc func systemDidWake(notification: Notification) {
    if let sleepStart = sleepStartTime {
      let sleepDuration = Date().timeIntervalSince(sleepStart)
      totalSleepDuration += sleepDuration
      print("Woke up, adding \(sleepDuration) to totalSleepDuration, now: \(totalSleepDuration)")
    }
  }

  func saveState() {
    UserDefaults.standard.set(lastUnpluggedTime, forKey: "lastUnpluggedTime")
    UserDefaults.standard.set(hasBeenChargedSinceStart, forKey: "hasBeenChargedSinceStart")
  }

  func loadState() {
    lastUnpluggedTime = UserDefaults.standard.object(forKey: "lastUnpluggedTime") as? Date
    hasBeenChargedSinceStart = UserDefaults.standard.bool(forKey: "hasBeenChargedSinceStart")
  }

  @objc func quitApp() {
    NSApplication.shared.terminate(self)
  }
}
