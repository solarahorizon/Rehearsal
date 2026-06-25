// RootView.swift
// Two screens (onboarding → counter) so a UI test can assert navigation AND
// seeded state. The seeded starting values arrive from App.init() (the seam);
// this view just renders them. Accessibility ids follow Rehearsal's 4-segment
// convention `<app-prefix>.<feature>.<element>.<state>` — see Docs/ACCESSIBILITY_IDS.md.
import SwiftUI

struct RootView: View {
    @State private var showOnboarding: Bool
    @State private var count: Int

    init(startOnboarding: Bool, startCount: Int) {
        _showOnboarding = State(initialValue: startOnboarding)
        _count = State(initialValue: startCount)
    }

    var body: some View {
        if showOnboarding {
            OnboardingView { showOnboarding = false }
        } else {
            CounterView(count: $count)
        }
    }
}

struct OnboardingView: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Rehearsal Demo")
                .font(.title2)
                .accessibilityIdentifier("demo.onboarding.title.label")
            Button("Get Started", action: onStart)
                .accessibilityIdentifier("demo.onboarding.start.button")
        }
        .padding()
    }
}

struct CounterView: View {
    @Binding var count: Int
    var body: some View {
        VStack(spacing: 24) {
            Text("\(count)")
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()
                .accessibilityIdentifier("demo.counter.value.label")
            Button("Increment") { count += 1 }
                .accessibilityIdentifier("demo.counter.increment.button")
        }
        .padding()
    }
}
