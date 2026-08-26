import PhotosUI
import SwiftUI
import UIKit

struct AboutMeView: View {
    @AppStorage("profileName") private var storedName = ""
    @AppStorage("profilePhotoData") private var storedPhotoData = Data()
    @AppStorage("profileHeightCm") private var storedHeightCm = 0.0
    @AppStorage("profileWeightKg") private var storedWeightKg = 0.0
    @AppStorage("profileBirthdate") private var storedBirthdate = 0.0
    @AppStorage("unitSystem") private var unitSystem = "metric"

    @State private var name = ""
    @State private var photoData = Data()
    @State private var hasBirthdate = false
    @State private var birthdate = Date.now
    @State private var heightText = ""
    @State private var weightText = ""

    private var isMetric: Bool { unitSystem != "imperial" }

    var body: some View {
        Form {
            ProfileFieldsForm(
                name: $name,
                photoData: $photoData,
                hasBirthdate: $hasBirthdate,
                birthdate: $birthdate,
                heightText: $heightText,
                weightText: $weightText,
                isMetric: isMetric
            )
        }
        .navigationTitle(L10n.aboutMe)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onDisappear(perform: persist)
    }

    private func load() {
        name = storedName
        photoData = storedPhotoData
        hasBirthdate = storedBirthdate > 0
        birthdate = storedBirthdate > 0
            ? Date(timeIntervalSince1970: storedBirthdate)
            : Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        heightText = storedHeightCm > 0
            ? ProfileFieldsForm.formattedNumber(isMetric ? storedHeightCm : storedHeightCm / 2.54)
            : ""
        weightText = storedWeightKg > 0
            ? ProfileFieldsForm.formattedNumber(isMetric ? storedWeightKg : storedWeightKg * 2.20462)
            : ""
    }

    private func persist() {
        storedName = name
        storedPhotoData = photoData
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
}

/// Shared personal-details + body-measurement fields, reused by both the
/// About Me settings page and the first-run onboarding profile step.
struct ProfileFieldsForm: View {
    @Binding var name: String
    @Binding var photoData: Data
    @Binding var hasBirthdate: Bool
    @Binding var birthdate: Date
    @Binding var heightText: String
    @Binding var weightText: String
    let isMetric: Bool

    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let hasPhoto = !photoData.isEmpty

        Section(L10n.personalDetails) {
            HStack(spacing: 16) {
                avatarView

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text(hasPhoto ? L10n.changePhoto : L10n.choosePhoto)
                }

                if hasPhoto {
                    Spacer()
                    Button(role: .destructive) {
                        photoData = Data()
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(L10n.removePhoto)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem,
                          let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    photoData = Self.resizedImageData(from: data) ?? data
                }
            }

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
                    .onChange(of: heightText) { _, newValue in
                        let sanitized = Self.sanitizeNumericInput(newValue)
                        if sanitized != newValue { heightText = sanitized }
                    }
            }
            LabeledContent(L10n.weight) {
                TextField(weightUnitLabel, text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: weightText) { _, newValue in
                        let sanitized = Self.sanitizeNumericInput(newValue)
                        if sanitized != newValue { weightText = sanitized }
                    }
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .accessibilityHidden(true)
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

    /// Keeps only digits and a single decimal separator, so height/weight
    /// fields can never hold non-numeric text even from paste or a
    /// hardware keyboard (the decimal-pad keyboard alone doesn't stop that).
    static func sanitizeNumericInput(_ text: String) -> String {
        var sawDecimalSeparator = false
        var result = ""
        for character in text {
            if character.isNumber {
                result.append(character)
            } else if character == ".", !sawDecimalSeparator {
                sawDecimalSeparator = true
                result.append(character)
            }
        }
        return result
    }

    static func resizedImageData(from data: Data, maxDimension: CGFloat = 400) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.85) }

        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }

    static func formattedNumber(_ value: Double) -> String {
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
