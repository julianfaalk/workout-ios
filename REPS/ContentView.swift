import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutViewModel: WorkoutViewModel
    @EnvironmentObject var sessionViewModel: AppSessionViewModel
    @EnvironmentObject private var localization: LocalizationService
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if !localization.didChooseLanguage {
                LanguageGateView()
            } else {
                switch sessionViewModel.state {
                case .loading:
                    ProgressView(localization.localized("cloud.loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                case .signedOut:
                    AuthGateView()
                case .profileSetup:
                    ProfileSetupView()
                case .planReady:
                    OnboardingPlanReadyView()
                case .ready:
                    WorkoutMainTabView(selectedTab: $selectedTab)
                        .environmentObject(workoutViewModel)
                }
            }
        }
        .alert(localization.localized("common.error"), isPresented: Binding(
            get: { sessionViewModel.errorMessage != nil },
            set: { if !$0 { sessionViewModel.errorMessage = nil } }
        )) {
            Button(localization.localized("common.ok")) {
                sessionViewModel.errorMessage = nil
            }
        } message: {
            Text(sessionViewModel.errorMessage ?? "")
        }
        .task(id: sessionViewModel.state) {
            if sessionViewModel.state == .ready {
                await sessionViewModel.syncSnapshot()
            }
        }
        .onChange(of: sessionViewModel.pendingInviteCode) { _, pendingCode in
            guard pendingCode != nil, sessionViewModel.state == .ready else { return }
            selectedTab = 2
        }
        .onReceive(sessionViewModel.$requestedTab.compactMap { $0 }) { tab in
            guard sessionViewModel.state == .ready else { return }
            selectedTab = tab
        }
    }
}

private struct WorkoutMainTabView: View {
    @EnvironmentObject private var localization: LocalizationService
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label(localization.localized("tab.today"), systemImage: "sun.max")
                }
                .tag(0)

            ScheduleView()
                .tabItem {
                    Label(localization.localized("tab.schedule"), systemImage: "calendar")
                }
                .tag(1)

            FriendsView()
                .tabItem {
                    Label(localization.localized("tab.friends"), systemImage: "person.3.fill")
                }
                .tag(2)

            ProgressTabView()
                .tabItem {
                    Label(localization.localized("tab.progress"), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label(localization.localized("tab.profile"), systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .onAppear {
            if let requestedTab = sessionViewModel.requestedTab {
                selectedTab = requestedTab
            } else if sessionViewModel.pendingInviteCode != nil {
                selectedTab = 2
            }
        }
    }
}

private struct LanguageGateView: View {
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingPalette.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(localization.localized("language.title"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(OnboardingPalette.primaryText(for: colorScheme))
                        Text(localization.localized("language.subtitle"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(OnboardingPalette.secondaryText(for: colorScheme))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                localization.choose(language)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(language.displayName)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(OnboardingPalette.primaryText(for: colorScheme))
                                    Text(language.localeIdentifier)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(OnboardingPalette.secondaryText(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(18)
                                .background(OnboardingPalette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(OnboardingPalette.border(for: colorScheme), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutViewModel())
        .environmentObject(AppSessionViewModel())
        .environmentObject(StoreManager.shared)
        .environmentObject(LocalizationService.shared)
}
