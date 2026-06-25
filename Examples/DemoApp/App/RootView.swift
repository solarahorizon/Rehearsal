// RootView.swift
// The demo's two screens: a tappable "Hello" → a celebratory "Demo Success!".
//
// Two UI tests reach the SAME success screen two different ways:
//   • the journey  — launch normally, tap Hello   (test_tapHello_revealsSuccess)
//   • the shortcut — launch SEEDED straight to success, no tap
//                    (test_seededStart_landsOnSuccess)  ← Mode B state-seeding,
//                    the whole point of the toolkit.
//
// Note: every animation here is FINITE (no `.repeatForever`). A never-ending
// animation keeps the app from going "idle", and XCUITest waits for idle before
// each step — so an infinite animation can hang your tests. Keep celebratory
// motion finite (or drive it with TimelineView). That's a real Rehearsal gotcha.
import SwiftUI

/// The screens the demo can show. State-seeding (Mode B) can boot straight to `.success`.
enum DemoState: String {
    case hello
    case success
}

struct RootView: View {
    @State private var state: DemoState
    @State private var ripple = false
    @State private var pop = false

    init(start: DemoState) {
        _state = State(initialValue: start)
    }

    var body: some View {
        Group {
            switch state {
            case .hello:   hello
            case .success: success
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: state)
    }

    // MARK: Hello — the whole screen is one tap target
    private var hello: some View {
        Button(action: reveal) {
            VStack(spacing: 14) {
                Text("👋").font(.system(size: 84))
                Text("Hello").font(.system(size: 46, weight: .bold))
                Text("tap anywhere").font(.headline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("demo.hello.tap.button")
        .overlay(rippleRing)
    }

    // a single finite "water ripple" ring that expands from the centre on tap
    private var rippleRing: some View {
        Circle()
            .stroke(Color.accentColor, lineWidth: 4)
            .frame(width: 64, height: 64)
            .scaleEffect(ripple ? 16 : 0.1)
            .opacity(ripple ? 0 : 0.85)
            .allowsHitTesting(false)
    }

    // MARK: Success — the rainbow payoff
    private var success: some View {
        VStack(spacing: 18) {
            Text("🎉").font(.system(size: 80))
            Text("Demo Success!")
                .font(.system(size: 42, weight: .heavy))
                .foregroundStyle(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                        center: .center
                    )
                )
                .accessibilityIdentifier("demo.success.title.label")
            Text("two tests, one green run")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(pop ? 1 : 0.6)
        .opacity(pop ? 1 : 0)
        .onAppear {
            // finite spring "pop" — celebratory, but it settles so the app idles
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { pop = true }
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.55)) { ripple = true }
        // flip to success mid-ripple for a smooth hand-off
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            state = .success
        }
    }
}
