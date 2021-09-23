//
//  Session.swift
//  TweetNestKit
//
//  Created by Jaehong Kang on 2021/02/23.
//

import CoreData
import CloudKit
import OrderedCollections
import UnifiedLogging
import Twitter

public actor Session {
    public static let shared = Session()

    static let cloudKitIdentifier = "iCloud.\(Bundle.tweetNestKit.bundleIdentifier!)"
    static let accountsCloudKitIdentifier = "iCloud.\(Bundle.tweetNestKit.bundleIdentifier!).accounts"
    static let dataAssetsCloudKitIdentifier = "iCloud.\(Bundle.tweetNestKit.bundleIdentifier!).dataAssets"
    static let applicationGroupIdentifier = "group.\(Bundle.tweetNestKit.bundleIdentifier!)"

    private var _twitterAPIConfiguration: AsyncLazy<TwitterAPIConfiguration>
    public var twitterAPIConfiguration: TwitterAPIConfiguration {
        get async throws {
            try await _twitterAPIConfiguration.wrappedValue
        }
    }

    private(set) nonisolated lazy var urlSession = URLSession(configuration: .twnk_default)

    private let inMemory: Bool

    public private(set) nonisolated lazy var persistentContainer = PersistentContainer(inMemory: inMemory)
    public private(set) nonisolated lazy var backgroundTaskScheduler = BackgroundTaskScheduler(session: self)

    private nonisolated lazy var persistentStoreRemoteChangeNotification = NotificationCenter.default
        .publisher(for: .NSPersistentStoreRemoteChange, object: persistentContainer.persistentStoreCoordinator)
        .sink { [weak self] _ in
            self?.handlePersistentStoreRemoteChanges()
        }

    private(set) var twitterSessions = [URL: Twitter.Session]()

    private init(twitterAPIConfiguration: @escaping () async throws -> TwitterAPIConfiguration, inMemory: Bool = false) {
        _twitterAPIConfiguration = .init({ try await twitterAPIConfiguration() })
        self.inMemory = inMemory
    }

    deinit {
        Task {
            await backgroundTaskScheduler.invalidate()
        }

        urlSession.invalidateAndCancel()
    }
}

extension Session {
    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Session.applicationGroupIdentifier)!
    }

    static var containerLibraryURL: URL {
        containerURL.appendingPathComponent("Library")
    }

    static var containerCacheURL: URL {
        containerLibraryURL
            .appendingPathComponent("Caches")
            .appendingPathComponent(Bundle.tweetNestKit.bundleIdentifier!)
    }

    static var containerApplicationSupportURL: URL {
        let containerApplicationSupportURL = containerLibraryURL
            .appendingPathComponent("Application Support")
            .appendingPathComponent(Bundle.tweetNestKit.bundleIdentifier!)

        // Migration START
        let oldURL = Session.containerURL
            .appendingPathComponent("Application Support")
            .appendingPathComponent(Bundle.tweetNestKit.name!)
        let newURL = containerApplicationSupportURL
        if FileManager.default.fileExists(atPath: oldURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: newURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try FileManager.default.moveItem(at: oldURL, to: newURL)
                try FileManager.default.removeItem(at: oldURL.deletingLastPathComponent())
            } catch {
                Logger(label: Bundle.tweetNestKit.bundleIdentifier!, category: String(reflecting: Self.self))
                    .error("\(error as NSError, privacy: .public)")
            }
        }
        // Migration END

        return containerApplicationSupportURL
    }
}

extension Session {
    public convenience init(inMemory: Bool = false) {
        self.init(twitterAPIConfiguration: { try await .iCloud }, inMemory: inMemory)

        if inMemory == false {
            _ = persistentStoreRemoteChangeNotification
        }
    }

    public convenience init(twitterAPIConfiguration: @autoclosure @escaping () async throws -> TwitterAPIConfiguration, inMemory: Bool = false) async {
        self.init(twitterAPIConfiguration: { try await twitterAPIConfiguration() }, inMemory: inMemory)

        if inMemory == false {
            _ = persistentStoreRemoteChangeNotification
        }
    }

    public convenience init(twitterAPIConfiguration: TwitterAPIConfiguration, inMemory: Bool = false) {
        self.init(twitterAPIConfiguration: { twitterAPIConfiguration }, inMemory: inMemory)

        if inMemory == false {
            _ = persistentStoreRemoteChangeNotification
        }
    }
}

extension Session {
    public func twitterSession(for accountObjectID: NSManagedObjectID? = nil) async throws -> Twitter.Session {
        let twitterAPIConfiguration = try await twitterAPIConfiguration

        guard let accountObjectID = accountObjectID, accountObjectID.isTemporaryID == false else {
            return Twitter.Session(consumerKey: twitterAPIConfiguration.apiKey, consumerSecret: twitterAPIConfiguration.apiKeySecret)
        }

        guard let twitterSession: Twitter.Session = twitterSessions[accountObjectID.uriRepresentation()] else {
            let twitterSession = Twitter.Session(twitterAPIConfiguration: twitterAPIConfiguration)
            updateTwitterSession(twitterSession, for: accountObjectID)

            try await twitterSession.updateCredential(credential(for: accountObjectID))

            return twitterSession
        }

        return twitterSession
    }

    func updateTwitterSession(_ twitterSession: Twitter.Session?, for accountObjectID: NSManagedObjectID) {
        guard accountObjectID.isTemporaryID == false else {
            return
        }

        twitterSessions[accountObjectID.uriRepresentation()] = twitterSession
    }
}
