//
//  Account.swift
//  TweetNestKit
//
//  Created by Jaehong Kang on 2021/02/24.
//

import Foundation
import CoreData
import Twitter

public class Account: NSManagedObject {

}

extension Account {
    @NSManaged public private(set) var users: [User]? // The accessor of the users property.
}

extension Account {
    var credential: Twitter.Session.Credential? {
        guard
            let token = token,
            let tokenSecret = tokenSecret
        else {
            return nil
        }

        return Twitter.Session.Credential(token: token, tokenSecret: tokenSecret)
    }
}

extension Account {
    struct Key {
        static let preferences = "preferences"
    }

    public dynamic var preferences: Preferences {
        get {
            willAccessValue(forKey: Key.preferences)
            defer { didAccessValue(forKey: Key.preferences) }

            let preferences = primitiveValue(forKey: Key.preferences) as? Preferences

            guard let preferences = preferences else {
                self.preferences = Preferences()
                return self.preferences
            }

            return preferences
        }
        set {
            willChangeValue(forKey: Key.preferences)
            defer { didChangeValue(forKey: Key.preferences) }

            setPrimitiveValue(newValue, forKey: Key.preferences)
        }
    }
}

extension Account {
    public var displayUserID: String? {
        return userID.flatMap { "#\(Int64($0)?.twnk_formatted() ?? $0)" }
    }
}
