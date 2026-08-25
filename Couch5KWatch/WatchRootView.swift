import SwiftUI

struct WatchRootView: View {
    let plan: TrainingPlan

    var body: some View {
        NavigationStack {
            List(plan.weeks) { week in
                Section("第 \(week.number) 周") {
                    ForEach(week.sessions) { session in
                        NavigationLink {
                            WatchWorkoutView(
                                weekNumber: week.number,
                                session: session
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.title)
                                    .font(.headline)
                                Text(session.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Couch 5K")
        }
    }
}
