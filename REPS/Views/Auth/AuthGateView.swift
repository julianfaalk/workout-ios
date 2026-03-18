import AuthenticationServices
import SwiftUI

enum OnboardingPalette {
    static let accent = Color(red: 0.12, green: 0.44, blue: 0.26)

    static func background(for colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.05, green: 0.08, blue: 0.07),
                    Color(red: 0.09, green: 0.13, blue: 0.11),
                    Color(red: 0.13, green: 0.19, blue: 0.16),
                ]
                : [
                    Color(red: 0.92, green: 0.97, blue: 0.93),
                    Color.white,
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func surface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.10, green: 0.13, blue: 0.12)
            : .white
    }

    static func elevatedSurface(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.17, blue: 0.15)
            : Color(.secondarySystemGroupedBackground)
    }

    static func primaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.96)
            : Color(red: 0.07, green: 0.11, blue: 0.09)
    }

    static func secondaryText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.70)
            : Color(red: 0.35, green: 0.41, blue: 0.38)
    }

    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }

    static func accentSoft(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? accent.opacity(0.22)
            : Color(red: 0.89, green: 0.96, blue: 0.90)
    }
}

struct AuthGateView: View {
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel
    @EnvironmentObject private var localization: LocalizationService
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEmailSheet = false
    @State private var email = ""
    @State private var magicLinkSent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeroPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text(localization.localized("auth.why_account"))
                            .font(.title3.weight(.bold))

