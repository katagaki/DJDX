import SwiftUI
import AppKit

// Reports trackpad/mouse scroll deltas to SwiftUI without ever becoming the
// mouse hit-target — `hitTest` returns nil so click-drag gestures (box editing,
// option-pan) pass straight through. Scroll events are picked up via a local
// event monitor, filtered to the cursor being inside this view's bounds.
struct ScrollCatcher: NSViewRepresentable {
    var onScroll: (CGSize) -> Void

    func makeNSView(context: Context) -> NSView {
        let v = CatcherView()
        v.onScroll = onScroll
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onScroll = onScroll
    }

    final class CatcherView: NSView {
        var onScroll: ((CGSize) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
                return
            }
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let win = self.window, event.window === win else { return event }
                let pt = self.convert(event.locationInWindow, from: nil)
                if self.bounds.contains(pt) {
                    self.onScroll?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
                }
                return event
            }
        }

        // Never intercept mouse events; we only care about scroll. The monitor
        // is torn down in viewDidMoveToWindow when the view leaves its window.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
