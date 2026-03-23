import Foundation

/// Watches ~/.claude/usage_cache.json for changes using GCD file system events.
/// When the file is modified (or created), it fires a callback.
final class FileMonitor {
    private let filePath: String
    private let directoryPath: String
    private let onChange: () -> Void

    private var fileSource: DispatchSourceFileSystemObject?
    private var dirSource: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "com.claudeusagebar.filemonitor", qos: .utility)

    init(onChange: @escaping () -> Void) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.filePath = "\(home)/.claude/usage_cache.json"
        self.directoryPath = "\(home)/.claude"
        self.onChange = onChange
    }

    /// Start monitoring. Call once on init.
    func start() {
        queue.async { [weak self] in
            self?.setupWatch()
        }
    }

    /// Stop monitoring and release resources.
    func stop() {
        queue.async { [weak self] in
            self?.cancelAll()
        }
    }

    // MARK: - Private

    private func setupWatch() {
        cancelAll()

        if FileManager.default.fileExists(atPath: filePath) {
            watchFile()
        } else {
            // File doesn't exist yet — watch the directory for creation
            watchDirectory()
        }
    }

    private func watchFile() {
        let fd = open(filePath, O_EVTONLY)
        guard fd >= 0 else {
            // Can't open the file — fall back to directory watching
            watchDirectory()
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced (common with atomic writes) — re-establish watch
                source.cancel()
                close(fd)
                // Brief delay to let the new file settle
                self.queue.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.setupWatch()
                }
                self.onChange()
            } else {
                self.onChange()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.fileSource = source
        source.resume()
    }

    private func watchDirectory() {
        // Ensure the directory exists
        guard FileManager.default.fileExists(atPath: directoryPath) else {
            // Directory doesn't exist — retry later
            queue.asyncAfter(deadline: .now() + 5) { [weak self] in
                self?.setupWatch()
            }
            return
        }

        let fd = open(directoryPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Check if our target file now exists
            if FileManager.default.fileExists(atPath: self.filePath) {
                source.cancel()
                close(fd)
                self.watchFile()
                self.onChange()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        self.dirSource = source
        source.resume()
    }

    private func cancelAll() {
        fileSource?.cancel()
        fileSource = nil
        dirSource?.cancel()
        dirSource = nil
    }

    deinit {
        cancelAll()
    }
}
