// RootView.swift
// The demo's two screens: a tappable "Hello" → a celebratory "Demo Success!",
// over a futuristic, slowly-rotating neon backdrop.
//
// Two UI tests reach the SAME success screen two different ways:
//   • the journey  — launch normally, tap Hello   (test_tapHello_revealsSuccess)
//   • the shortcut — launch SEEDED straight to success, no tap
//                    (test_seededStart_landsOnSuccess)  ← Mode B state-seeding.
//
// ANIMATION + TESTING — the important bit:
// The backdrop runs CONTINUOUS motion (a 360° rotation + a breathing zoom). A
// never-ending animation keeps the app from ever going "idle", and XCUITest waits
// for idle before every step — so it would hang the tests. The fix is the seam:
// the tests pass `--reduce-motion`, which freezes the continuous motion. So the
// app stays beautiful in normal use AND stays testable. That's a real pattern for
// UI-testing animated apps, demonstrated end-to-end here.
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
    @State private var spin = false      // continuous 360° (gated by reduceMotion)
    @State private var breathe = false   // continuous zoom in/out (gated)
    private let reduceMotion: Bool

    /// cyan → blue → purple → magenta "neon" gradient, reused for glow.
    private let neon = LinearGradient(
        colors: [Color(red: 0.0, green: 0.92, blue: 1.0),
                 Color(red: 0.42, green: 0.5, blue: 1.0),
                 Color(red: 0.72, green: 0.3, blue: 1.0),
                 Color(red: 1.0, green: 0.25, blue: 0.7)],
        startPoint: .leading, endPoint: .trailing)

    init(start: DemoState, reduceMotion: Bool) {
        _state = State(initialValue: start)
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        ZStack {
            background
            ambient            // continuous rotating/breathing neon rings
            Group {
                switch state {
                case .hello:   hello
                case .success: success
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: state)
        .onAppear(perform: startAmbient)
    }

    private var background: some View {
        RadialGradient(
            colors: [Color(red: 0.06, green: 0.09, blue: 0.18),
                     Color(red: 0.02, green: 0.02, blue: 0.06)],
            center: .center, startRadius: 5, endRadius: 460)
            .ignoresSafeArea()
    }

    // the "modern website" backdrop: concentric neon rings that slowly rotate 360°
    // and gently breathe (zoom in/out). Frozen when reduceMotion is on (tests).
    private var ambient: some View {
        ZStack {
            Circle().stroke(neon, lineWidth: 2).frame(width: 320, height: 320).blur(radius: 2).opacity(0.30)
            Circle().stroke(neon, lineWidth: 1.5).frame(width: 215, height: 215).opacity(0.22)
            Circle().stroke(neon, lineWidth: 1).frame(width: 120, height: 120).opacity(0.15)
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .scaleEffect(breathe ? 1.12 : 0.9)
        .allowsHitTesting(false)
    }

    private func startAmbient() {
        guard !reduceMotion else { return }   // ← the seam keeps the test idle-able
        withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) { spin = true }
        withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { breathe = true }
    }

    // MARK: Hello — the whole screen is one tap target
    private var hello: some View {
        Button(action: reveal) {
            VStack(spacing: 18) {
                Text("👋").font(.system(size: 80))
                Text("Hello")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(neon)
                    .shadow(color: Color(red: 0.2, green: 0.8, blue: 1).opacity(0.55), radius: 14)
                Text("tap anywhere")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("demo.hello.tap.button")
        .overlay(rippleRing)
    }

    // a single finite "energy ripple" ring that expands from the centre on tap
    private var rippleRing: some View {
        Circle()
            .stroke(neon, lineWidth: 4)
            .frame(width: 70, height: 70)
            .scaleEffect(ripple ? 16 : 0.1)
            .opacity(ripple ? 0 : 0.9)
            .allowsHitTesting(false)
    }

    // MARK: Success — the neon payoff (finite warp-in entrance)
    private var success: some View {
        ZStack {
            Circle()
                .stroke(neon, lineWidth: 3)
                .frame(width: 90, height: 90)
                .scaleEffect(pop ? 4.4 : 0.2)
                .opacity(pop ? 0 : 0.85)

            VStack(spacing: 20) {
                Text("🎉").font(.system(size: 76))
                Text("Demo Success!")
                    .font(.system(size: 42, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(neon)
                    .shadow(color: Color(red: 0.3, green: 0.85, blue: 1).opacity(0.7), radius: 20)
                    .accessibilityIdentifier("demo.success.title.label")
                Text("two tests, one green run")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .scaleEffect(pop ? 1 : 0.7)
            .opacity(pop ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // finite spring "warp-in" — settles, so the app idles even under test
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { pop = true }
        }
    }

    private func reveal() {
        withAnimation(.easeOut(duration: 0.55)) { ripple = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            state = .success
        }
    }
}
