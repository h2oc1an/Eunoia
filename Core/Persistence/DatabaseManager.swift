import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?

    // Table definitions
    let videos = Table("videos")
    let vocabularyEntries = Table("vocabulary_entries")
    let reviewRecords = Table("review_records")
    let videoBookmarks = Table("video_bookmarks")
    let downloadTasks = Table("download_tasks")

    // Video columns
    let videoId = Expression<String>("id")
    let videoTitle = Expression<String>("title")
    let videoLocalPath = Expression<String>("local_path")
    let videoThumbnailPath = Expression<String?>("thumbnail_path")
    let videoDuration = Expression<Double>("duration")
    let videoSubtitlePath = Expression<String?>("subtitle_path")
    let videoCreatedAt = Expression<String>("created_at")
    let videoLastPlayedAt = Expression<String?>("last_played_at")
    let videoLastPlaybackPosition = Expression<Double>("last_playback_position")
    let videoPlaybackRate = Expression<Double>("playback_rate")
    let videoDownloadTaskId = Expression<String?>("download_task_id")
    let videoSourceURL = Expression<String?>("source_url")
    let videoFileSize = Expression<Int64?>("file_size")

    // VocabularyEntry columns
    let vocabId = Expression<String>("id")
    let vocabWord = Expression<String>("word")
    let vocabMeaning = Expression<String?>("meaning")
    let vocabContext = Expression<String?>("context")
    let vocabSourceVideoId = Expression<String?>("source_video_id")
    let vocabSourceTimestamp = Expression<Double?>("source_timestamp")
    let vocabCreatedAt = Expression<String>("created_at")
    let vocabRepetitions = Expression<Int>("repetitions")
    let vocabEasinessFactor = Expression<Double>("easiness_factor")
    let vocabInterval = Expression<Int>("interval_days")
    let vocabNextReviewDate = Expression<String>("next_review_date")
    let vocabLastReviewDate = Expression<String?>("last_review_date")

    // ReviewRecord columns
    let reviewId = Expression<String>("id")
    let reviewVocabEntryId = Expression<String>("vocabulary_entry_id")
    let reviewDate = Expression<String>("review_date")
    let reviewQuality = Expression<Int>("quality")
    let reviewRepetition = Expression<Int>("repetition")
    let reviewEasinessFactor = Expression<Double>("easiness_factor")
    let reviewInterval = Expression<Int>("interval_days")

    // VideoBookmark columns
    let bookmarkId = Expression<String>("id")
    let bookmarkVideoId = Expression<String>("video_id")
    let bookmarkTimestamp = Expression<Double>("timestamp")
    let bookmarkNote = Expression<String?>("note")
    let bookmarkCreatedAt = Expression<String>("created_at")

    // DownloadTask columns
    let downloadId = Expression<String>("id")
    let downloadSourceType = Expression<String>("source_type")
    let downloadSourceURL = Expression<String>("source_url")
    let downloadTitle = Expression<String>("title")
    let downloadStatus = Expression<String>("status")
    let downloadProgress = Expression<Double>("progress")
    let downloadLocalPath = Expression<String?>("local_path")
    let downloadTemporaryPath = Expression<String?>("temporary_path")
    let downloadTotalBytes = Expression<Int64?>("total_bytes")
    let downloadedBytes = Expression<Int64?>("downloaded_bytes")
    let downloadErrorMessage = Expression<String?>("error_message")
    let downloadCreatedAt = Expression<String>("created_at")
    let downloadCompletedAt = Expression<String?>("completed_at")
    let downloadMetadataJSON = Expression<String?>("metadata_json")
    let downloadFormatJSON = Expression<String?>("format_json")

    private init() {
        do {
            let path = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("SpeakingEnglish.sqlite3")
                .path
            db = try Connection(path)
            createTables()
        } catch {
            print("Database connection failed: \(error)")
        }
    }

    private func createTables() {
        guard let db = db else { return }

        do {
            // Create videos table
            try db.run(videos.create(ifNotExists: true) { t in
                t.column(videoId, primaryKey: true)
                t.column(videoTitle)
                t.column(videoLocalPath)
                t.column(videoThumbnailPath)
                t.column(videoDuration)
                t.column(videoSubtitlePath)
                t.column(videoCreatedAt)
                t.column(videoLastPlayedAt)
                t.column(videoLastPlaybackPosition, defaultValue: 0)
                t.column(videoPlaybackRate, defaultValue: 1.0)
                t.column(videoDownloadTaskId)
                t.column(videoSourceURL)
                t.column(videoFileSize)
            })

            // Create vocabulary_entries table
            try db.run(vocabularyEntries.create(ifNotExists: true) { t in
                t.column(vocabId, primaryKey: true)
                t.column(vocabWord)
                t.column(vocabMeaning)
                t.column(vocabContext)
                t.column(vocabSourceVideoId)
                t.column(vocabSourceTimestamp)
                t.column(vocabCreatedAt)
                t.column(vocabRepetitions, defaultValue: 0)
                t.column(vocabEasinessFactor, defaultValue: 2.5)
                t.column(vocabInterval, defaultValue: 0)
                t.column(vocabNextReviewDate)
                t.column(vocabLastReviewDate)
            })

            // Create review_records table
            try db.run(reviewRecords.create(ifNotExists: true) { t in
                t.column(reviewId, primaryKey: true)
                t.column(reviewVocabEntryId)
                t.column(reviewDate)
                t.column(reviewQuality)
                t.column(reviewRepetition)
                t.column(reviewEasinessFactor)
                t.column(reviewInterval)
            })

            // Create video_bookmarks table
            try db.run(videoBookmarks.create(ifNotExists: true) { t in
                t.column(bookmarkId, primaryKey: true)
                t.column(bookmarkVideoId)
                t.column(bookmarkTimestamp)
                t.column(bookmarkNote)
                t.column(bookmarkCreatedAt)
            })

            // Create/migrate download_tasks table
            migrateDownloadTasksTable(db)

        } catch {
            print("Table creation failed: \(error)")
        }
    }

    // MARK: - Download Tasks Table Migration
    private func migrateDownloadTasksTable(_ db: Connection) {
        // 检查旧表是否存在（通过查询旧列名 torrent_info）
        let hasOldSchema: Bool
        do {
            let columns = try db.prepare("PRAGMA table_info(download_tasks)")
            let columnNames = Set(columns.compactMap { row -> String? in
                if let name = row[1] as? String { return name }
                return nil
            })
            hasOldSchema = columnNames.contains("torrent_info") || columnNames.contains("source_content")
        } catch {
            hasOldSchema = false
        }

        if hasOldSchema {
            // 旧表存在，删掉重建（下载功能原本就不可用，数据可丢弃）
            try? db.run(downloadTasks.drop(ifExists: true))
        }

        // 创建新表
        do {
            try db.run(downloadTasks.create(ifNotExists: true) { t in
                t.column(downloadId, primaryKey: true)
                t.column(downloadSourceType)
                t.column(downloadSourceURL)
                t.column(downloadTitle)
                t.column(downloadStatus)
                t.column(downloadProgress, defaultValue: 0)
                t.column(downloadLocalPath)
                t.column(downloadTemporaryPath)
                t.column(downloadTotalBytes)
                t.column(downloadedBytes)
                t.column(downloadErrorMessage)
                t.column(downloadCreatedAt)
                t.column(downloadCompletedAt)
                t.column(downloadMetadataJSON)
                t.column(downloadFormatJSON)
            })
        } catch {
            print("download_tasks table creation failed: \(error)")
        }
    }

    func getConnection() -> Connection? {
        return db
    }
}

// Date formatting helpers
extension DatabaseManager {
    static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func dateToString(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    static func stringToDate(_ string: String) -> Date {
        return dateFormatter.date(from: string) ?? Date()
    }
}
