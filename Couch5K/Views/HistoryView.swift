import Charts
import SwiftData
import SwiftUI
import MapKit

struct HistoryView: View {
    let records: [WorkoutRecord]

    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @AppStorage(AppTheme.storageKey) private var colorTheme = AppTheme.pink.rawValue
    @State private var trendMetric: TrendMetric = .distance
    @State private var displayedMonth = Calendar.current.dateInterval(
        of: .month,
        for: .now
    )?.start ?? .now
    @State private var selectedDate: Date?
    @State private var visibleRecordCount = HistoryView.pageSize

    private static let pageSize = 20

    private var themeColor: Color {
        AppTheme(rawValue: colorTheme)?.color ?? .brandPink
    }

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        L10n.noHistory,
                        systemImage: "figure.run",
                        description: Text(L10n.noHistoryDescription)
                    )
                } else {
                    List {
                        summarySection
                        badgesSection
                        chartsSection
                        activityCalendarSection

                        Section {
                            if filteredRecords.isEmpty {
                                Text(L10n.noWorkoutsThisDay)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(displayedRecords) { record in
                                    NavigationLink {
                                        WorkoutRecordDetailView(record: record)
                                    } label: {
                                        recordRow(record)
                                    }
                                }
                                .onDelete(perform: delete)

                                if hasMoreRecords {
                                    Button(L10n.loadMore) {
                                        withAnimation {
                                            visibleRecordCount += HistoryView.pageSize
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        } header: {
                            HStack {
                                Text(selectedDate.map(L10n.workoutsOnDate) ?? L10n.allWorkouts)
                                if selectedDate != nil {
                                    Spacer()
                                    Button(L10n.showAllWorkouts) {
                                        withAnimation {
                                            selectedDate = nil
                                        }
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.workoutHistory)
            .onChange(of: selectedDate) { _, _ in
                visibleRecordCount = HistoryView.pageSize
            }
        }
    }

    private var filteredRecords: [WorkoutRecord] {
        guard let selectedDate else { return records }
        return recordsOnDay(selectedDate)
    }

    private var displayedRecords: [WorkoutRecord] {
        Array(filteredRecords.prefix(visibleRecordCount))
    }

    private var hasMoreRecords: Bool {
        filteredRecords.count > displayedRecords.count
    }

    private var activityCalendarSection: some View {
        Section {
            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(monthTitle)
                            .font(.title2.bold())
                        Text(L10n.monthWorkoutCount(monthRecords.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        monthButton(
                            systemImage: "chevron.left",
                            label: L10n.previousMonth,
                            disabled: false
                        ) {
                            moveMonth(by: -1)
                        }

                        monthButton(
                            systemImage: "chevron.right",
                            label: L10n.nextMonth,
                            disabled: !canMoveToNextMonth
                        ) {
                            moveMonth(by: 1)
                        }
                    }
                }

                LazyVGrid(columns: calendarColumns, spacing: 10) {
                    ForEach(calendarWeekdays, id: \.id) { weekday in
                        Text(weekday.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDay(date)
                        } else {
                            Color.clear
                                .frame(height: 42)
                        }
                    }
                }

                HStack(spacing: 20) {
                    Label(
                        distanceText(monthRecords.reduce(0) { $0 + $1.distanceMeters }),
                        systemImage: "figure.run"
                    )
                    Label(
                        monthRecords.reduce(0) { $0 + $1.plannedDuration }.workoutDurationText,
                        systemImage: "clock"
                    )
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 10)
        } header: {
            Text(L10n.activityCalendar)
        }
    }

    private func monthButton(
        systemImage: String,
        label: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.bold())
                .frame(width: 38, height: 38)
                .background(Color.secondary.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    private func calendarDay(_ date: Date) -> some View {
        let workoutCount = recordsOnDay(date).count
        let hasWorkout = workoutCount > 0
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = selectedDate.map {
            Calendar.current.isDate($0, inSameDayAs: date)
        } ?? false

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = isSelected ? nil : date
            }
        } label: {
            ZStack {
                Circle()
                    .fill(hasWorkout ? themeColor : Color.secondary.opacity(0.08))

                if isSelected {
                    Circle()
                        .stroke(themeColor, lineWidth: 2)
                        .padding(-3)
                } else if isToday && !hasWorkout {
                    Circle()
                        .stroke(themeColor, lineWidth: 1.5)
                }

                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.subheadline.weight(hasWorkout ? .bold : .regular))
                    .foregroundStyle(hasWorkout ? Color.white : Color.primary)

                if hasWorkout {
                    Image(systemName: workoutCount > 1 ? "checkmark.circle.fill" : "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: 12, y: -12)
                }
            }
            .frame(width: 38, height: 38)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            L10n.calendarDayAccessibility(
                date: date,
                workoutCount: workoutCount
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var badgesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.myBadges)
                            .font(.headline)
                        Text(L10n.badgesMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(unlockedBadgeCount) / \(badges.count)")
                        .font(.subheadline.bold())
                        .foregroundStyle(themeColor)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(badges) { badge in
                            badgeCard(badge)
                        }
                    }
                }
                .contentMargins(.horizontal, 2, for: .scrollContent)
            }
            .padding(.vertical, 4)
        }
    }

    private func badgeCard(_ badge: AchievementBadge) -> some View {
        let progress = badgeProgress(for: badge)
        let unlocked = progress >= 1

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: unlocked ? badge.icon : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(unlocked ? Color.white : Color.secondary)
                    .frame(width: 48, height: 48)
                    .background(
                        unlocked ? themeColor : Color.secondary.opacity(0.12),
                        in: Circle()
                    )

                Spacer()

                if unlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(themeColor)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(badge.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(badge.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if unlocked {
                Text(L10n.earned)
                    .font(.caption.bold())
                    .foregroundStyle(themeColor)
            } else {
                ProgressView(value: progress)
                    .tint(themeColor)
                Text(badgeProgressText(for: badge))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 180, height: 212, alignment: .topLeading)
        .background(
            unlocked
                ? themeColor.opacity(0.09)
                : Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(unlocked ? themeColor.opacity(0.22) : Color.clear)
        }
        .accessibilityElement(children: .combine)
    }

    private var summarySection: some View {
        Section(L10n.workoutOverview) {
            LazyVGrid(columns: summaryColumns, spacing: 12) {
                statistic(value: "\(records.count)", label: L10n.completions, icon: "checkmark")
                statistic(
                    value: totalDuration.workoutDurationText,
                    label: L10n.totalTraining,
                    icon: "clock"
                )
                statistic(
                    value: distanceText(totalDistance),
                    label: L10n.totalDistance,
                    icon: "location.fill"
                )
                statistic(
                    value: "\(currentWeekCount)",
                    label: L10n.thisWeek,
                    icon: "calendar"
                )
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var chartsSection: some View {
        Section(L10n.workoutTrends) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    trendMetricButton(.distance, icon: "figure.run")
                    trendMetricButton(.duration, icon: "clock")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.thisWeek)
                        .font(.title2.bold())

                    HStack(spacing: 28) {
                        trendStatistic(
                            label: L10n.distance,
                            value: distanceText(currentWeekDistance)
                        )
                        trendStatistic(
                            label: L10n.duration,
                            value: currentWeekDuration.workoutDurationText
                        )
                        trendStatistic(
                            label: L10n.completions,
                            value: "\(currentWeekCount)"
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.pastTwelveWeeks)
                        .font(.subheadline)

                    Chart(weeklyActivity) { activity in
                        AreaMark(
                            x: .value(L10n.week, activity.startDate),
                            y: .value(trendMetric.axisTitle, trendValue(for: activity))
                        )
                        .foregroundStyle(themeColor.opacity(0.14))
                        .interpolationMethod(.linear)

                        LineMark(
                            x: .value(L10n.week, activity.startDate),
                            y: .value(trendMetric.axisTitle, trendValue(for: activity))
                        )
                        .foregroundStyle(themeColor)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                        PointMark(
                            x: .value(L10n.week, activity.startDate),
                            y: .value(trendMetric.axisTitle, trendValue(for: activity))
                        )
                        .foregroundStyle(Color(.systemBackground))
                        .symbolSize(62)
                        .annotation(position: .overlay) {
                            Circle()
                                .stroke(themeColor, lineWidth: 2.5)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .chartYScale(domain: 0...trendChartMaximum)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.secondary.opacity(0.16))
                            AxisValueLabel {
                                if let number = value.as(Double.self) {
                                    Text(trendAxisLabel(number))
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(
                                        date.formatted(
                                            .dateTime
                                                .month(.abbreviated)
                                                .locale(AppLanguage.current.locale)
                                        )
                                    )
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .animation(.easeInOut(duration: 0.25), value: trendMetric)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private func trendMetricButton(_ metric: TrendMetric, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                trendMetric = metric
            }
        } label: {
            Label(metric.title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(trendMetric == metric ? Color.white : Color.primary)
                .background(
                    trendMetric == metric ? themeColor : Color.clear,
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            trendMetric == metric ? themeColor : Color.secondary.opacity(0.35),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func trendStatistic(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    private func trendValue(for activity: WeeklyActivity) -> Double {
        switch trendMetric {
        case .distance:
            convertedDistance(activity.distanceMeters)
        case .duration:
            activity.duration / 60
        }
    }

    private var trendChartMaximum: Double {
        let maximum = weeklyActivity.map(trendValue(for:)).max() ?? 0
        return max(maximum * 1.2, 1)
    }

    private func trendAxisLabel(_ value: Double) -> String {
        switch trendMetric {
        case .distance:
            String(format: "%.1f %@", value, distanceUnit)
        case .duration:
            String(format: "%.0f %@", value, L10n.minuteAbbreviation)
        }
    }

    private func statistic(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(themeColor)

            Text(value)
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func recordRow(_ record: WorkoutRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(record.title)
                    .font(.headline)
                Spacer()
                Text(record.plannedDuration.workoutDurationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(record.localizedSessionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(record.completedAt, format: .dateTime.year().month().day().hour().minute())
                if !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(L10n.hasNotes, systemImage: "note.text")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var totalDuration: TimeInterval {
        records.reduce(0) { $0 + $1.plannedDuration }
    }

    private var totalDistance: Double {
        records.reduce(0) { $0 + $1.distanceMeters }
    }

    private var currentWeekCount: Int {
        records.count { Calendar.current.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear) }
    }

    private var currentWeekDistance: Double {
        currentWeekRecords.reduce(0) { $0 + $1.distanceMeters }
    }

    private var currentWeekDuration: TimeInterval {
        currentWeekRecords.reduce(0) { $0 + $1.plannedDuration }
    }

    private var currentWeekRecords: [WorkoutRecord] {
        records.filter {
            Calendar.current.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }
    }

    private var calendarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    }

    private var calendarWeekdays: [(id: Int, label: String)] {
        [2, 3, 4, 5, 6, 7, 1].map { ($0, L10n.weekday($0, short: true)) }
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth)
              ) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = (weekday + 5) % 7
        var days = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        days.append(
            contentsOf: range.compactMap {
                calendar.date(byAdding: .day, value: $0 - 1, to: firstDay)
            }
        )
        let trailingEmptyDays = (7 - days.count % 7) % 7
        days.append(contentsOf: Array<Date?>(repeating: nil, count: trailingEmptyDays))
        return days
    }

    private var monthRecords: [WorkoutRecord] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }
        return records.filter { interval.contains($0.completedAt) }
    }

    private var monthTitle: String {
        displayedMonth.formatted(
            .dateTime
                .year()
                .month(.wide)
                .locale(AppLanguage.current.locale)
        )
    }

    private var canMoveToNextMonth: Bool {
        guard let currentMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start else {
            return false
        }
        return displayedMonth < currentMonth
    }

    private func recordsOnDay(_ date: Date) -> [WorkoutRecord] {
        records.filter { Calendar.current.isDate($0.completedAt, inSameDayAs: date) }
    }

    private func moveMonth(by value: Int) {
        guard let month = Calendar.current.date(
            byAdding: .month,
            value: value,
            to: displayedMonth
        ) else {
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = month
            selectedDate = nil
        }
    }

    private var badges: [AchievementBadge] {
        [
            achievementBadge(
                id: "first-step",
                icon: "shoeprints.fill",
                requirement: .workouts(1)
            ),
            achievementBadge(
                id: "habit-started",
                icon: "sparkles",
                requirement: .workouts(3)
            ),
            achievementBadge(
                id: "showing-up",
                icon: "calendar.badge.checkmark",
                requirement: .weekStreak(2)
            ),
            achievementBadge(
                id: "ten-strong",
                icon: "flame.fill",
                requirement: .workouts(10)
            ),
            achievementBadge(
                id: "five-kilometers",
                icon: "map.fill",
                requirement: .distance(5_000)
            ),
            achievementBadge(
                id: "consistent-month",
                icon: "calendar.circle.fill",
                requirement: .weekStreak(4)
            ),
            achievementBadge(
                id: "distance-builder",
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                requirement: .distance(25_000)
            ),
            achievementBadge(
                id: "couch-to-5k",
                icon: "trophy.fill",
                requirement: .planSessions(27)
            )
        ]
    }

    private func achievementBadge(
        id: String,
        icon: String,
        requirement: AchievementRequirement
    ) -> AchievementBadge {
        let copy = L10n.badge(id: id)
        return AchievementBadge(
            id: id,
            title: copy.title,
            detail: copy.detail,
            icon: icon,
            requirement: requirement
        )
    }

    private var unlockedBadgeCount: Int {
        badges.count { badgeProgress(for: $0) >= 1 }
    }

    private var longestWeekStreak: Int {
        let calendar = Calendar.current
        let activeWeeks = Set(
            records.compactMap {
                calendar.dateInterval(of: .weekOfYear, for: $0.completedAt)?.start
            }
        )
        let sortedWeeks = activeWeeks.sorted()
        guard !sortedWeeks.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for index in 1..<sortedWeeks.count {
            let previous = sortedWeeks[index - 1]
            let expected = calendar.date(byAdding: .weekOfYear, value: 1, to: previous)
            if expected == sortedWeeks[index] {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private var completedPlanSessions: Int {
        Set(
            records
                .filter { (1...9).contains($0.weekNumber) && (1...3).contains($0.sessionDay) }
                .map(\.completionKey)
        ).count
    }

    private func badgeProgress(for badge: AchievementBadge) -> Double {
        let current: Double
        let target: Double

        switch badge.requirement {
        case .workouts(let count):
            current = Double(records.count)
            target = Double(count)
        case .weekStreak(let weeks):
            current = Double(longestWeekStreak)
            target = Double(weeks)
        case .distance(let meters):
            current = totalDistance
            target = meters
        case .planSessions(let count):
            current = Double(completedPlanSessions)
            target = Double(count)
        }

        return min(current / target, 1)
    }

    private func badgeProgressText(for badge: AchievementBadge) -> String {
        switch badge.requirement {
        case .workouts(let target):
            L10n.workoutProgress(current: min(records.count, target), target: target)
        case .weekStreak(let target):
            L10n.weekProgress(current: min(longestWeekStreak, target), target: target)
        case .distance(let target):
            "\(distanceText(min(totalDistance, target))) / \(distanceText(target))"
        case .planSessions(let target):
            L10n.workoutProgress(current: min(completedPlanSessions, target), target: target)
        }
    }

    private var weeklyActivity: [WeeklyActivity] {
        let calendar = Calendar.current
        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)

        return (0..<12).reversed().compactMap { weeksAgo in
            guard let startDate = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: currentWeek),
                  let endDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) else {
                return nil
            }

            let weekRecords = records.filter {
                $0.completedAt >= startDate && $0.completedAt < endDate
            }
            return WeeklyActivity(
                startDate: startDate,
                count: weekRecords.count,
                distanceMeters: weekRecords.reduce(0) { $0 + $1.distanceMeters },
                duration: weekRecords.reduce(0) { $0 + $1.plannedDuration }
            )
        }
    }

    private var summaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var distanceUnit: String {
        unitSystem == "imperial" ? L10n.mileAbbreviation : L10n.kilometerAbbreviation
    }

    private func convertedDistance(_ meters: Double) -> Double {
        meters / (unitSystem == "imperial" ? 1_609.344 : 1_000)
    }

    private func distanceText(_ meters: Double) -> String {
        String(format: "%.1f %@", convertedDistance(meters), distanceUnit)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(displayedRecords[index])
        }
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Unable to delete workout record: \(error)")
        }
    }
}

private struct WeeklyActivity: Identifiable {
    let startDate: Date
    let count: Int
    let distanceMeters: Double
    let duration: TimeInterval

    var id: Date { startDate }
}

private enum TrendMetric: String {
    case distance
    case duration

    var title: String {
        switch self {
        case .distance: L10n.distance
        case .duration: L10n.duration
        }
    }

    var axisTitle: String { title }
}

private struct AchievementBadge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let requirement: AchievementRequirement
}

private enum AchievementRequirement {
    case workouts(Int)
    case weekStreak(Int)
    case distance(Double)
    case planSessions(Int)
}

private struct WorkoutRecordDetailView: View {
    @Bindable var record: WorkoutRecord
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem = "metric"
    @AppStorage(AppTheme.storageKey) private var colorTheme = AppTheme.pink.rawValue

    private var themeColor: Color {
        AppTheme(rawValue: colorTheme)?.color ?? .brandPink
    }

    var body: some View {
        Form {
            Section(L10n.workout) {
                LabeledContent(L10n.plan, value: record.title)
                LabeledContent(L10n.content, value: record.localizedSessionSummary)
                LabeledContent(L10n.duration, value: record.plannedDuration.workoutDurationText)
                if record.distanceMeters > 0 {
                    LabeledContent(L10n.distance, value: distanceText(record.distanceMeters))
                }
                LabeledContent(
                    L10n.completedAt,
                    value: record.completedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
            }

            if record.route.count >= 2 {
                Section(L10n.route) {
                    Map {
                        MapPolyline(
                            coordinates: record.route.map {
                                CLLocationCoordinate2D(
                                    latitude: $0.latitude,
                                    longitude: $0.longitude
                                )
                            }
                        )
                        .stroke(themeColor, lineWidth: 5)
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(L10n.routeMapAccessibility)
                }
            }

            Section(L10n.workoutNotes) {
                TextEditor(text: $record.notes)
                    .frame(minHeight: 140)
                    .overlay(alignment: .topLeading) {
                        if record.notes.isEmpty {
                            Text(L10n.workoutNotesPlaceholder)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
        }
        .navigationTitle(record.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            do {
                try modelContext.save()
            } catch {
                assertionFailure("Unable to save workout notes: \(error)")
            }
        }
    }

    private func distanceText(_ meters: Double) -> String {
        if unitSystem == "imperial" {
            return String(format: "%.2f %@", meters / 1_609.344, L10n.mileAbbreviation)
        }
        return String(format: "%.2f %@", meters / 1_000, L10n.kilometerAbbreviation)
    }
}
