import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case pink
    case blue
    case green
    case orange
    case purple
    case teal

    static let storageKey = "colorTheme"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink: Color(red: 232 / 255, green: 40 / 255, blue: 86 / 255)
        case .blue: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
        case .green: Color(red: 40 / 255, green: 160 / 255, blue: 90 / 255)
        case .orange: Color(red: 255 / 255, green: 122 / 255, blue: 26 / 255)
        case .purple: Color(red: 142 / 255, green: 68 / 255, blue: 236 / 255)
        case .teal: Color(red: 0 / 255, green: 173 / 255, blue: 181 / 255)
        }
    }

    var displayName: String {
        switch self {
        case .pink: L10n.themePink
        case .blue: L10n.themeBlue
        case .green: L10n.themeGreen
        case .orange: L10n.themeOrange
        case .purple: L10n.themePurple
        case .teal: L10n.themeTeal
        }
    }

    static var current: AppTheme {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return .pink }
        return AppTheme(rawValue: raw) ?? .pink
    }
}

struct ThemeColorPicker: View {
    @Binding var colorTheme: String

    var body: some View {
        HStack(spacing: 14) {
            ForEach(AppTheme.allCases) { theme in
                swatch(theme)
            }
        }
        .padding(.vertical, 4)
    }

    private func swatch(_ theme: AppTheme) -> some View {
        let isSelected = theme.rawValue == colorTheme

        return Button {
            colorTheme = theme.rawValue
        } label: {
            ZStack {
                Circle()
                    .fill(theme.color)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 34, height: 34)
            .overlay {
                Circle()
                    .stroke(isSelected ? theme.color : Color.clear, lineWidth: 2)
                    .padding(-4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
