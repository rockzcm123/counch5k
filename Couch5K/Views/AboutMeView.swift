import SwiftUI

struct AboutMeView: View {
    @AppStorage("profileName") private var storedName = ""
    @AppStorage("profileHeightCm") private var storedHeightCm = 0.0
    @AppStorage("profileWeightKg") private var storedWeightKg = 0.0
    @AppStorage("profileBirthdate") private var storedBirthdate = 0.0
    @AppStorage("unitSystem") private var unitSystem = "metric"

    @State private var name = ""
    @State private var hasBirthdate = false
    @State private var birthdate = Date.now
    @State private var heightText = ""
    @State private var weightText = ""

    private var isMetric: Bool { unitSystem != "imperial" }

    var body: some View {
        Form {
            Section(L10n.personalDetails) {
                TextField(L10n.yourName, text: $name, prompt: Text(L10n.namePlaceholder))
                    .textContentType(.name)

                Toggle(L10n.birthdate, isOn: $hasBirthdate.animation())

                if hasBirthdate {
                    DatePicker(
                        L10n.birthdate,
                        selection: $birthdate,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    LabeledContent(L10n.age, value: ageText)
                }
            }

            Section(L10n.bodyMeasurements) {
                LabeledContent(L10n.height) {
                    TextField(heightUnitLabel, text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(L10n.weight) {
                    TextField(weightUnitLabel, text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle(L10n.aboutMe)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onDisappear(perform: persist)
    }

    private var heightUnitLabel: String {
        isMetric ? L10n.centimeters : L10n.inches
    }

    private var weightUnitLabel: String {
        isMetric ? L10n.kilograms : L10n.pounds
    }

    private var ageText: String {
        let years = Calendar.current.dateComponents([.year], from: birthdate, to: .now).year ?? 0
        return L10n.ageYears(max(years, 0))
    }

    private func load() {
        name = storedName
        hasBirthdate = storedBirthdate > 0
        birthdate = storedBirthdate > 0
            ? Date(timeIntervalSince1970: storedBirthdate)
            : Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        heightText = storedHeightCm > 0
            ? formatted(isMetric ? storedHeightCm : storedHeightCm / 2.54)
            : ""
        weightText = storedWeightKg > 0
            ? formatted(isMetric ? storedWeightKg : storedWeightKg * 2.20462)
            : ""
    }

    private func persist() {
        storedName = name
        storedBirthdate = hasBirthdate ? birthdate.timeIntervalSince1970 : 0

        if let value = Double(heightText), value > 0 {
            storedHeightCm = isMetric ? value : value * 2.54
        } else {
            storedHeightCm = 0
        }

        if let value = Double(weightText), value > 0 {
            storedWeightKg = isMetric ? value : value / 2.20462
        } else {
            storedWeightKg = 0
        }
    }

    private func formatted(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
    }
}

#Preview {
    NavigationStack {
        AboutMeView()
    }
}
