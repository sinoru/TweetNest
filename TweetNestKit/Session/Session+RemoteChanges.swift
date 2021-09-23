//
//  Session+RemoteChanges.swift
//  Session+RemoteChanges
//
//  Created by Jaehong Kang on 2021/09/01.
//

import Foundation
import Twitter
import CoreData
import UserNotifications
import OrderedCollections
import UnifiedLogging

extension Session {
    private nonisolated var logger: Logger {
        Logger(subsystem: Bundle.tweetNestKit.bundleIdentifier!, category: "remote-changes")
    }

    @discardableResult
    private func updateLastPersistentHistoryTransactionTimestamp(_ newValue: Date?) throws -> Date? {
        let oldValue = TweetNestKitUserDefaults.standard.lastPersistentHistoryTransactionTimestamp

        TweetNestKitUserDefaults.standard.lastPersistentHistoryTransactionTimestamp = newValue

        return oldValue
    }

    private var persistentHistoryTransactions: (transactions: [NSPersistentHistoryTransaction], lastPersistentHistoryTransactionDate: Date?, context: NSManagedObjectContext)? {
        get throws {
            let lastPersistentHistoryTransactionDate = try updateLastPersistentHistoryTransactionTimestamp(nil)
            let fetchHistoryRequest = NSPersistentHistoryChangeRequest.fetchHistory(
                after: lastPersistentHistoryTransactionDate ?? .distantPast
            )

            let context = persistentContainer.newBackgroundContext()
            context.undoManager = nil

            guard
                let persistentHistoryResult = try context.execute(fetchHistoryRequest) as? NSPersistentHistoryResult,
                let transactions = persistentHistoryResult.result as? [NSPersistentHistoryTransaction]
            else {
                return nil
            }

            try updateLastPersistentHistoryTransactionTimestamp(transactions.last?.timestamp ?? lastPersistentHistoryTransactionDate)

            return (transactions, lastPersistentHistoryTransactionDate, context)
        }
    }

    nonisolated func handlePersistentStoreRemoteChanges() {
        Task.detached(priority: .utility) { [self] in
            await withExtendedBackgroundExecution {
                do {
                    guard
                        let transactions = try await persistentHistoryTransactions,
                        let lastPersistentHistoryTransactionDate = transactions.lastPersistentHistoryTransactionDate
                    else {
                        return
                    }

                    do {
                        try Task.checkCancellation()

                        try await withThrowingTaskGroup(of: Void.self) { taskGroup in
                            taskGroup.addTask { try await handleUserDetailChanges(transactions: transactions.transactions, context: transactions.context) }
                            taskGroup.addTask { try await handleAccountChanges(transactions: transactions.transactions, context: transactions.context) }
                            taskGroup.addTask { try await handleUserChanges(transactions: transactions.transactions, context: transactions.context) }
                            taskGroup.addTask { try await handleDataAssetsChanges(transactions: transactions.transactions, context: transactions.context) }

                            try await taskGroup.waitForAll()
                        }
                    } catch {
                        if error is CancellationError {
                            do {
                                try await updateLastPersistentHistoryTransactionTimestamp(lastPersistentHistoryTransactionDate)
                            } catch {
                                logger.error("Error occurred while rollback persistent history token: \(error as NSError, privacy: .public)")
                            }
                        }

                        throw error
                    }
                } catch {
                    logger.error("Error occurred while handle persistent store remote changes: \(error as NSError, privacy: .public)")
                }
            }
        }
    }

    private nonisolated func handleAccountChanges(transactions: [NSPersistentHistoryTransaction], context: NSManagedObjectContext) async throws {
        let accountChangesByObjectID: OrderedDictionary<NSManagedObjectID, NSPersistentHistoryChange> = OrderedDictionary(
            Array(
                transactions
                    .lazy
                    .flatMap { $0.changes ?? [] }
                    .filter { $0.changedObjectID.entity == Account.entity() }
                    .map { ($0.changedObjectID, $0) }
            ),
            uniquingKeysWith: { $1 }
        )

        for (accountObjectID, change) in accountChangesByObjectID {
            try Task.checkCancellation()

            func updateCredential() async {
                let credential: Twitter.Session.Credential? = await context.perform(schedule: .enqueued) {
                    guard let account = try? context.existingObject(with: accountObjectID) as? Account else {
                        return nil
                    }

                    return account.credential
                }

                guard let twitterSession = await twitterSessions[accountObjectID.uriRepresentation()] else {
                    return
                }

                await twitterSession.updateCredential(credential)
            }

            func cleansingAccount() async {
                do {
                    try await self.cleansingAccount(for: accountObjectID, context: context)
                } catch {
                    logger.error("Error occurred while cleansing account: \(String(reflecting: error), privacy: .public)")
                }
            }

            switch change.changeType {
            case .insert:
                await cleansingAccount()
            case .update:
                await updateCredential()
            case .delete:
                break
            @unknown default:
                break
            }
        }
    }

