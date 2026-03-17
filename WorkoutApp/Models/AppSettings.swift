import Foundation
import GRDB

enum TrainingGoalFocus: String, CaseIterable, Identifiable, Codable {
    case hypertrophy
    case strength
    case recomposition
    case athletic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hypertrophy:
            return "Muscle"
        case .strength:
            return "Strength"
        case .recomposition:
            return "Lean"
        case .athletic:
            return "Athletic"
        }
    }

    var subtitle: String {
        switch self {
        case .hypertrophy:
            return "Mehr Volumen, sauberer Pump und progressive Hypertrophie."
        case .strength:
            return "Mehr Fokus auf Hauptlifts, Kraft und klare Leistungssteigerung."
        case .recomposition:
            return "Starker Mix aus Performance, Volumen und Kalorienkontrolle."
        case .athletic:
            return "Leistung, Energie, Core und robuste Ganzkoerper-Performance."
        }
    }
}

enum WorkoutRotationStyle: String, CaseIterable, Identifiable, Codable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conservative:
            return "Stable"
        case .balanced:
            return "Balanced"
        case .aggressive:
            return "Fresh"
        }
    }

    var subtitle: String {
        switch self {
        case .conservative:
            return "Haelt Assistenz-Uebungen laenger stabil, damit Fortschritt messbar bleibt."
        case .balanced:
            return "Wechselt smart zwischen Progression und frischen Reizen."
        case .aggressive:
            return "Mehr Variation bei jeder neuen Session fuer maximale Abwechslung."
        }
    }

    var cadenceSessions: Int {
        switch self {
        case .conservative:
            return 3
        case .balanced:
            return 2
        case .aggressive:
            return 1
        }
    }
}

struct AppSettings {
    var defaultRestTime: Int = 90
    var workoutReminderEnabled: Bool = false
    var workoutReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var restTimerSound: Bool = true
    var restTimerHaptic: Bool = true
    var weekStartsOn: Int = 1 // 0 = Sunday, 1 = Monday
    var trainingSetupCompleted: Bool = false
    var goalFocus: String = TrainingGoalFocus.hypertrophy.rawValue
    var preferredSessionLengthMinutes: Int = 60
    var targetTrainingDaysPerWeek: Int = 4
    var rotationStyle: String = WorkoutRotationStyle.balanced.rawValue

    static let defaultRestTimeKey = "defaultRestTime"
    static let workoutReminderEnabledKey = "workoutReminderEnabled"
    static let workoutReminderTimeKey = "workoutReminderTime"
    static let restTimerSoundKey = "restTimerSound"
    static let restTimerHapticKey = "restTimerHaptic"
    static let weekStartsOnKey = "weekStartsOn"
    static let trainingSetupCompletedKey = "trainingSetupCompleted"
    static let goalFocusKey = "goalFocus"
    static let preferredSessionLengthMinutesKey = "preferredSessionLengthMinutes"
    static let targetTrainingDaysPerWeekKey = "targetTrainingDaysPerWeek"
    static let rotationStyleKey = "rotationStyle"

    var goalFocusValue: TrainingGoalFocus {
        get { TrainingGoalFocus(rawValue: goalFocus) ?? .hypertrophy }
        set { goalFocus = newValue.rawValue }
    }

    var rotationStyleValue: WorkoutRotationStyle {
        get { WorkoutRotationStyle(rawValue: rotationStyle) ?? .balanced }
        set { rotationStyle = newValue.rawValue }
    }
}

struct SettingEntry: Codable, Hashable {
    var key: String
    var value: String
}

// MARK: - GRDB Support
extension SettingEntry: FetchableRecord, PersistableRecord {
    static let databaseTableName = "settings"

    enum Columns: String, ColumnExpression {
        case key, value
    }

    init(row: Row) throws {
        key = try row[Columns.key]
        value = try row[Columns.value]
    }

    func encode(to container: inout PersistenceContainer) throws {
        container[Columns.key] = key
        container[Columns.value] = value
    }
}
