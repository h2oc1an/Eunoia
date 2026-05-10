import Foundation
import SQLite

// MARK: - Download Task Repository
class DownloadTaskRepository {
    private let db: Connection?
    private let manager = DatabaseManager.shared

    init() {
        self.db = manager.getConnection()
    }

    // MARK: - Save
    func save(_ task: DownloadTask) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var metadataJSON: String?
        if let metadata = task.metadata {
            if let data = try? JSONEncoder().encode(metadata) {
                metadataJSON = String(data: data, encoding: .utf8)
            }
        }

        var formatJSON: String?
        if let format = task.selectedFormat {
            if let data = try? JSONEncoder().encode(format) {
                formatJSON = String(data: data, encoding: .utf8)
            }
        }

        let insert = manager.downloadTasks.insert(or: .replace,
            manager.downloadId <- task.id.uuidString,
            manager.downloadSourceType <- task.sourceType.rawValue,
            manager.downloadSourceURL <- task.sourceURL,
            manager.downloadTitle <- task.title,
            manager.downloadStatus <- task.status.rawValue,
            manager.downloadProgress <- task.progress,
            manager.downloadLocalPath <- task.localPath,
            manager.downloadTemporaryPath <- task.temporaryPath,
            manager.downloadTotalBytes <- task.totalBytes,
            manager.downloadedBytes <- task.downloadedBytes,
            manager.downloadErrorMessage <- task.errorMessage,
            manager.downloadCreatedAt <- DatabaseManager.dateToString(task.createdAt),
            manager.downloadCompletedAt <- task.completedAt.map { DatabaseManager.dateToString($0) },
            manager.downloadMetadataJSON <- metadataJSON,
            manager.downloadFormatJSON <- formatJSON
        )

        try db.run(insert)
    }

    // MARK: - Get All
    func getAll() throws -> [DownloadTask] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        var tasks: [DownloadTask] = []
        for row in try db.prepare(manager.downloadTasks.order(manager.downloadCreatedAt.desc)) {
            if let task = rowToTask(row) {
                tasks.append(task)
            }
        }
        return tasks
    }

    // MARK: - Get Active
    func getActive() throws -> [DownloadTask] {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.downloadTasks
            .filter([DownloadStatus.pending.rawValue,
                     DownloadStatus.parsing.rawValue,
                     DownloadStatus.downloading.rawValue,
                     DownloadStatus.paused.rawValue].contains(manager.downloadStatus))
            .order(manager.downloadCreatedAt.desc)

        var tasks: [DownloadTask] = []
        for row in try db.prepare(query) {
            if let task = rowToTask(row) {
                tasks.append(task)
            }
        }
        return tasks
    }

    // MARK: - Get By ID
    func getById(_ id: UUID) throws -> DownloadTask? {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let query = manager.downloadTasks.filter(manager.downloadId == id.uuidString)
        guard let row = try db.pluck(query) else { return nil }

        return rowToTask(row)
    }

    // MARK: - Update Status
    func updateStatus(_ id: UUID, status: DownloadStatus, progress: Double? = nil, downloadedBytes: Int64? = nil) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let task = manager.downloadTasks.filter(manager.downloadId == id.uuidString)

        if let progress = progress {
            try db.run(task.update(
                manager.downloadStatus <- status.rawValue,
                manager.downloadProgress <- progress,
                manager.downloadedBytes <- downloadedBytes
            ))
        } else {
            try db.run(task.update(manager.downloadStatus <- status.rawValue))
        }
    }

    // MARK: - Update Metadata
    func updateMetadata(_ id: UUID, metadata: VideoMetadata, title: String? = nil) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let jsonData = try JSONEncoder().encode(metadata)
        let metadataJSON = String(data: jsonData, encoding: .utf8)
        let task = manager.downloadTasks.filter(manager.downloadId == id.uuidString)

        var setters: [Setter] = [
            manager.downloadTotalBytes <- metadata.fileSize,
            manager.downloadMetadataJSON <- metadataJSON
        ]
        if let title = title {
            setters.append(manager.downloadTitle <- title)
        }

        try db.run(task.update(setters))
    }

    // MARK: - Update Completed
    func updateCompleted(_ id: UUID, localPath: String) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let task = manager.downloadTasks.filter(manager.downloadId == id.uuidString)
        try db.run(task.update(
            manager.downloadStatus <- DownloadStatus.completed.rawValue,
            manager.downloadProgress <- 1.0,
            manager.downloadLocalPath <- localPath,
            manager.downloadCompletedAt <- DatabaseManager.dateToString(Date())
        ))
    }

    // MARK: - Update Failed
    func updateFailed(_ id: UUID, error: String) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let task = manager.downloadTasks.filter(manager.downloadId == id.uuidString)
        try db.run(task.update(
            manager.downloadStatus <- DownloadStatus.failed.rawValue,
            manager.downloadErrorMessage <- error
        ))
    }

    // MARK: - Delete
    func delete(_ id: UUID) throws {
        guard let db = db else { throw RepositoryError.connectionFailed }

        let task = manager.downloadTasks.filter(manager.downloadId == id.uuidString)
        try db.run(task.delete())
    }

    // MARK: - Helper
    private func rowToTask(_ row: Row) -> DownloadTask? {
        guard let id = UUID(uuidString: row[manager.downloadId]),
              let sourceType = DownloadSourceType(rawValue: row[manager.downloadSourceType]),
              let status = DownloadStatus(rawValue: row[manager.downloadStatus]) else {
            return nil
        }

        var metadata: VideoMetadata?
        if let jsonString = row[manager.downloadMetadataJSON],
           let jsonData = jsonString.data(using: .utf8) {
            metadata = try? JSONDecoder().decode(VideoMetadata.self, from: jsonData)
        }

        var selectedFormat: VideoFormat?
        if let jsonString = row[manager.downloadFormatJSON],
           let jsonData = jsonString.data(using: .utf8) {
            selectedFormat = try? JSONDecoder().decode(VideoFormat.self, from: jsonData)
        }

        return DownloadTask(
            id: id,
            sourceType: sourceType,
            sourceURL: row[manager.downloadSourceURL],
            title: row[manager.downloadTitle],
            status: status,
            progress: row[manager.downloadProgress],
            localPath: row[manager.downloadLocalPath],
            temporaryPath: row[manager.downloadTemporaryPath],
            totalBytes: row[manager.downloadTotalBytes],
            downloadedBytes: row[manager.downloadedBytes],
            errorMessage: row[manager.downloadErrorMessage],
            createdAt: DatabaseManager.stringToDate(row[manager.downloadCreatedAt]),
            completedAt: row[manager.downloadCompletedAt].map { DatabaseManager.stringToDate($0) },
            metadata: metadata,
            selectedFormat: selectedFormat
        )
    }
}
