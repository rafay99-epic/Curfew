import CurfewControl
import SwiftUI

struct SettingsView: View {
    let settings: ControlSettings
    let busy: ControlSetting?
    let toggle: (ControlSetting) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ControlSetting.allCases, id: \.self) { setting in
                if setting != .login || settings.loginReady {
                    SettingRow(title: setting.title, on: settings[setting], busy: busy == setting, enabled: busy == nil) {
                        toggle(setting)
                    }
                }
            }
            Text(Self.hint(settings))
                .font(Theme.sans(13))
                .foregroundStyle(Theme.dim)
                .lineSpacing(3)
                .frame(maxWidth: 440, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    static func hint(_ settings: ControlSettings) -> String {
        settings.login
            ? "Log in from the phone works for an account once its password has been typed at this Mac's login screen."
            : "Wake for the phone lets it reach this Mac while it sleeps."
    }
}

private struct SettingRow: View {
    let title: String
    let on: Bool
    let busy: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        HairlineRow {
            Text(title).font(Theme.sans(14.5)).foregroundStyle(Theme.text)
        } trailing: {
            Button(action: action) {
                Text(busy ? "…" : on ? "On" : "Off")
                    .font(Theme.mono(12.5, on ? .medium : .regular))
                    .foregroundStyle(on ? Theme.text : Theme.dim)
                    .frame(minWidth: 34, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel(title)
            .accessibilityValue(on ? "On" : "Off")
        }
    }
}
