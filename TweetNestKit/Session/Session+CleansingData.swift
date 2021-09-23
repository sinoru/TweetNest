//
//  Session+CleansingData.swift
//  Session+CleansingData
//
//  Created by Jaehong Kang on 2021/08/29.
//

import Foundation
import CoreData
import OrderedCollections

extension Session {
    private nonisolated var persistentContainerNewBackgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.undoManager = nil
        context.automaticallyMergesChangesFromParent = false

        return context
    }

    public nonisolated func cleansingAllData() async throws {
        let context = persistentContainerNewBackgroundContext

        try await cleansingAllAccounts(context: context)
        try await cleansingAllUsersAndUserDetails(context: context)
        try await cleansingAllDataAssets(context: context)

        await preferences.lastCleansed = Date()
    }

    public nonisolated func cleansingAllAccounts(context: NSManagedObjectContext? = nil) async throws {
        let context = context ?? persistentContainerNewBackgroundContext

        let accountObjectIDs: [NSManagedObjectID] = try await context.perform(schedule: .enqueued) {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: Account.entity().name!)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \Account.creationDate, ascending: false),
            ]
            fetchRequest.resultType = .managedObjectIDResultType

            return try context.fetch(fetchRequest)
        }

        for accountObjectID in accountObjectIDs {
            try Task.checkCancellation()
            try await cleansingAccount(for: accountObjectID, context: context)
        }
    }

    public nonisolated func cleansingAccount(for accountObjectID: NSManagedObjectID, context: NSManagedObjectContext? = nil) async throws {
        let context = context ?? persistentContainerNewBackgroundContext

        try await context.perform(schedule: .enqueued) {
            guard
                let account = try? context.existingObject(with: accountObjectID) as? Account,
                let accountToken = account.token,
                let accountTokenSecret = account.tokenSecret
            else {
                return
            }

            let accountFetchRequest: NSFetchRequest<Account> = Account.fetchRequest()
            accountFetchRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "token == %@", accountToken),
                    NSPredicate(format: "tokenSecret == %@", accountTokenSecret),
                ]
            )
            accountFetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let accounts = try context.fetch(accountFetchRequest)

            guard accounts.count > 1 else { return }

            let targetAccount = accounts.first ?? account

            targetAccount.creationDate = accounts.first?.creationDate ?? account.creationDate
            targetAccount.preferringSortOrder = accounts.first?.preferringSortOrder ?? account.preferringSortOrder
            targetAccount.userID = accounts.last?.userID ?? account.userID

            for account in accounts {
                guard account != targetAccount else { continue }

                targetAccount.preferences = .init(
                    fetchBlockingUsers: targetAccount.preferences.fetchBlockingUsers || account.preferences.fetchBlockingUsers
                )

                context.delete(account)
            }

            try context.save()
        }
    }

    nonisolated func cleansingAllUsersAndUserDetails(context: NSManagedObjectContext) async throws {
        let userObjectIDs: [NSManagedObjectID] = try await context.perform(schedule: .enqueued) {
            let userFetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: User.entity().name!)
            userFetchRequest.resultType = .managedObjectIDResultType
            userFetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            return try context.fetch(userFetchRequest)
        }

        for userObjectID in userObjectIDs {
            try Task.checkCancellation()
            try await self.cleansingUser(for: userObjectID, context: context)
            try await self.cleansingUserDetails(for: userObjectID, context: context)
        }
    }

    public nonisolated func cleansingUser(for userObjectID: NSManagedObjectID, context: NSManagedObjectContext? = nil) async throws {
        let context = context ?? persistentContainerNewBackgroundContext

        try await context.perform(schedule: .enqueued) {
            guard
                let user = try? context.existingObject(with: userObjectID) as? User,
                let userID = user.id
            else {
                return
            }

            let userFetchRequest: NSFetchRequest<User> = User.fetchRequest()
            userFetchRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "id == %@", userID),
                ]
            )
            userFetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "creationDate", ascending: true),
                NSSortDescriptor(key: "lastUpdateEndDate", ascending: true),
            ]

            let users = try context.fetch(userFetchRequest)

            guard users.count > 1 else { return }

            let targetUser = users.first ?? user

            for user in users {
                guard user != targetUser else { continue }

                targetUser.creationDate = [targetUser.creationDate, user.creationDate].lazy.compactMap({$0}).min()
                targetUser.lastUpdateEndDate = [targetUser.lastUpdateEndDate, user.lastUpdateEndDate].lazy.compactMap({$0}).max()
                targetUser.lastUpdateStartDate = [targetUser.lastUpdateStartDate, user.lastUpdateStartDate].lazy.compactMap({$0}).max()
                targetUser.modificationDate = [targetUser.modificationDate, user.modificationDate].lazy.compactMap({$0}).max()

                targetUser.addToUserDetails(user.userDetails ?? [])

                context.delete(user)
            }

            try context.save()
        }
    }

    nonisolated func cleansingUserDetails(for userObjectID: NSManagedObjectID, context: NSManagedObjectContext? = nil) async throws {
        let context = context ?? persistentContainerNewBackgroundContext

        try await context.perform(schedule: .enqueued) {
            guard
                let user = try? context.existingObject(with: userObjectID) as? User
            else {
                return
            }

            var userDetails = OrderedSet(user.sortedUserDetails ?? [])

            for (index, userDetail) in userDetails.enumerated() {
                let previousUserIndex = index - 1
                let previousUserDetail = userDetails.indices.contains(previousUserIndex) ? userDetails[previousUserIndex] : nil

                if previousUserDetail ~= userDetail {
                    userDetails.remove(userDetail)
                    context.delete(userDetail)
                }
            }

            try context.save()
        }
    }

    nonisolated func cleansingAllDataAssets(context: NSManagedObjectContext) async throws {
        let dataAssetObjectIDs: [NSManagedObjectID] = try await context.perform(schedule: .enqueued) {
            let dataAssetsFetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: DataAsset.entity().name!)
            dataAssetsFetchRequest.resultType = .managedObjectIDResultType
            dataAssetsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            return try context.fetch(dataAssetsFetchRequest)
        }

        for dataAssetObjectID in dataAssetObjectIDs {
            try Task.checkCancellation()
            try await self.cleansingDataAsset(for: dataAssetObjectID, context: context)
        }
    }

    public nonisolated func cleansingDataAsset(for dataAssetObjectID: NSManagedObjectID, context: NSManagedObjectContext? = nil) async throws {
        let context = context ?? persistentContainerNewBackgroundContext

        try await context.perform(schedule: .enqueued) {
            guard
                let dataAsset = try? context.existingObject(with: dataAssetObjectID) as? DataAsset,
                let dataAssetURL = dataAsset.url,
                let dataAssetDataSHA512Hash = dataAsset.dataSHA512Hash
            else {
                return
            }

            let dataAssetsFetchRequest: NSFetchRequest<DataAsset> = DataAsset.fetchRequest()
            dataAssetsFetchRequest.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "url == %@", dataAssetURL as NSURL),
                    NSPredicate(format: "dataSHA512Hash == %@", dataAssetDataSHA512Hash as NSData),
                ]
            )
            dataAssetsFetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let dataAssets = try context.fetch(dataAssetsFetchRequest)

            guard dataAssets.count > 1 else { return }

            let targetDataAsset = dataAssets.first ?? dataAsset

            for dataAsset in dataAssets {
                guard dataAsset != targetDataAsset else { continue }

                context.delete(dataAsset)
            }

            try context.save()
        }
    }
}