                        FeatureRow(
                            title: localization.localized("auth.feature.cloud_metrics.title"),
                            subtitle: localization.localized("auth.feature.cloud_metrics.subtitle"),
                            icon: "externaldrive.badge.icloud"
                        )
                        FeatureRow(
                            title: localization.localized("auth.feature.premium.title"),
                            subtitle: localization.localized("auth.feature.premium.subtitle"),
                            icon: "crown.fill"
                        )
                        FeatureRow(
                            title: localization.localized("auth.feature.fast_login.title"),
                            subtitle: localization.localized("auth.feature.fast_login.subtitle"),
                            icon: "lock.shield.fill"
                        )
                    }

                    VStack(spacing: 12) {
                        SignInWithAppleButton(.signIn) { request in
                            let nonce = sessionViewModel.authService.prepareAppleSignIn()
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = nonce
                        } onCompletion: { result in
                            Task {
                                switch result {
                                case .success(let authResult):
                                    guard let credential = authResult.credential as? ASAuthorizationAppleIDCredential,
                                          let user = await sessionViewModel.authService.signInWithApple(credential: credential) else {
                                        sessionViewModel.errorMessage = sessionViewModel.authService.errorMessage
                                        return
                                    }
                                    await sessionViewModel.loginComplete(user: user)
                                case .failure(let error):
                                    sessionViewModel.errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Button {
                            Task {
                                guard let user = await sessionViewModel.authService.signInWithGoogle() else {
                                    sessionViewModel.errorMessage = sessionViewModel.authService.errorMessage
                                    return
                                }
                                await sessionViewModel.loginComplete(user: user)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: AppConfig.isGoogleSignInConfigured ? "globe" : "wrench.and.screwdriver.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(AppConfig.isGoogleSignInConfigured
                                     ? localization.localized("auth.google")
                                     : localization.localized("auth.google_pending"))
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .foregroundStyle(
                                AppConfig.isGoogleSignInConfigured
                                    ? OnboardingPalette.primaryText(for: colorScheme)
                                    : OnboardingPalette.secondaryText(for: colorScheme)
                            )
                            .background(OnboardingPalette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(OnboardingPalette.border(for: colorScheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!AppConfig.isGoogleSignInConfigured)

                        Button {
                            showEmailSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                Text(localization.localized("auth.email"))
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .foregroundStyle(OnboardingPalette.primaryText(for: colorScheme))
                            .background(OnboardingPalette.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(OnboardingPalette.border(for: colorScheme), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage = sessionViewModel.errorMessage ?? sessionViewModel.authService.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.red)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized("auth.legal_copy"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Link(localization.localized("auth.privacy"), destination: AppConfig.privacyURL)
                            Link(localization.localized("auth.terms"), destination: AppConfig.termsURL)
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                .padding(20)
            }
            .background(
                OnboardingPalette.background(for: colorScheme)
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .sheet(isPresented: $showEmailSheet) {
                EmailLoginSheet(
                    email: $email,
                    magicLinkSent: $magicLinkSent,
                    isLoading: sessionViewModel.authService.isLoading,
                    errorMessage: sessionViewModel.authService.errorMessage
                ) {
                    let sent = await sessionViewModel.authService.sendMagicLink(email: email)
                    magicLinkSent = sent
                }
            }
        }
    }
}

struct OnboardingPlanReadyView: View {
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel
    @EnvironmentObject private var localization: LocalizationService
    @State private var showingPaywall = false

    private var summary: OnboardingPlanSummary? {
        sessionViewModel.onboardingPlanSummary
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let summary {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localization.localized("plan.ready.title"))
                                .font(.system(size: 34, weight: .bold, design: .rounded))

                            Text(
                                localization.localized(
                                    "plan.ready.plan.detail",
                                    localization.localized(summary.goalFocus.planTitleKey),
                                    summary.sessionLengthMinutes
                                )
                            )
                            .font(.body)
                            .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 18) {
                            Text(localization.localized("plan.ready.card.title"))
                                .font(.headline.weight(.bold))

                            VStack(alignment: .leading, spacing: 10) {
                                Text(
                                    localization.localized(
                                        "plan.ready.plan.line",
                                        summary.trainingDaysPerWeek,
                                        localization.localized(summary.planStyle.titleKey)
                                    )
                                )
                                .font(.title3.weight(.bold))

                                Text(
                                    localization.localized(
                                        "plan.ready.plan.detail",
                                        localization.localized(summary.goalFocus.planTitleKey),
                                        summary.sessionLengthMinutes
                                    )
                                )
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                PlanReadyMetricCard(
                                    label: localization.localized("wizard.focus"),
                                    value: localization.localized(summary.goalFocus.titleKey)
                                )
                                PlanReadyMetricCard(
                                    label: localization.localized("wizard.training_days"),
                                    value: localization.localized("wizard.training_days.value", summary.trainingDaysPerWeek)
                                )
                                PlanReadyMetricCard(
                                    label: localization.localized("wizard.session_length"),
                                    value: "\(summary.sessionLengthMinutes) min"
                                )
                                PlanReadyMetricCard(
                                    label: localization.localized("wizard.level"),
                                    value: localizedExperienceLevel(summary.experienceLevel, localization: localization)
                                )
                                PlanReadyMetricCard(
                                    label: localization.localized("wizard.rotation"),
                                    value: localization.localized(summary.rotationStyle.titleKey)
                                )
                            }
                        }
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                        Text(localization.localized("plan.ready.footer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            showingPaywall = true
                        } label: {
                            Text(localization.localized("plan.ready.cta"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(.white)
                                .background(Color(red: 0.12, green: 0.44, blue: 0.26), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(24)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 320)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingPaywall) {
                if let summary {
                    PaywallView(
                        planSummary: summary,
                        allowsSkip: true,
                        showsCloseButton: false,
                        onSkip: {
                            sessionViewModel.completePostOnboardingOffer()
                        },
                        onPurchaseSuccess: {
                            sessionViewModel.completePostOnboardingOffer()
                        }
                    )
                }
            }
        }
    }
}

struct ProfileSetupView: View {
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel
    @EnvironmentObject private var localization: LocalizationService

    @State private var displayName = ""
    @State private var goal = ""
    @State private var selectedExperience = "Intermediate"
    @State private var currentStep = 0
    @State private var selectedGoalFocus: TrainingGoalFocus = .hypertrophy
    @State private var selectedRotationStyle: WorkoutRotationStyle = .balanced
    @State private var preferredSessionLengthMinutes = 60.0
    @State private var targetTrainingDaysPerWeek = 4.0
    @State private var workoutReminderEnabled = true
    @State private var workoutReminderTime = Calendar.current.date(from: DateComponents(hour: 18, minute: 30)) ?? Date()

    private let levels = ["Beginner", "Intermediate", "Advanced"]
    private let db = DatabaseService.shared

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(localization.localized("wizard.title"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(localization.localized("wizard.subtitle"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(index <= currentStep ? Color.blue : Color.secondary.opacity(0.15))
                                .frame(height: 8)
                        }
                    }

                    Text(stepTitle)
                        .font(.title3.weight(.bold))

                    Group {
                        switch currentStep {
                        case 0:
                            VStack(spacing: 14) {
                                LabeledField(title: localization.localized("wizard.name"), text: $displayName, prompt: "Julian")
                                LabeledField(title: localization.localized("wizard.goal"), text: $goal, prompt: localization.localized("wizard.goal.placeholder"))

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(localization.localized("wizard.level"))
                                        .font(.subheadline.weight(.semibold))
                                    Picker(localization.localized("wizard.level"), selection: $selectedExperience) {
                                        ForEach(levels, id: \.self) { level in
                                            Text(localizedLevel(level)).tag(level)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        case 1:
                            VStack(alignment: .leading, spacing: 18) {
                                Text(localization.localized("wizard.focus"))
                                    .font(.subheadline.weight(.semibold))

                                ForEach(TrainingGoalFocus.allCases) { focus in
                                    Button {
                                        selectedGoalFocus = focus
                                    } label: {
                                        WizardOptionRow(
                                            emoji: focusEmoji(for: focus),
                                            title: localization.localized(focus.titleKey),
                                            subtitle: localization.localized(focus.subtitleKey),
                                            isSelected: selectedGoalFocus == focus,
                                            tint: focusTint(for: focus)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(localization.localized("wizard.session_length"))
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("\(Int(preferredSessionLengthMinutes.rounded())) min")
                                            .font(.headline)
                                        Spacer()
                                        Text(localization.localized("wizard.session_length.caption"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $preferredSessionLengthMinutes, in: 35...105, step: 5)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(localization.localized("wizard.training_days"))
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text(localization.localized("wizard.training_days.value", Int(targetTrainingDaysPerWeek.rounded())))
                                            .font(.headline)
                                        Spacer()
                                        Text(localization.localized("wizard.training_days.caption"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $targetTrainingDaysPerWeek, in: 2...6, step: 1)
                                }
                            }
                        default:
                            VStack(alignment: .leading, spacing: 18) {
                                Text(localization.localized("wizard.rotation"))
                                    .font(.subheadline.weight(.semibold))

                                ForEach(WorkoutRotationStyle.allCases) { style in
                                    Button {
                                        selectedRotationStyle = style
                                    } label: {
                                        WizardOptionRow(
                                            emoji: rotationEmoji(for: style),
                                            title: localization.localized(style.titleKey),
                                            subtitle: localization.localized(style.subtitleKey),
                                            isSelected: selectedRotationStyle == style,
                                            tint: rotationTint(for: style)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Toggle(isOn: $workoutReminderEnabled) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(localization.localized("wizard.notifications.enable"))
                                            .font(.subheadline.weight(.semibold))
                                        Text(localization.localized("wizard.notifications.copy"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                if workoutReminderEnabled {
                                    DatePicker(
                                        localization.localized("wizard.notifications.time"),
                                        selection: $workoutReminderTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                if let errorMessage = sessionViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.red)
                }

                Spacer()

                HStack(spacing: 12) {
                    if currentStep > 0 {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                currentStep -= 1
                            }
                        } label: {
                            Text(localization.localized("common.back"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(.primary)
                                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                    }

                    Button {
                        if currentStep < 2 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                currentStep += 1
                            }
                        } else {
                            Task {
                                await completeWizard()
                            }
                        }
                    } label: {
                        HStack {
                            if sessionViewModel.isSyncing {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(
                                sessionViewModel.isSyncing
                                    ? localization.localized("wizard.saving")
                                    : currentStep < 2
                                        ? localization.localized("common.continue")
                                        : localization.localized("wizard.review_plan")
                            )
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.12, green: 0.44, blue: 0.26), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await seedWizardDefaults()
            }
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0:
            return localization.localized("wizard.step.profile")
        case 1:
            return localization.localized("wizard.step.focus")
        default:
            return localization.localized("wizard.step.notifications")
        }
    }

    private func completeWizard() async {
        var settings = (try? db.fetchSettings()) ?? AppSettings()
        settings.goalFocusValue = selectedGoalFocus
        settings.preferredSessionLengthMinutes = Int(preferredSessionLengthMinutes.rounded())
        settings.targetTrainingDaysPerWeek = Int(targetTrainingDaysPerWeek.rounded())
        settings.rotationStyleValue = selectedRotationStyle
        settings.workoutReminderEnabled = workoutReminderEnabled
        settings.workoutReminderTime = workoutReminderTime
        settings.preferredLanguageValue = localization.selectedLanguage

        if workoutReminderEnabled {
            let granted = await NotificationService.shared.requestPermission()
            if !granted {
                settings.workoutReminderEnabled = false
                sessionViewModel.errorMessage = localization.localized("wizard.notifications.denied")
            }
        }

        await sessionViewModel.completeOnboarding(
            displayName: displayName,
            goal: goal,
            experienceLevel: selectedExperience,
            localSettings: settings
        )
    }

    private func seedWizardDefaults() async {
        if let currentUser = sessionViewModel.currentUser {
            displayName = currentUser.resolvedDisplayName
            goal = currentUser.profile.goal
            if !currentUser.profile.experienceLevel.isEmpty {
                selectedExperience = currentUser.profile.experienceLevel
            }
        }

        guard let settings = try? db.fetchSettings() else { return }
        selectedGoalFocus = settings.goalFocusValue
        selectedRotationStyle = settings.rotationStyleValue
        preferredSessionLengthMinutes = Double(settings.preferredSessionLengthMinutes)
        targetTrainingDaysPerWeek = Double(settings.targetTrainingDaysPerWeek)
        workoutReminderEnabled = settings.workoutReminderEnabled
        workoutReminderTime = settings.workoutReminderTime
    }

    private func localizedLevel(_ rawLevel: String) -> String {
        localizedExperienceLevel(rawLevel, localization: localization)
    }

    private func focusEmoji(for focus: TrainingGoalFocus) -> String {
        switch focus {
        case .hypertrophy:
            return "💪"
        case .strength:
            return "🏋️"
        case .recomposition:
            return "⚡️"
        case .athletic:
            return "🧠"
        }
    }

    private func focusTint(for focus: TrainingGoalFocus) -> Color {
        switch focus {
        case .hypertrophy:
            return .green
        case .strength:
            return .orange
        case .recomposition:
            return .blue
        case .athletic:
            return .teal
        }
    }

    private func rotationEmoji(for style: WorkoutRotationStyle) -> String {
        switch style {
        case .conservative:
            return "🧱"
        case .balanced:
            return "🎯"
        case .aggressive:
            return "🌪️"
        }
    }

    private func rotationTint(for style: WorkoutRotationStyle) -> Color {
        switch style {
        case .conservative:
            return .green
        case .balanced:
            return .blue
        case .aggressive:
            return .orange
        }
    }
}

private struct WizardOptionRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 46, height: 46)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? tint : Color.secondary.opacity(0.45))
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? tint.opacity(0.45) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct HeroPanel: View {
    @EnvironmentObject private var localization: LocalizationService

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.localized("auth.hero.eyebrow"))
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
                .textCase(.uppercase)

            Text(localization.localized("auth.hero.title"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(localization.localized("auth.hero.subtitle"))
                .font(.callout)
                .foregroundStyle(.white.opacity(0.84))

            HStack(spacing: 10) {
                TagPill(label: localization.localized("auth.hero.tag.streak"))
                TagPill(label: localization.localized("auth.hero.tag.premium"))
                TagPill(label: localization.localized("auth.hero.tag.api"))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.20, blue: 0.15),
                    Color(red: 0.14, green: 0.44, blue: 0.25),
                    Color(red: 0.31, green: 0.61, blue: 0.38),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
    }
}

private struct FeatureRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingPalette.accent)
                .frame(width: 34, height: 34)
                .background(OnboardingPalette.accentSoft(for: colorScheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(OnboardingPalette.secondaryText(for: colorScheme))
            }

            Spacer()
        }
    }
}

private struct TagPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.14), in: Capsule())
            .foregroundStyle(.white)
    }
}

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct PlanReadyMetricCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

@MainActor
private func localizedExperienceLevel(_ rawLevel: String, localization: LocalizationService) -> String {
    switch rawLevel {
    case "Beginner":
        return localization.localized("wizard.level.beginner")
    case "Advanced":
        return localization.localized("wizard.level.advanced")
    default:
        return localization.localized("wizard.level.intermediate")
    }
}

extension TrainingGoalFocus {
    var titleKey: String {
        switch self {
        case .hypertrophy:
            return "goal.focus.hypertrophy.title"
        case .strength:
            return "goal.focus.strength.title"
        case .recomposition:
            return "goal.focus.recomposition.title"
        case .athletic:
            return "goal.focus.athletic.title"
        }
    }

    var planTitleKey: String {
        switch self {
        case .hypertrophy:
            return "goal.focus.hypertrophy.plan"
        case .strength:
            return "goal.focus.strength.plan"
        case .recomposition:
            return "goal.focus.recomposition.plan"
        case .athletic:
            return "goal.focus.athletic.plan"
        }
    }

    var subtitleKey: String {
        switch self {
        case .hypertrophy:
            return "goal.focus.hypertrophy.subtitle"
        case .strength:
            return "goal.focus.strength.subtitle"
        case .recomposition:
            return "goal.focus.recomposition.subtitle"
        case .athletic:
            return "goal.focus.athletic.subtitle"
        }
    }
}

extension WorkoutRotationStyle {
    var titleKey: String {
        switch self {
        case .conservative:
            return "rotation.style.stable.title"
        case .balanced:
            return "rotation.style.balanced.title"
        case .aggressive:
            return "rotation.style.fresh.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .conservative:
            return "rotation.style.stable.subtitle"
        case .balanced:
            return "rotation.style.balanced.subtitle"
        case .aggressive:
            return "rotation.style.fresh.subtitle"
        }
    }
}

extension OnboardingPlanStyle {
    var titleKey: String {
        switch self {
        case .pushPull:
            return "plan.style.push_pull"
        case .pushPullLegs:
            return "plan.style.push_pull_legs"
        case .pushPullLegsShoulders:
            return "plan.style.push_pull_legs_shoulders"
        case .highFrequencyPushPullLegs:
            return "plan.style.high_frequency"
        }
    }
}

private struct EmailLoginSheet: View {
    @Binding var email: String
    @Binding var magicLinkSent: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onSend: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localization: LocalizationService

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: magicLinkSent ? "paperplane.circle.fill" : "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(red: 0.12, green: 0.44, blue: 0.26))

                Text(magicLinkSent ? localization.localized("auth.email.sent") : localization.localized("auth.email.title"))
                    .font(.title2.weight(.bold))

                Text(
                    magicLinkSent
                    ? localization.localized("auth.email.sent_copy")
                    : localization.localized("auth.email.copy")
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                if !magicLinkSent {
                    TextField(localization.localized("auth.email.placeholder"), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task {
                            await onSend()
                        }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                }
                                Text(isLoading ? localization.localized("auth.email.sending") : localization.localized("auth.email.send"))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .foregroundStyle(.white)
                        .background(Color(red: 0.12, green: 0.44, blue: 0.26), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.localized("common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
