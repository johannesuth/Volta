import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications
import VoltaLanguageCore

// MARK: - Permission state

/// Where one permission stands, in the terms the setup screen needs.
enum Grant: Equatable {
    /// Not asked yet.
    case unknown
    case granted
    /// macOS wants the user to confirm it in System Settings.
    case pending
    case denied

    init(notifications status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .unknown
        case .denied: self = .denied
        default: self = .granted            // authorized, provisional, ephemeral
        }
    }

    init(login status: SMAppService.Status) {
        switch status {
        case .enabled: self = .granted
        case .requiresApproval: self = .pending
        case .notRegistered: self = .unknown
        default: self = .denied             // notFound: macOS can't register this copy
        }
    }
}

/// The two permissions Volta asks for before it starts: open at login and notifications.
struct SetupChecklist: Equatable {
    var notifications: Grant
    var login: Grant

    /// Something hasn't been asked yet, so the main button still reads "Allow".
    var needsRequest: Bool { notifications == .unknown || login == .unknown }
    var allGranted: Bool { notifications == .granted && login == .granted }

    @MainActor
    static func current() async -> SetupChecklist {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return SetupChecklist(notifications: Grant(notifications: settings.authorizationStatus),
                              login: Grant(login: SMAppService.mainApp.status))
    }
}

// MARK: - Window

/// First-run setup. Volta's menu-bar item appears only after this window is finished.
@MainActor
final class OnboardingWindow {
    static let shared = OnboardingWindow()
    private var window: NSWindow?

