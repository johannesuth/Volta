import AppKit
import SwiftUI
import VoltaLanguageCore

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

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
                         styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Volta"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentViewController = NSHostingController(rootView: OnboardingView { [weak self] in
            self?.window?.close()
            self?.window = nil
            onFinished()
        })
        w.center()
        window = w
        NSApp.activate()
        w.makeKeyAndOrderFront(nil)
    }
}

private struct OnboardingView: View {
    @State private var language = ConfigStore.shared.c.language
    @State private var page = 0
    @State private var soundOn = true
    @State private var orbiting = false
    var onFinished: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= page ? Color.cyan : Color.white.opacity(0.15))
                        .frame(width: index == page ? 28 : 12, height: 4)
                        .animation(.spring(duration: 0.35), value: page)
                }
                Spacer()
                Text("GETTING STARTED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(.top, 26)
            .padding(.horizontal, 30)

            Spacer(minLength: 14)
            hero
                .frame(height: 145)
                .padding(.bottom, 12)

            Group {
                switch page {
                case 0: languagePage
                case 1: overviewPage
                default: finishPage
                }
            }
            .id(page)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .frame(maxWidth: .infinity, minHeight: 190)

            Spacer(minLength: 14)
            HStack(spacing: 12) {
                if page > 0 {
                    Button("Back") { withAnimation(.spring(duration: 0.38)) { page -= 1 } }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.7))
                } else {
                    Color.clear.frame(width: 74, height: 1)
                }
                Spacer()
                Button {
                    if page < 2 {
                        withAnimation(.spring(duration: 0.38)) { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(page == 2 ? "Start using Volta" : "Continue")
                        Image(systemName: page == 2 ? "arrow.right" : "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.cyan)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 28)
        }
        .frame(width: 560, height: 520)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(red: 0.055, green: 0.09, blue: 0.16),
                                        Color(red: 0.025, green: 0.035, blue: 0.07)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color.cyan.opacity(0.13))
                    .frame(width: 260, height: 260)
                    .blur(radius: 70)
                    .offset(x: 80, y: -100)
            }
            .ignoresSafeArea()
        }
        .foregroundStyle(.white)
        .environment(\.locale, Locale(identifier: language.localeIdentifier))
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) { orbiting = true }
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.13), lineWidth: 1)
                .frame(width: 132, height: 132)
            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(AngularGradient(colors: [.cyan.opacity(0.05), .cyan, .blue.opacity(0.75), .cyan.opacity(0.05)],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(orbiting ? 360 : 0))
            Circle()
                .fill(LinearGradient(colors: [Color.cyan.opacity(0.19), Color.blue.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 94, height: 94)
                .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
            Image(systemName: page == 0 ? "character.bubble.fill" : (page == 1 ? "battery.100percent" : "sparkles"))
                .font(.system(size: 35, weight: .medium))
                .foregroundStyle(LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse, options: .repeating)
            Circle()
                .fill(Color.cyan)
                .frame(width: 6, height: 6)
                .shadow(color: .cyan, radius: 8)
                .offset(x: orbiting ? 72 : -72, y: orbiting ? -34 : 34)
        }
        .animation(.spring(duration: 0.45), value: page)
        .accessibilityHidden(true)
    }

    private var languagePage: some View {
        VStack(spacing: 14) {
            Text("Choose your language")
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text("Pick the language Volta will use throughout the app. You can change it later in Settings.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            Picker("App language", selection: $language) {
                ForEach(AppLanguage.allCases) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            .padding(.top, 8)
        }
    }

    private var overviewPage: some View {
        VStack(spacing: 12) {
            Text("Your Mac's power, at a glance")
                .font(.system(size: 25, weight: .bold, design: .rounded))
            Text("Volta lives in the menu bar and keeps useful battery details close by.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            HStack(spacing: 10) {
                feature("waveform.path", title: "Live power", detail: "Charge, draw and battery health")
                feature("chart.xyaxis.line", title: "History", detail: "On-device trends and export")
                feature("headphones", title: "Accessories", detail: "Battery levels when available")
            }
            .padding(.top, 8)
        }
    }

    private var finishPage: some View {
        VStack(spacing: 12) {
            Text("Make Volta yours")
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text("Your readings stay on this Mac. No account or cloud sync is required.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            Toggle("Play a welcome sound", isOn: $soundOn)
                .toggleStyle(.switch)
                .frame(maxWidth: 270)
                .padding(.top, 10)
            Text("You can adjust alerts, appearance and measurements in Settings at any time.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
        }
    }

    private func feature(_ symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)
            Text(title).font(.system(size: 11, weight: .semibold))
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .padding(9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func finish() {
        var config = ConfigStore.shared.c
        config.language = language
        config.languageChosen = true
        config.onboarded = true
        ConfigStore.shared.c = config
        if soundOn { Chime.ring("Glass", gain: 0.6, force: true) }
        onFinished()
    }
}
