import Foundation
import CoreGraphics

/// Dims the built-in display when the lid is closed (optional v1.1 feature).
/// Uses CoreDisplay private API loaded via dlopen/dlsym.
final class DisplayDimmer {
    static let shared = DisplayDimmer()
    private init() {}

    // MARK: - Types

    private typealias CoreDisplaySetFn = @convention(c) (CGDirectDisplayID, Double) -> Void
    private typealias CoreDisplayGetFn = @convention(c) (CGDirectDisplayID) -> Double

    // MARK: - State

    private var savedBrightness: Double?
    private var didDim = false

    // MARK: - Public

    /// Dim the built-in display to 0 brightness.
    /// Saves the current brightness for later restoration.
    func dim() {
        guard !didDim else { return }
        guard let handle = openCoreDisplay() else { return }
        defer { dlclose(handle) }

        savedBrightness = getBrightness(handle: handle)
        setBrightness(0.0, handle: handle)
        didDim = true

        print("[Crackinate] Display dimmed (was: \(savedBrightness ?? -1))")
    }

    /// Restore the display to its previously saved brightness.
    func restore() {
        guard didDim, let saved = savedBrightness else { return }
        guard let handle = openCoreDisplay() else { return }
        defer { dlclose(handle) }

        setBrightness(saved, handle: handle)
        didDim = false
        savedBrightness = nil

        print("[Crackinate] Display brightness restored to \(saved)")
    }

    /// Check if the display dimmer API is available on this system.
    var isAvailable: Bool {
        guard let handle = openCoreDisplay() else { return false }
        dlclose(handle)
        return true
    }

    // MARK: - Private

    private func openCoreDisplay() -> UnsafeMutableRawPointer? {
        return dlopen(
            "/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay",
            RTLD_LAZY
        )
    }

    private func setBrightness(_ level: Double, handle: UnsafeMutableRawPointer) {
        guard let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else { return }
        let fn = unsafeBitCast(sym, to: CoreDisplaySetFn.self)
        let clamped = max(0.0, min(1.0, level))
        fn(CGMainDisplayID(), clamped)
    }

    private func getBrightness(handle: UnsafeMutableRawPointer) -> Double {
        guard let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") else { return 1.0 }
        let fn = unsafeBitCast(sym, to: CoreDisplayGetFn.self)
        return fn(CGMainDisplayID())
    }
}
