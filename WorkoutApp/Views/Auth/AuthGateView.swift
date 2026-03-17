import AuthenticationServices
import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel

    @State private var showEmailSheet = false
    @State private var email = ""
    @State private var magicLinkSent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeroPanel()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Warum mit Konto?")
                            .font(.title3.weight(.bold))

                        FeatureRow(
                            title: "Permanent gesicherte Kennzahlen",
                            subtitle: "Workout-Streak, letzter Trainingsstand und Profil bleiben ueber Geraetewechsel erhalten.",
                            icon: "externaldrive.badge.icloud"
                        )
                        FeatureRow(
                            title: "Premium und App Store ready",
                            subtitle: "Abo-Status, Account-Loeschung und rechtliche Links sind direkt in den Flow integriert.",
                            icon: "crown.fill"
                        )
                        FeatureRow(
                            title: "Schneller Login",
                            subtitle: "Apple sofort, E-Mail per Magic Link, Google vorbereitet fuer die dedizierte Client-ID.",
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
                                Text(AppConfig.isGoogleSignInConfigured ? "Mit Google anmelden" : "Google folgt nach OAuth-Setup")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .foregroundStyle(AppConfig.isGoogleSignInConfigured ? Color.primary : Color.secondary)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
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
                                Text("Mit E-Mail anmelden")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal, 18)
                            .frame(height: 56)
                            .foregroundStyle(Color.primary)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
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
                        Text("Mit dem Login stimmst du Datenschutz und Nutzungsbedingungen zu.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Link("Datenschutz", destination: AppConfig.privacyURL)
                            Link("Nutzungsbedingungen", destination: AppConfig.termsURL)
                        }
                        .font(.footnote.weight(.semibold))
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.97, blue: 0.94),
                        Color.white,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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

struct ProfileSetupView: View {
    @EnvironmentObject private var sessionViewModel: AppSessionViewModel

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
                    Text("Mach dein Profil startklar")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Wir bauen dir einmal sauber dein Trainings-Setup. Neue Konten bekommen damit direkt Rotation, Reminder und einen klaren Fokus fuer den Start.")
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
                                LabeledField(title: "Name", text: $displayName, prompt: "Julian")
                                LabeledField(title: "Trainingsziel", text: $goal, prompt: "Muskelaufbau, Fettverlust, Routine ...")

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Level")
                                        .font(.subheadline.weight(.semibold))
                                    Picker("Level", selection: $selectedExperience) {
                                        ForEach(levels, id: \.self) { level in
                                            Text(level).tag(level)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        case 1:
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Worauf soll die App optimieren?")
                                    .font(.subheadline.weight(.semibold))

                                ForEach(TrainingGoalFocus.allCases) { focus in
                                    Button {
                                        selectedGoalFocus = focus
                                    } label: {
                                        WizardOptionRow(
                                            emoji: focusEmoji(for: focus),
                                            title: focus.title,
                                            subtitle: focus.subtitle,
                                            isSelected: selectedGoalFocus == focus,
                                            tint: focusTint(for: focus)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Geplante Session-Laenge")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("\(Int(preferredSessionLengthMinutes.rounded())) min")
                                            .font(.headline)
                                        Spacer()
                                        Text("Kurz bis fokussiert lang")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $preferredSessionLengthMinutes, in: 35...105, step: 5)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trainings-Tage pro Woche")
                                        .font(.subheadline.weight(.semibold))
                                    HStack {
                                        Text("\(Int(targetTrainingDaysPerWeek.rounded())) Tage")
                                            .font(.headline)
                                        Spacer()
                                        Text("Damit Goals und Calendar dazu passen")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Slider(value: $targetTrainingDaysPerWeek, in: 2...6, step: 1)
                                }
                            }
                        default:
                            VStack(alignment: .leading, spacing: 18) {
                                Text("Wie frisch sollen die Uebungen rotieren?")
                                    .font(.subheadline.weight(.semibold))

                                ForEach(WorkoutRotationStyle.allCases) { style in
                                    Button {
                                        selectedRotationStyle = style
                                    } label: {
                                        WizardOptionRow(
                                            emoji: rotationEmoji(for: style),
                                            title: style.title,
                                            subtitle: style.subtitle,
                                            isSelected: selectedRotationStyle == style,
                                            tint: rotationTint(for: style)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                Toggle(isOn: $workoutReminderEnabled) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Workout-Reminder aktivieren")
                                            .font(.subheadline.weight(.semibold))
                                        Text("Schickt dir lokale Notifications fuer deine geplanten Trainingstage.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .toggleStyle(.switch)

                                if workoutReminderEnabled {
                                    DatePicker(
                                        "Reminder-Zeit",
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
                            Text("Zurueck")
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
                            Text(sessionViewModel.isSyncing ? "Setup wird gespeichert ..." : currentStep < 2 ? "Weiter" : "Weiter zur App")
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
            return "Profil"
        case 1:
            return "Trainings-Fokus"
        default:
            return "Rotation & Reminder"
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

        if workoutReminderEnabled {
            let granted = await NotificationService.shared.requestPermission()
            if !granted {
                settings.workoutReminderEnabled = false
                sessionViewModel.errorMessage = "Mitteilungen sind aktuell nicht erlaubt. Die App startet trotzdem und du kannst Reminder spaeter in den Einstellungen aktivieren."
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
        guard let settings = try? db.fetchSettings() else { return }
        selectedGoalFocus = settings.goalFocusValue
        selectedRotationStyle = settings.rotationStyleValue
        preferredSessionLengthMinutes = Double(settings.preferredSessionLengthMinutes)
        targetTrainingDaysPerWeek = Double(settings.targetTrainingDaysPerWeek)
        workoutReminderEnabled = settings.workoutReminderEnabled
        workoutReminderTime = settings.workoutReminderTime
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
            return .purple
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
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Workout App Cloud")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.74))
                .textCase(.uppercase)

            Text("Trainieren, sichern, spaeter weitermachen.")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Apple Login ist sofort einsatzbereit. E-Mail und Premium laufen ueber deine eigene Workout-API und MongoDB.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.84))

            HStack(spacing: 10) {
                TagPill(label: "Streak Sync")
                TagPill(label: "Premium Ready")
                TagPill(label: "Own API")
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
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.12, green: 0.44, blue: 0.26))
                .frame(width: 34, height: 34)
                .background(Color(red: 0.89, green: 0.96, blue: 0.90), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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

private struct EmailLoginSheet: View {
    @Binding var email: String
    @Binding var magicLinkSent: Bool
    let isLoading: Bool
    let errorMessage: String?
    let onSend: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: magicLinkSent ? "paperplane.circle.fill" : "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(red: 0.12, green: 0.44, blue: 0.26))

                Text(magicLinkSent ? "Magic Link gesendet" : "E-Mail Login")
                    .font(.title2.weight(.bold))

                Text(
                    magicLinkSent
                    ? "Pruefe dein Postfach. Der Link oeffnet die Workout App direkt auf diesem iPhone."
                    : "Wir schicken dir einen einmaligen Login-Link an deine E-Mail-Adresse."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                if !magicLinkSent {
                    TextField("deine@email.de", text: $email)
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
                            Text(isLoading ? "Wird gesendet ..." : "Login-Link senden")
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
                    Button("Schliessen") {
                        dismiss()
                    }
                }
            }
        }
    }
}