    private nonisolated func handleUserChanges(transactions: [NSPersistentHistoryTransaction], context: NSManagedObjectContext) async throws {
        let userChangesByObjectID: OrderedDictionary<NSManagedObjectID, NSPersistentHistoryChange> = OrderedDictionary(
            Array(
                transactions
                    .lazy
                    .flatMap { $0.changes ?? [] }
                    .filter { $0.changedObjectID.entity == User.entity() }
                    .map { ($0.changedObjectID, $0) }
            ),
            uniquingKeysWith: { $1 }
        )

        for (userObjectID, change) in userChangesByObjectID {
            try Task.checkCancellation()

            func cleansingUser() async {
                do {
                    try await self.cleansingUser(for: userObjectID, context: context)
                } catch {
                    logger.error("Error occurred while cleansing user: \(String(reflecting: error), privacy: .public)")
                }
            }

            switch change.changeType {
            case .insert:
                await cleansingUser()
            case .update:
                break
            case .delete:
                break
            @unknown default:
                break
            }
        }
    }

    private nonisolated func handleDataAssetsChanges(transactions: [NSPersistentHistoryTransaction], context: NSManagedObjectContext) async throws {
        let dataAssetChangesByObjectID: OrderedDictionary<NSManagedObjectID, NSPersistentHistoryChange> = OrderedDictionary(
            Array(
                transactions
                    .lazy
                    .flatMap { $0.changes ?? [] }
                    .filter { $0.changedObjectID.entity == DataAsset.entity() }
                    .map { ($0.changedObjectID, $0) }
            ),
            uniquingKeysWith: { $1 }
        )

        for (dataAssetObjectID, change) in dataAssetChangesByObjectID {
            try Task.checkCancellation()

            func cleansingDataAsset() async {
                do {
                    try await self.cleansingDataAsset(for: dataAssetObjectID, context: context)
                } catch {
                    logger.error("Error occurred while cleansing data asset: \(String(reflecting: error), privacy: .public)")
                }
            }

            switch change.changeType {
            case .insert:
                await cleansingDataAsset()
            case .update:
                break
            case .delete:
                break
            @unknown default:
                break
            }
        }
    }

