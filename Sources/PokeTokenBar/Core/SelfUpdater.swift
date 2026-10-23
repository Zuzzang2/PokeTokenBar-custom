import AppKit
import Observation

/// "최근 버전으로 업데이트": takes the newest `main`, builds it in a private clone under the app's
/// state directory and swaps the installed app. The clone is never the developer's own checkout, so
/// local branches and uncommitted work are untouched. Needs git and the Swift toolchain, like
/// `build-app.sh` itself.
@MainActor
@Observable
final class SelfUpdater {
    enum State: Equatable {
        case idle
        case working(String)
    }

    private(set) var state: State = .idle
    var isBusy: Bool { if case .working = state { return true } else { return false } }

    static let defaultRepoURL = "https://github.com/Zuzzang2/PokeTokenBar-custom.git"
    static let installedApp = "/Applications/PokeTokenBar.app"

    /// Remote and build id baked into Info.plist by `build-app.sh`.
    static var repoURL: String {
        let embedded = Bundle.main.object(forInfoDictionaryKey: "PTBRepoURL") as? String
        return embedded.flatMap { $0.isEmpty ? nil : $0 } ?? defaultRepoURL
    }
    static var currentBuild: String { (Bundle.main.object(forInfoDictionaryKey: "PTBBuild") as? String) ?? "unknown" }

    private var cloneDir: URL { AppStatePaths.directory().appendingPathComponent("update-src") }
    private var logURL: URL { AppStatePaths.directory().appendingPathComponent("update.log") }

    /// True when `remote` (a full commit hash) is exactly what this app was built from.
    static func isUpToDate(build: String, remote: String) -> Bool {
        guard !build.hasSuffix("+local"), build != "unknown", build.count >= 7 else { return false }
        return remote.hasPrefix(build)
    }

    /// Asks first (the build takes minutes and restarts the app), then runs to completion.
    /// `show` reports the outcome to the user: title, message.
    func updateToLatestMain(confirm: () -> Bool, show: (String, String) -> Void) async {
        guard !isBusy else { return }
        let url = Self.repoURL
        state = .working("최신 커밋 확인 중…")
        defer { state = .idle }
        let remote = await Self.run("/usr/bin/git", ["ls-remote", url, "refs/heads/main"])
        guard remote.status == 0, let hash = remote.output.split(whereSeparator: \.isWhitespace).first.map(String.init),
              hash.count >= 7 else {
            show("업데이트 확인 실패", "main 최신 커밋을 가져오지 못했어요. 네트워크와 저장소 접근 권한을 확인해 주세요.\n\(Self.tail(remote.output))")
            return
        }
        if Self.isUpToDate(build: Self.currentBuild, remote: hash) {
            show("이미 최신이에요", "현재 빌드 \(Self.currentBuild)가 main의 최신 커밋과 같아요.")
            return
        }
        guard confirm() else { return }

        state = .working("최신 main 내려받는 중…")
        let fm = FileManager.default
        let fetched: (status: Int32, output: String)
        if fm.fileExists(atPath: cloneDir.appendingPathComponent(".git").path) {
            let f = await Self.run("/usr/bin/git", ["-C", cloneDir.path, "fetch", "origin", "main"])
            fetched = f.status == 0
                ? await Self.run("/usr/bin/git", ["-C", cloneDir.path, "reset", "--hard", "FETCH_HEAD"]) : f
        } else {
            try? fm.removeItem(at: cloneDir)
            fetched = await Self.run("/usr/bin/git", ["clone", "--branch", "main", "--single-branch", url, cloneDir.path])
        }
        guard fetched.status == 0 else {
            show("업데이트 실패", "내려받기에 실패했어요.\n\(Self.tail(fetched.output))")
            return
        }

        // The build script ends by killing this app and installing the new one, so the relaunch is
        // chained in the same shell: it keeps running after the app is gone. On a build failure the
        // app is still alive and reports the log tail instead.
        state = .working("빌드 중… 몇 분 걸려요. 끝나면 앱이 다시 켜져요")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let script = "cd \"\(cloneDir.path)\" && PTB_NATIVE_ARCH_ONLY=1 ./scripts/build-app.sh >> \"\(logURL.path)\" 2>&1 "
            + "&& /usr/bin/open \"\(Self.installedApp)\""
        let built = await Self.run("/bin/bash", ["-c", script])
        if built.status != 0 {
            let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? built.output
            show("업데이트 실패", "빌드에 실패했어요. 기존 앱은 그대로예요.\n\(Self.tail(log))")
        }
    }

    /// Runs a tool to completion off the main actor and returns its status and combined output.
    nonisolated private static func run(_ tool: String, _ args: [String]) async -> (status: Int32, output: String) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: tool)
                process.arguments = args
                var env = ProcessInfo.processInfo.environment
                env["GIT_TERMINAL_PROMPT"] = "0"   // never hang on a credential prompt
                process.environment = env
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do { try process.run() } catch {
                    continuation.resume(returning: (-1, "\(error)"))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: (process.terminationStatus, String(decoding: data, as: UTF8.self)))
            }
        }
    }

    private static func tail(_ text: String, lines: Int = 8) -> String {
        text.split(separator: "\n").suffix(lines).joined(separator: "\n")
    }
}
