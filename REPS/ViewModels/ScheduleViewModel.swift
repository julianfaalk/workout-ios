import Foundation
import SwiftUI

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var scheduleDays: [ScheduleDay] = []
    @Published var templates: [WorkoutTemplate] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var weekStartsOn: Int = 1

    private let db = DatabaseService.shared

    init() {
        Task {
            await loadSchedule()
            await loadTemplates()
            await loadSettings()
        }
    }

    func loadSchedule() async {
        isLoading = true
        do {
            scheduleDays = try db.fetchScheduleWithTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadTemplates() async {
        do {
            templates = try db.fetchAllTemplates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSettings() async {
        do {
            let settings = try db.fetchSettings()
            weekStartsOn = settings.weekStartsOn
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignTemplate(dayOfWeek: Int, templateId: UUID?) async -> Bool {
        do {
            let schedule = Schedule(
                dayOfWeek: dayOfWeek,
                templateId: templateId,
                isRestDay: templateId == nil
            )
            try db.saveSchedule(schedule)
            await loadSchedule()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func markAsRestDay(dayOfWeek: Int) async -> Bool {
        do {
            let schedule = Schedule(
                dayOfWeek: dayOfWeek,
                templateId: nil,
                isRestDay: true
            )
            try db.saveSchedule(schedule)
            await loadSchedule()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func getTodaySchedule() -> ScheduleDay? {
        let today = Calendar.current.component(.weekday, from: Date()) - 1 // Convert to 0-indexed
        return scheduleDays.first { $0.dayOfWeek == today }
    }

    func getOrderedDays() -> [ScheduleDay] {
        var ordered: [ScheduleDay] = []
        for i in 0..<7 {
            let dayIndex = (weekStartsOn + i) % 7
            if let day = scheduleDays.first(where: { $0.dayOfWeek == dayIndex }) {
                ordered.append(day)
            } else {
                ordered.append(ScheduleDay(schedule: nil, template: nil, dayOfWeek: dayIndex))
            }
        }
        return ordered
    }

    func dateForCurrentWeek(dayOfWeek: Int, referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let startOfWeek = startDateOfCurrentWeek(referenceDate: referenceDate)
        var offset = dayOfWeek - weekStartsOn
        if offset < 0 {
            offset += 7
        }

        return calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? referenceDate
    }

    private func startDateOfCurrentWeek(referenceDate: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let todayWeekday = calendar.component(.weekday, from: today) - 1 // 0...6

        var delta = todayWeekday - weekStartsOn
        if delta < 0 {
            delta += 7
        }

        return calendar.date(byAdding: .day, value: -delta, to: today) ?? today
    }
}
