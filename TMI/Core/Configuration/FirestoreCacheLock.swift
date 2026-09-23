import Darwin
import Foundation

/// Detects whether another process already holds Firestore's on-disk cache.
///
/// Firestore keeps its persistent cache in a LevelDB database guarded by an
/// `fcntl` lock. If a second copy of the app opens the same container (a Mac
/// build launched from Xcode while another copy is still running, for example),
/// Firestore aborts the process with "Failed to open LevelDB database … LOCK:
/// Resource temporarily unavailable". Probing the lock before Firestore starts
/// lets the app fall back to a memory cache instead of crashing.
nonisolated enum FirestoreCacheLock {
    /// The LevelDB lock file for the default database of `projectID`.
    static func lockFileURL(
        projectID: String,
        appName: String = "__FIRAPP_DEFAULT",
        applicationSupport: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> URL? {
        applicationSupport?
            .appending(path: "firestore", directoryHint: .isDirectory)
            .appending(path: appName, directoryHint: .isDirectory)
            .appending(path: projectID, directoryHint: .isDirectory)
            .appending(path: "main", directoryHint: .isDirectory)
            .appending(path: "LOCK", directoryHint: .notDirectory)
    }

    /// The process ID holding the lock, or `nil` when the cache is free.
    ///
    /// Uses `F_GETLK`, which reports a conflicting lock without taking one.
    /// Call it before Firestore opens the database: closing a descriptor drops
    /// every `fcntl` lock this process holds on the file, including LevelDB's.
    static func holder(of lockFile: URL) -> pid_t? {
        let descriptor = open(lockFile.path(percentEncoded: false), O_RDWR)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }

        var probe = flock()
        probe.l_type = Int16(F_WRLCK)
        probe.l_whence = Int16(SEEK_SET)
        probe.l_start = 0
        probe.l_len = 0
        guard fcntl(descriptor, F_GETLK, &probe) == 0, probe.l_type != Int16(F_UNLCK) else {
            return nil
        }
        return probe.l_pid
    }
}
