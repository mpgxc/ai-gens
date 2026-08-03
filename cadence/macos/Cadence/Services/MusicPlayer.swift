import AVFoundation
import Foundation
import Observation

/// Background audio for focus blocks.
///
/// `AVPlayer` covers both cases the app supports — a local file or folder, and
/// a direct stream URL — with the same API, so there is one code path rather
/// than two.
///
/// Sandbox note: a user-picked file is only reachable through a
/// **security-scoped bookmark**. The raw path stops working the moment the app
/// relaunches, so the bookmark is what gets persisted, and access has to be
/// opened before playback and closed after. Getting this wrong produces a
/// player that works until quit and silently fails forever after.
@MainActor
@Observable
final class MusicPlayer {

    enum Source: Equatable {
        case none
        case file(URL)
        case folder(URL)
        case stream(URL)
    }

    /// What the player is currently doing, for the settings screen to show.
    enum Status: Equatable {
        case idle
        case playing(String)
        case failed(String)
    }

    private(set) var status: Status = .idle

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var source: Source = .none
    @ObservationIgnored private var scopedURL: URL?
    @ObservationIgnored private var playlist: [URL] = []
    @ObservationIgnored private var playlistIndex = 0
    @ObservationIgnored private var endObserver: Task<Void, Never>?
    @ObservationIgnored private var fadeTask: Task<Void, Never>?

    /// 0…1, applied on every start so a mid-session change takes effect next block.
    var volume: Double = 0.6
    var shuffle: Bool = true

    private static let fadeIn: TimeInterval = 1.2
    private static let fadeOut: TimeInterval = 2.0

    /// Extensions AVFoundation can decode on macOS. Anything else in a chosen
    /// folder is skipped rather than queued and failed.
    static let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac", "mp4",
    ]

    // MARK: - Configuration

    func configure(source: Source, volume: Double, shuffle: Bool) {
        self.volume = volume
        self.shuffle = shuffle
        guard source != self.source else { return }
        stopImmediately()
        self.source = source
        // Whatever was queued belonged to the old folder.
        playlist = []
        playlistIndex = 0
    }

    // MARK: - Playback

    /// Called when a focus block starts running.
    func start() {
        guard source != .none else { return }
        fadeTask?.cancel()

        do {
            let url = try resolveNextTrack()
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.volume = 0
            player.actionAtItemEnd = .pause
            self.player = player

            observeEnd()
            player.play()
            status = .playing(displayName(for: url))
            fade(to: Float(volume), duration: Self.fadeIn)
        } catch {
            status = .failed(error.localizedDescription)
            releaseScope()
        }
    }

    /// Called when the focus block ends, is paused, or is stopped.
    ///
    /// Fades rather than cuts: the silence arriving gradually is itself the
    /// signal that the phase changed, and an abrupt stop is startling when the
    /// point of the app is to protect concentration.
    func fadeOutAndStop() {
        guard player != nil else { return }
        fade(to: 0, duration: Self.fadeOut) { [weak self] in
            self?.stopImmediately()
        }
    }

    func stopImmediately() {
        fadeTask?.cancel()
        fadeTask = nil
        endObserver?.cancel()
        endObserver = nil
        player?.pause()
        player = nil
        releaseScope()
        status = .idle
    }

    /// Plays a few seconds so the user can check the source works without
    /// starting a real 25-minute block.
    func preview() {
        start()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            self?.fadeOutAndStop()
        }
    }

    // MARK: - Track selection

    private func resolveNextTrack() throws -> URL {
        switch source {
        case .none:
            throw MusicError.noSource

        case .stream(let url):
            return url

        case .file(let bookmarked):
            let url = try openScope(bookmarked)
            return url

        case .folder(let bookmarked):
            let folder = try openScope(bookmarked)
            if playlist.isEmpty {
                playlist = try Self.audioFiles(in: folder)
                guard !playlist.isEmpty else { throw MusicError.emptyFolder }
                if shuffle { playlist.shuffle() }
                playlistIndex = 0
            }
            let url = playlist[playlistIndex % playlist.count]
            playlistIndex += 1
            return url
        }
    }

    static func audioFiles(in folder: URL) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// A single file loops; a folder advances; a stream never ends so this
    /// never fires for one.
    private func observeEnd() {
        endObserver?.cancel()
        endObserver = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default
                .notifications(named: AVPlayerItem.didPlayToEndTimeNotification)
                .map({ _ in () })
            {
                guard let self, self.player != nil else { return }
                switch self.source {
                case .file:
                    self.player?.seek(to: .zero)
                    self.player?.play()
                case .folder:
                    self.advanceToNextTrack()
                case .stream, .none:
                    break
                }
            }
        }
    }

    private func advanceToNextTrack() {
        guard let next = try? resolveNextTrack() else { return }
        let item = AVPlayerItem(url: next)
        player?.replaceCurrentItem(with: item)
        player?.play()
        status = .playing(displayName(for: next))
    }

    // MARK: - Fading

    private func fade(to target: Float, duration: TimeInterval, then done: (() -> Void)? = nil) {
        fadeTask?.cancel()
        let steps = 48
        let stepNanos = UInt64(duration / Double(steps) * 1_000_000_000)
        fadeTask = Task { @MainActor [weak self] in
            guard let player = self?.player else { return }
            let start = player.volume
            for step in 1...steps {
                if Task.isCancelled { return }
                player.volume = start + (target - start) * Float(step) / Float(steps)
                try? await Task.sleep(nanoseconds: stepNanos)
            }
            done?()
        }
    }

    // MARK: - Sandbox scope

    /// Opens access to a bookmarked location. The caller must eventually hit
    /// `releaseScope()`; `stopImmediately()` does that on every path.
    private func openScope(_ url: URL) throws -> URL {
        releaseScope()
        guard url.startAccessingSecurityScopedResource() else {
            // A plain path inside the container needs no scope, so only treat
            // this as fatal for locations outside it.
            if FileManager.default.isReadableFile(atPath: url.path) { return url }
            throw MusicError.accessDenied(url.lastPathComponent)
        }
        scopedURL = url
        return url
    }

    private func releaseScope() {
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }

    private func displayName(for url: URL) -> String {
        source.isStream ? url.host() ?? url.absoluteString : url.deletingPathExtension().lastPathComponent
    }

    enum MusicError: LocalizedError {
        case noSource
        case emptyFolder
        case accessDenied(String)

        var errorDescription: String? {
            switch self {
            case .noSource:
                String(localized: "No music source selected.")
            case .emptyFolder:
                String(localized: "That folder has no playable audio files.")
            case .accessDenied(let name):
                String(localized: "Cadence can't open \(name). Choose it again in Settings.")
            }
        }
    }
}

extension MusicPlayer.Source {
    var isStream: Bool { if case .stream = self { true } else { false } }

    /// Rebuilds a source from what `AppSettings` persists. Bookmarks are
    /// resolved here rather than at pick time because the URL a bookmark
    /// resolves to can move between launches.
    static func restore(kind: MusicSourceKind, bookmark: Data?, streamURL: String) -> Self {
        switch kind {
        case .off:
            return .none
        case .stream:
            guard let url = URL(string: streamURL), url.scheme?.hasPrefix("http") == true else { return .none }
            return .stream(url)
        case .file, .folder:
            guard let bookmark else { return .none }
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return .none }
            return kind == .file ? .file(url) : .folder(url)
        }
    }
}
