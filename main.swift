import SwiftUI
import CoreGraphics
import ApplicationServices
import Carbon.HIToolbox

enum ClickType: Int {
    case left = 0, right = 1, double = 2
}

final class ClickerState: ObservableObject {
    static let shared = ClickerState()

    private let defaults = UserDefaults.standard

    @Published var clicking = false
    @Published var trusted = AXIsProcessTrusted()
    @Published var intervalMs: Double {
        didSet {
            defaults.set(intervalMs, forKey: "intervalMs")
            if clicking { startTimer() }
        }
    }
    @Published var clickType: ClickType { didSet { defaults.set(clickType.rawValue, forKey: "clickType") } }

    private var timer: Timer?

    private init() {
        intervalMs = defaults.object(forKey: "intervalMs") as? Double ?? 500
        clickType = ClickType(rawValue: defaults.integer(forKey: "clickType")) ?? .left
    }

    func toggle() {
        clicking.toggle()
        Self.log(clicking ? "start interval=\(intervalMs) trusted=\(AXIsProcessTrusted())" : "stop")
        clicking ? startTimer() : stopTimer()
    }

    func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: intervalMs / 1000, repeats: true) { [weak self] _ in
            self?.fire()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func fire() {
        Self.click(clickType)
        Self.log("click") // ponytail: temp debug, remove once clicks confirmed
    }

    static func log(_ msg: String) {
        let line = "\(Date()) \(msg)\n"
        if let h = FileHandle(forWritingAtPath: "/tmp/autoclicker.log") {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            try? h.close()
        } else {
            try? line.write(toFile: "/tmp/autoclicker.log", atomically: true, encoding: .utf8)
        }
    }

    static func click(_ type: ClickType) {
        let loc = CGEvent(source: nil)?.location ?? .zero
        func post(_ t: CGEventType, _ button: CGMouseButton, _ clicks: Int64) {
            let e = CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: loc, mouseButton: button)
            e?.setIntegerValueField(.mouseEventClickState, value: clicks)
            e?.post(tap: .cghidEventTap)
        }
        switch type {
        case .left:
            post(.leftMouseDown, .left, 1); usleep(20_000); post(.leftMouseUp, .left, 1)
        case .right:
            post(.rightMouseDown, .right, 1); usleep(20_000); post(.rightMouseUp, .right, 1)
        case .double:
            post(.leftMouseDown, .left, 1); usleep(20_000); post(.leftMouseUp, .left, 1)
            usleep(50_000)
            post(.leftMouseDown, .left, 2); usleep(20_000); post(.leftMouseUp, .left, 2)
        }
    }

    func registerHotkey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { ClickerState.shared.toggle() }
            return noErr
        }, 1, &spec, nil, nil)

        let id = EventHotKeyID(signature: OSType(0x4143_544B), id: 1) // 'ACTK'
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_F6), 0, id, GetApplicationEventTarget(), 0, &ref)
    }
}

struct ContentView: View {
    @ObservedObject var s = ClickerState.shared

    var body: some View {
        VStack(spacing: 20) {
            if !s.trusted {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                    Text("Accessibility permission needed")
                        .font(.callout)
                    Spacer()
                    Button("Fix") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(.red, in: RoundedRectangle(cornerRadius: 8))
            }

            Button {
                s.toggle()
            } label: {
                Text(s.clicking ? "Stop (F6)" : "Start (F6)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(s.clicking ? .red : .green)
            .keyboardShortcut(.space, modifiers: [])

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Interval")
                    Spacer()
                    TextField("500", value: $s.intervalMs, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    Text("ms").foregroundStyle(.secondary)
                    Stepper("", value: $s.intervalMs, in: 10...10_000, step: 50)
                        .labelsHidden()
                        .fixedSize()
                }
                Slider(value: $s.intervalMs, in: 10...2_000, step: 10)
                HStack(spacing: 8) {
                    ForEach([50.0, 100, 250, 500, 1_000], id: \.self) { ms in
                        chip(ms)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Picker("Click Type", selection: $s.clickType) {
                Text("Left").tag(ClickType.left)
                Text("Right").tag(ClickType.right)
                Text("Double").tag(ClickType.double)
            }
            .pickerStyle(.segmented)

            Text(s.clicking ? "Clicking every \(Int(s.intervalMs)) ms…" : "Stopped")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 320)
        .onAppear { s.trusted = AXIsProcessTrusted() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            s.trusted = AXIsProcessTrusted()
        }
    }

    @ViewBuilder private func chip(_ ms: Double) -> some View {
        let label = "\(Int(ms))"
        if Int(s.intervalMs) == Int(ms) {
            Button(label) { s.intervalMs = ms }.buttonStyle(.borderedProminent).controlSize(.small)
        } else {
            Button(label) { s.intervalMs = ms }.buttonStyle(.bordered).controlSize(.small)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ClickerState.shared.registerHotkey()

        // prompt for Accessibility permission on first launch if missing
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AutoclickerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("Autoclicker") {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
