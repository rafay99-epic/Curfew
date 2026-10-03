import CurfewControl

extension ControlSetting {
    var title: String {
        switch self {
        case .login: "Log in from the phone"
        case .wake: "Wake for the phone"
        case .awake: "Stay awake on power"
        }
    }
}
