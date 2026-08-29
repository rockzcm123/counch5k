import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case pink
    case blue
    case green
    case orange
    case purple
    case teal
    case white

    static let storageKey = "colorTheme"

    var id: String { rawValue }

    /// The accent used for buttons, highlights, and (for every theme except
    /// `.white`) the Plan tab's hero banner background.
    var color: Color {
        switch self {
        case .pink: Color(red: 232 / 255, green: 40 / 255, blue: 86 / 255)
        case .blue: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255)
        case .green: Color(red: 40 / 255, green: 160 / 255, blue: 90 / 255)
        case .orange: Color(red: 255 / 255, green: 122 / 255, blue: 26 / 255)
        case .purple: Color(red: 142 / 255, green: 68 / 255, blue: 236 / 255)
        case .teal: Color(red: 0 / 255, green: 173 / 255, blue: 181 / 255)
        // A Wise-inspired green, used for pill buttons and highlights on
        // the white surface — see `isLightSurface` below. Deliberately
        // richer than Wise's own very light lime green: this accent is
        // also reused everywhere else in the app (calendar badges,
        // checkmarks) as white-on-color, which needs more contrast than a
        // pale lime can give it.
        case .white: Color(red: 34 / 255, green: 170 / 255, blue: 96 / 255)
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
        case .white: L10n.themeWhite
        }
    }

    /// `.white` swaps the app's usual "solid accent color banner, white
    /// text" surfaces for a plain white/light-gray surface with dark text
    /// and the accent used only for small pills and highlights instead —
    /// the Wise-app look. Every other theme keeps the original style.
    var isLightSurface: Bool {
        self == .white
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
                    // The `.white` swatch renders as white with a visible
                    // border (rather than its lime-green accent) so it
                    // reads as "the white theme," not just another color.
                    .fill(theme.isLightSurface ? Color.white : theme.color)
                    .overlay {
                        if theme.isLightSurface {
                            Circle().stroke(Color(.separator), lineWidth: 1)
                        }
                    }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.isLightSurface ? .black : .white)
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
