import CurfewControl
import Foundation
import Observation
import SystemConfiguration

@MainActor
@Observable
final class CurfewModel {
    enum Stage: Equatable {
        case checking
        case setup
        case running
        case stopped
        case denied
    }

    enum Work: Equatable {
        case settingUp
        case starting
        case updating
        case removing
    }

    enum Screen: Equatable {
        case home
        case about
    }

    private(set) var stage: Stage = .checking
    private(set) var computerName: String
    private(set) var phones: [ControlPhone] = []
    private(set) var pairing: PairingOffer?
    private(set) var secondsLeft = 0
    private(set) var notice: String?
    private(set) var problem: String?
    private(set) var work: Work?
    private(set) var settings: ControlSettings?
    private(set) var changing: ControlSetting?
    private(set) var serviceVersion: String?
    var confirmingLogin = false
    var screen: Screen = .home

    @ObservationIgnored private let client: ControlClient
    @ObservationIgnored private let runner: any PrivilegedRunning
    @ObservationIgnored private let isInstalled: @Sendable () -> Bool
    @ObservationIgnored private var ticker: Task<Void, Never>?

    init(client: ControlClient, runner: any PrivilegedRunning, isInstalled: @escaping @Sendable () -> Bool, computerName: String) {
        self.client = client
        self.runner = runner
        self.isInstalled = isInstalled
        self.computerName = computerName
    }

    static func live() -> CurfewModel {
        CurfewModel(
            client: ControlClient(path: Layout.live.controlSocket),
            runner: AppleScriptRunner(tool: AppleScriptRunner.bundledTool),
            isInstalled: { FileManager.default.fileExists(atPath: Layout.live.launchDaemon) },
            computerName: SCDynamicStoreCopyComputerName(nil, nil) as String? ?? "This Mac"
        )
    }

    var version: String { CurfewVersion.current }

    var needsUpdate: Bool {
        stage == .running && serviceVersion.map { $0 != version } == true
    }

    func refresh() async {
        do {
            apply(try await client.status())
        } catch ControlSocketError.denied {
            stopTicker()
            stage = .denied
        } catch {
            stopTicker()
            pairing = nil
            stage = isInstalled() ? .stopped : .setup
        }
    }

    func setUp() async {
        await perform(.install, as: .settingUp, until: .running)
    }

    func startAgain() async {
        await perform(.restart, as: .starting, until: .running)
    }

    func update() async {
        await perform(.install, as: .updating, until: .running)
    }

    func toggle(_ setting: ControlSetting) {
        guard let settings, changing == nil else { return }
        if setting == .login, !settings.login {
            confirmingLogin = true
            return
        }
        Task { await set(setting, !settings[setting]) }
    }

    func set(_ setting: ControlSetting, _ on: Bool) async {
        changing = setting
        notice = nil
        problem = nil
        defer { changing = nil }
        do {
            try await client.set(setting, on)
        } catch ControlError.loginUnavailable {
            problem = "macOS did not load the login plugin, so the login screen was left as it was."
        } catch {
            problem = "Could not change \(setting.title.lowercased())."
        }
        await refresh()
    }

    func removeFromMac() async {
        await perform(.uninstall, as: .removing, until: .setup)
        if stage == .setup {
            screen = .home
        }
    }

    func startPairing() async {
        guard pairing == nil else { return }
        notice = nil
        do {
            begin(try await client.startPairing())
        } catch ControlError.noNetwork {
            notice = "This Mac is not on a network. Connect to the home Wi-Fi first."
        } catch {
            await refresh()
        }
    }

    func cancelPairing() async {
        guard let pairing else { return }
        finish(nil)
        try? await client.cancelPairing(pairing.code)
    }

    func unpair(_ phone: ControlPhone) async {
        do {
            try await client.unpair(phone.id)
            notice = "Removed \(phone.name)."
        } catch ControlError.noPhone {
            notice = nil
        } catch {
            problem = "Could not remove \(phone.name)."
        }
        await refresh()
    }

    func pollPairing() async {
        guard let offer = pairing else { return }
        secondsLeft = max(0, secondsLeft - 1)
        switch try? await client.progress(of: offer.code) {
        case .pending(let seconds)?:
            secondsLeft = seconds
        case .paired(let name)?:
            finish("Paired with \(name).")
            await refresh()
        case .expired?:
            finish("The code expired.")
        case .cancelled?:
            finish("The code was cancelled.")
        case nil:
            if secondsLeft == 0 { finish("The code expired.") }
        }
    }

    private func apply(_ status: ControlStatus) {
        stage = .running
        computerName = status.name
        phones = status.phones
        settings = status.settings
        serviceVersion = status.version
        if pairing == nil, let offer = status.pairing {
            begin(offer)
        }
    }

    private func begin(_ offer: PairingOffer) {
        pairing = offer
        secondsLeft = offer.expiresIn
        notice = nil
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                await self.pollPairing()
            }
        }
    }

    private func finish(_ message: String?) {
        stopTicker()
        pairing = nil
        notice = message
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func perform(_ action: PrivilegedAction, as kind: Work, until goal: Stage) async {
        work = kind
        problem = nil
        defer { work = nil }
        try? await Task.sleep(for: .milliseconds(100))
        do throws(PrivilegedError) {
            try await runner.run(action)
        } catch {
            switch error {
            case .cancelled: break
            case .missingTool: problem = "The app is missing its curfew tool. Install Curfew again."
            case .failed(let message): problem = message
            }
            return
        }
        for _ in 0..<40 {
            await refresh()
            if stage == goal { return }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}

#if DEBUG
extension CurfewModel {
    static func sample(
        _ stage: Stage, phones: [ControlPhone] = [], pairing: PairingOffer? = nil, secondsLeft: Int = 0, screen: Screen = .home,
        settings: ControlSettings? = nil, serviceVersion: String? = nil
    ) -> CurfewModel {
        let model = CurfewModel(
            client: ControlClient(path: "/nonexistent"), runner: AppleScriptRunner(tool: nil),
            isInstalled: { false }, computerName: "MacBook Pro"
        )
        model.stage = stage
        model.phones = phones
        model.pairing = pairing
        model.secondsLeft = secondsLeft
        model.screen = screen
        model.settings = settings
        model.serviceVersion = serviceVersion ?? model.version
        return model
    }
}
#endif