    func show(onFinished: @escaping () -> Void) {
        if let window {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                         styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        w.title = "Volta"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            w.standardWindowButton(button)?.isHidden = true
        }
        w.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
            onFinished()
        })
        w.setContentSize(NSSize(width: 480, height: 560))
        w.center()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }

    func bringToFront() {
        guard let window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Steps

private struct OnboardingView: View {
    @Bindable private var store = ConfigStore.shared
    @State private var page = 0
    @State private var checklist = SetupChecklist(notifications: .unknown, login: .unknown)
    @State private var asking = false
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Hue.accent : Color.secondary.opacity(0.25))
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }
            .animation(.spring(duration: 0.35), value: page)
            .padding(.top, 40)

            ZStack {
                switch page {
                case 0: welcome
                case 1: permissions
                default: ready
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 34)

            footer
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
        .frame(width: 480, height: 560)
        .background(alignment: .top) {
            LinearGradient(colors: [Hue.accent.opacity(0.2), Hue.accent.opacity(0)], startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
        }
        .ignoresSafeArea(edges: .top)
        .environment(\.locale, Locale(identifier: store.c.language.localeIdentifier))
        .tint(Hue.accent)
        .task { checklist = await SetupChecklist.current() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { checklist = await SetupChecklist.current() }
        }
    }

    // MARK: Step 1 – welcome and language

    private var welcome: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 108, height: 108)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            Text(Copy.text("Willkommen bei Volta", "Welcome to Volta"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(Copy.text("Akku, Akkuzustand und Energieverbrauch – direkt in deiner Menüleiste.",
                           "Battery, battery health and energy use, right in your menu bar."))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                Text(Copy.text("Sprache", "Language"))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker(selection: $store.c.language) {
                    Text(verbatim: "Deutsch").tag(AppLanguage.german)
                    Text(verbatim: "English").tag(AppLanguage.english)
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }
            .padding(.top, 16)
            Spacer(minLength: 0)
        }
    }

    // MARK: Step 2 – permissions

    private var permissions: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Hue.accent.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Hue.accent.opacity(0.35), radius: 10, y: 4)
            Text(Copy.text("Zwei kurze Freigaben", "Two quick permissions"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(Copy.text("Damit Volta mit deinem Mac startet und dich rechtzeitig erinnern kann.",
                           "So Volta starts with your Mac and can remind you in time."))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                PermissionRow(symbol: "power",
                              title: Copy.text("Beim Anmelden starten", "Open at login"),
                              detail: Copy.text("Volta ist nach jedem Neustart sofort da.",
                                                "Volta is there right after every restart."),
                              grant: checklist.login, ask: askLogin, fix: LoginItem.openSystemSettings)
                Divider().padding(.leading, 44)
                PermissionRow(symbol: "bell.badge.fill",
                              title: Copy.text("Mitteilungen", "Notifications"),
                              detail: Copy.text("Damit Volta dir Warnungen als Mitteilung schicken darf.",
                                                "Lets Volta send you alerts as notifications."),
                              grant: checklist.notifications, ask: { Task { await askNotifications() } },
                              fix: openNotificationSettings)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.primary.opacity(0.08), lineWidth: 1))
            .padding(.top, 6)
            .animation(.spring(duration: 0.3), value: checklist)

            Text(Copy.text("Beides kannst du jederzeit in den Einstellungen ändern.",
                           "You can change both in Settings at any time."))
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
    }

    // MARK: Step 3 – ready

    private var ready: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            MenuBarStrip()
                .padding(.bottom, 6)
            Text(Copy.text("Alles bereit", "You're all set"))
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(Copy.text("Volta sitzt gleich oben in deiner Menüleiste.", "Volta will sit at the top of your menu bar."))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 12) {
                tip("cursorarrow.click", Copy.text("Klick auf die Batterie, um das Dashboard zu öffnen.",
                                                   "Click the battery to open the dashboard."))
                tip("command", Copy.text("Oder drück \(store.c.shortcut.label) – aus jeder App.",
                                         "Or press \(store.c.shortcut.label) from any app."))
                tip("gearshape.fill", Copy.text("Die Einstellungen findest du über das Zahnrad im Dashboard.",
                                                "Settings are behind the gear icon in the dashboard."))
            }
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    private func tip(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Hue.accent)
                .frame(width: 28, height: 28)
                .background(Hue.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer and actions

    private var footer: some View {
        HStack(spacing: 14) {
            if page > 0 {
                Button(Copy.text("Zurück", "Back")) { go(to: page - 1) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if page == 1 && checklist.needsRequest {
                Button(Copy.text("Später", "Later")) { go(to: 2) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            Button(action: primary) {
                HStack(spacing: 6) {
                    if asking { ProgressView().controlSize(.small) }
                    Text(primaryTitle)
                }
                .frame(minWidth: 130)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: Copy.text("Weiter", "Continue")
        case 1: checklist.needsRequest ? Copy.text("Erlauben", "Allow") : Copy.text("Weiter", "Continue")
        default: Copy.text("Volta starten", "Start Volta")
        }
    }

    private func primary() {
        switch page {
        case 0: go(to: 1)
        case 1:
            if checklist.needsRequest { Task { await askAll() } } else { go(to: 2) }
        default: finish()
        }
    }

    private func go(to target: Int) {
        withAnimation(.spring(duration: 0.4)) { page = min(max(target, 0), 2) }
    }

    private func askLogin() {
        try? LoginItem.set(true)
        Task { checklist = await SetupChecklist.current() }
    }

    private func askNotifications() async {
        guard !asking else { return }
        asking = true
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        checklist = await SetupChecklist.current()
        asking = false
    }

    /// The main button: ask for everything still open, then move on once nothing is left to ask.
    private func askAll() async {
        if checklist.login == .unknown { try? LoginItem.set(true) }
        if checklist.notifications == .unknown { await askNotifications() }
        checklist = await SetupChecklist.current()
        guard !checklist.needsRequest, page == 1 else { return }
        try? await Task.sleep(for: .milliseconds(700))     // let the check marks show
        if page == 1 { go(to: 2) }
    }

    private func openNotificationSettings() {
        let id = Bundle.main.bundleIdentifier ?? "com.johannesuth.volta"
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func finish() {
        var config = ConfigStore.shared.c
        config.languageChosen = true
        config.onboarded = true
        ConfigStore.shared.c = config
        onFinished()
    }
}

// MARK: - Pieces

private struct PermissionRow: View {
    let symbol: String
    let title: String
    let detail: String
    let grant: Grant
    let ask: () -> Void
    let fix: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Hue.accent.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 11)
    }

    private var note: String {
        switch grant {
        case .pending: Copy.text("Bitte in den Systemeinstellungen bestätigen.", "Please confirm in System Settings.")
        case .denied: Copy.text("Abgelehnt – in den Systemeinstellungen änderbar.", "Declined – you can change this in System Settings.")
        default: detail
        }
    }

    @ViewBuilder private var trailing: some View {
        switch grant {
        case .granted:
            Label(Copy.text("Erlaubt", "Allowed"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Hue.good)
                .transition(.scale.combined(with: .opacity))
        case .unknown:
            Button(Copy.text("Erlauben", "Allow"), action: ask)
        case .pending:
            Button(Copy.text("Bestätigen …", "Confirm …"), action: fix)
        case .denied:
            Button(Copy.text("Öffnen …", "Open …"), action: fix)
        }
    }
}

/// A small dark menu bar with Volta's battery in it, so new users know where to look.
private struct MenuBarStrip: View {
    private let store = ConfigStore.shared

    var body: some View {
        var s = Telemetry.shared.now
        if !s.hasPack || s.level <= 0 { s.hasPack = true; s.level = 80 }
        let image = GlyphPainter.image(snapshot: s, clock: nil, cfg: store.c, darkBar: true, badges: [])
        return HStack(spacing: 16) {
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(nsImage: image)
                .renderingMode(image.isTemplate ? .template : .original)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Hue.accent, lineWidth: 1.5))
            Text(Date.now, style: .time)
                .monospacedDigit()
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 18)
        .frame(height: 34)
        .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .accessibilityHidden(true)
    }
}
