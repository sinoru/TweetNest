//
//  User.swift
//  TweetNestKit
//
//  Created by Jaehong Kang on 2021/02/25.
//

import Foundation
import OrderedCollections
import CoreData
import Twitter

public class User: NSManagedObject {
    public dynamic var sortedUserDetails: OrderedSet<UserDetail>? {
        userDetails.flatMap {
            OrderedSet(
                $0.lazy
                    .compactMap { $0 as? UserDetail }
                    .sorted { $0.creationDate ?? .distantPast < $1.creationDate ?? .distantPast }
            )
        }
    }

    public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        let keyPaths = super.keyPathsForValuesAffectingValue(forKey: key)
        switch key {
        case "sortedUserDetails":
            return keyPaths.union(Set(["userDetails"]))
        default:
            return keyPaths
        }
    }
}

extension User {
    @NSManaged public private(set) var accounts: [Account]? // The accessor of the accounts property.
}

extension User {
    public var displayID: String? {
        return id.flatMap { "#\(Int64($0)?.twnk_formatted() ?? $0)" }
    }
}