    private nonisolated func handleUserDetailChanges(transactions: [NSPersistentHistoryTransaction], context: NSManagedObjectContext) async throws {
        let userDetailChangesByObjectID: OrderedDictionary<NSManagedObjectID, NSPersistentHistoryChange> = OrderedDictionary(
            Array(
                transactions
                    .lazy
                    .flatMap { $0.changes ?? [] }
                    .filter { $0.changedObjectID.entity == UserDetail.entity() }
                    .map { ($0.changedObjectID, $0) }
            ),
            uniquingKeysWith: { $1 }
        )

        for (userDetailObjectID, change) in userDetailChangesByObjectID {
            try Task.checkCancellation()

            let (threadIdentifier, notificationIdentifier): (String?, String) = await context.perform(schedule: .enqueued) {
                guard
                    let userDetail = try? context.existingObject(with: userDetailObjectID) as? UserDetail,
                    let user = userDetail.user
                else {
                    return (nil, userDetailObjectID.uriRepresentation().absoluteString)
                }

                let threadIdentifier = user.id ?? user.objectID.uriRepresentation().absoluteString
                let notificationIdentifier = [threadIdentifier, userDetail.creationDate.flatMap { String($0.timeIntervalSince1970) }].compactMap { $0 }.joined(separator: "\t")

                return (threadIdentifier, notificationIdentifier.isEmpty ? userDetailObjectID.uriRepresentation().absoluteString : notificationIdentifier)
            }

            switch change.changeType {
            case .insert, .update:
                let notificationContent: UNNotificationContent? = await context.perform(schedule: .enqueued) {
                    guard
                        let newUserDetail = try? context.existingObject(with: userDetailObjectID) as? UserDetail,
                        Date(timeIntervalSinceNow: -(10 * 60)) <= (newUserDetail.creationDate ?? .distantPast),
                        let user = newUserDetail.user,
                        let sortedUserDetails = user.sortedUserDetails,
                        sortedUserDetails.count > 1,
                        let account = user.accounts?.max(by: { $0.creationDate ?? .distantPast < $1.creationDate ?? .distantPast })
                    else {
                        return nil
                    }

                    let oldUserDetailIndex = sortedUserDetails.lastIndex(of: newUserDetail).flatMap({ $0 - 1 })

                    let oldUserDetail = oldUserDetailIndex.flatMap { sortedUserDetails.indices.contains($0) == true ? sortedUserDetails[$0] : nil }

                    guard (oldUserDetail ~= newUserDetail) == false else {
                        return nil
                    }

                    let followingUserChanges = newUserDetail.followingUserChanges(from: oldUserDetail)
                    let followerUserChanges = newUserDetail.followerUserChanges(from: oldUserDetail)

                    let notificationContentTitle: String
                    if let name = newUserDetail.name, let displayUsername = newUserDetail.displayUsername, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        notificationContentTitle = "\(name) (\(displayUsername))"
                    } else if let displayUsername = newUserDetail.displayUsername {
                        notificationContentTitle = displayUsername
                    } else {
                        notificationContentTitle = account.userID.flatMap { Int64($0).flatMap { "#\($0.twnk_formatted())" } } ?? account.userID.flatMap { "#\($0)" } ?? account.objectID.uriRepresentation().absoluteString
                    }

                    let notificationContent = UNMutableNotificationContent()
                    notificationContent.title = notificationContentTitle

                    if let threadIdentifier = threadIdentifier {
                        notificationContent.threadIdentifier = threadIdentifier
                    }

                    var changes: [String] = []
                    if followingUserChanges.followingUsersCount > 0 {
                        changes.append(String(localized: "\(followingUserChanges.followingUsersCount, specifier: "%ld") new following(s)", bundle: .tweetNestKit, comment: "background-refresh notification body."))
                    }
                    if followingUserChanges.unfollowingUsersCount > 0 {
                        changes.append(String(localized: "\(followingUserChanges.unfollowingUsersCount, specifier: "%ld") new unfollowing(s)", bundle: .tweetNestKit, comment: "background-refresh notification body."))
                    }
                    if followerUserChanges.followerUsersCount > 0 {
                        changes.append(String(localized: "\(followerUserChanges.followerUsersCount, specifier: "%ld") new follower(s)", bundle: .tweetNestKit, comment: "background-refresh notification body."))
                    }
                    if followerUserChanges.unfollowerUsersCount > 0 {
                        changes.append(String(localized: "\(followerUserChanges.unfollowerUsersCount, specifier: "%ld") new unfollower(s)", bundle: .tweetNestKit, comment: "background-refresh notification body."))
                    }

                    if changes.isEmpty == false {
                        notificationContent.subtitle = String(localized: "New Data Available", bundle: .tweetNestKit, comment: "background-refresh notification.")
                        notificationContent.body = changes.formatted(.list(type: .and, width: .narrow))
                        notificationContent.sound = .default
                        notificationContent.interruptionLevel = .timeSensitive
                    } else {
                        notificationContent.body = String(localized: "New Data Available", bundle: .tweetNestKit, comment: "background-refresh notification.")
                        notificationContent.interruptionLevel = .passive
                    }

                    return notificationContent
                }

                guard let notificationContent = notificationContent else { continue }

                do {
                    try await UNUserNotificationCenter.current().add(
                        UNNotificationRequest(
                            identifier: notificationIdentifier,
                            content: notificationContent,
                            trigger: nil
                        )
                    )
                } catch {
                    logger.error("Error occurred while request notification: \(String(reflecting: error), privacy: .public)")
                }
            case .delete:
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
            @unknown default:
                break
            }
        }
    }
}
