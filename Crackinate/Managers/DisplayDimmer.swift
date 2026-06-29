import Foundation
import CoreGraphics

/// Dims the built-in display when the lid is closed on a MacBook.
/// Uses CoreDisplay private API loaded via dlopen/dlsym.
/// Captures the built-in display ID at init so it still works after lid-close
/// disconnects the display from CoreGraphics.
final class DisplayDimmer {
    static let shared = DisplayDimmer()
    private init() {
        builtInDisplayID = Self.findBuiltInDisplayID()
    }

    // MARK: - Types

    private typealias CoreDisplaySetFn = @convention(c) (CGDirectDisplayID, Double) -> Void
    private typealias CoreDisplayGetFn = @convention(c) (CGDirectDisplayID) -> Double

    // MARK: - State

    private var savedBrightness: Double?
    private var didDim = false
    private let builtInDisplayID: CGDirectDisplayID?

    // Cached dylib handle — opened once
    private lazy var coreDisplayHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY)
    }()

    // MARK: - Public

    /// Whether this machine has a built-in display (MacBook) that can be dimmed.
    var hasBuiltInDisplay: Bool { builtInDisplayID != nil }

    /// Dim the built-in display to 0 brightness.
    func dim() {
        guard !didDim else { return }
        guard let displayID = builtInDisplayID else { return }
        guard let handle = coreDisplayHandle else { return }

        savedBrightness = getBrightness(displayID, handle: handle)
        setBrightness(0.0, displayID: displayID, handle: handle)
        didDim = true

        print("[Crackinate] Display dimmed (was: \(savedBrightness ?? -1))")
    }

    /// Restore the display to its previously saved brightness.
    func restore() {
        guard didDim, let saved = savedBrightness else { return }
        guard let displayID = builtInDisplayID else { return }
        guard let handle = coreDisplayHandle else { return }

        setBrightness(saved, displayID: displayID, handle: handle)
        didDim = false
        savedBrightness = nil

        print("[Crackinate] Display brightness restored to \(saved)")
    }

    /// Check if the dimmer can actually control the display.
    var isAvailable: Bool {
        builtInDisplayID != nil && coreDisplayHandle != nil
    }

    // MARK: - Private

    /// Find the built-in (MacBook internal) display ID.
    /// Must be called while the lid is open — returns nil on desktop Macs.
    private static func findBuiltInDisplayID() -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }

        let displays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: Int(count))
        defer { displays.deallocate() }

        guard CGGetActiveDisplayList(count, displays, &count) == .success else {
            return nil
        }

        for i in 0..<Int(count) {
            let id = displays[i]
            if CGDisplayIsBuiltin(id) != 0 {
                print("[Crackinate] Found built-in display ID: \(id)")
                return id
            }
        }

        print("[Crackinate] No built-in display found (desktop Mac or external-only)")
        return nil
    }

    private func setBrightness(_ level: Double, displayID: CGDirectDisplayID, handle: UnsafeMutableRawPointer) {
        guard let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else { return }
        let fn = unsafeBitCast(sym, to: CoreDisplaySetFn.self)
        let clamped = max(0.0, min(1.0, level))
        fn(displayID, clamped)
    }

    private func getBrightness(_ displayID: CGDirectDisplayID, handle: UnsafeMutableRawPointer) -> Double {
        guard let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") else { return 1.0 }
        let fn = unsafeBitCast(sym, to: CoreDisplayGetFn.self)
        return fn(displayID)
    }
}
