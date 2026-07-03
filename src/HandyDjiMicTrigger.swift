import Cocoa
import CoreGraphics
import Foundation
import IOKit.hid

func parseIntEnv(_ name: String, default defaultValue: Int) -> Int {
    guard let rawValue = ProcessInfo.processInfo.environment[name]?.lowercased() else {
        return defaultValue
    }

    if rawValue.hasPrefix("0x") {
        return Int(rawValue.dropFirst(2), radix: 16) ?? defaultValue
    }

    return Int(rawValue) ?? Int(rawValue, radix: 16) ?? defaultValue
}

let vendorID = parseIntEnv("DJI_VENDOR_ID", default: 0x2ca3)
let productID = parseIntEnv("DJI_PRODUCT_ID", default: 0x4008)
let consumerUsagePage = 0x0c
let volumeIncrementUsage = 0xe9
let systemDefined = CGEventType(rawValue: 14)!
let auxControlButtonsSubtype = Int16(8)
let djiMediaData1Values: Set<Int> = [2560, 2816]
let f18KeyCode = CGKeyCode(79)
let triggerWindow: TimeInterval = 0.35
let requireDjiHidEvent = ProcessInfo.processInfo.environment["REQUIRE_DJI_HID_EVENT"] != "0"

var lastDjiHidEvent = Date.distantPast

func log(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    fputs(line, stderr)
}

func postFnF18(pressed: Bool) {
    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: f18KeyCode, keyDown: pressed) else {
        return
    }
    event.flags = [.maskSecondaryFn]
    event.post(tap: .cghidEventTap)
}

func markDjiEvent(value: IOHIDValue) {
    let element = IOHIDValueGetElement(value)

    let usagePage = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    guard usagePage == consumerUsagePage, usage == volumeIncrementUsage else {
        return
    }

    let intValue = IOHIDValueGetIntegerValue(value)
    lastDjiHidEvent = Date()
    log("DJI HID event usagePage=0x\(String(usagePage, radix: 16)) usage=0x\(String(usage, radix: 16)) value=\(intValue)")
}

let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: vendorID,
    kIOHIDProductIDKey as String: productID,
]
IOHIDManagerSetDeviceMatching(hidManager, matching as CFDictionary)
IOHIDManagerRegisterInputValueCallback(hidManager, { _, _, _, value in
    markDjiEvent(value: value)
}, nil)
IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

let openResult = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
if openResult != kIOReturnSuccess {
    log("warning: IOHIDManagerOpen returned \(openResult)")
}

let eventCallback: CGEventTapCallBack = { _, type, event, _ in
    guard type == systemDefined,
          let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == auxControlButtonsSubtype,
          djiMediaData1Values.contains(nsEvent.data1) else {
        return Unmanaged.passRetained(event)
    }

    let age = Date().timeIntervalSince(lastDjiHidEvent)
    guard !requireDjiHidEvent || age <= triggerWindow else {
        return Unmanaged.passRetained(event)
    }

    let pressed = nsEvent.data1 == 2816
    postFnF18(pressed: pressed)
    log("translated media event data1=\(nsEvent.data1) djiAge=\(String(format: "%.3f", age)) -> fn+F18 \(pressed ? "down" : "up")")
    return nil
}

guard let eventTap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << systemDefined.rawValue),
    callback: eventCallback,
    userInfo: nil
) else {
    log("failed to create CGEvent tap; grant Accessibility/Input Monitoring permission to this helper")
    exit(2)
}

let eventSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), eventSource, .commonModes)
CGEvent.tapEnable(tap: eventTap, enable: true)

log("started Handy DJI Mic Trigger for vendor=0x\(String(vendorID, radix: 16)) product=0x\(String(productID, radix: 16))")
CFRunLoopRun()
