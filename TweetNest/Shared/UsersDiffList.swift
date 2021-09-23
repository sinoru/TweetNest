//
//  UsersDiffList.swift
//  UsersDiffList
//
//  Created by Jaehong Kang on 2021/08/09.
//

import SwiftUI
import TweetNestKit
import OrderedCollections

struct UsersDiffList: View {
    @FetchRequest private var userDetails: FetchedResults<UserDetail>

    let title: Text
    let diffKeyPath: KeyPath<UserDetail, [String]?>

    @State private var searchQuery: String = ""

    @ViewBuilder private var usersDiffList: some View {
        List(userDetails) { userDetail in
            let userDetailIndex = userDetails.firstIndex(of: userDetail)
            let previousUserDetailIndex = userDetailIndex.flatMap { $0 + 1 }
            let previousUserDetail = previousUserDetailIndex.flatMap { userDetails.indices.contains($0) ? userDetails[$0] : nil }

            let userIDs = OrderedSet(userDetail[keyPath: diffKeyPath] ?? [])
            let previousUserIDs = OrderedSet(previousUserDetail?[keyPath: diffKeyPath] ?? [])

            let appendedUserIDs = userIDs.subtracting(previousUserIDs)
            let removedUserIDs = previousUserIDs.subtracting(userIDs)

            if appendedUserIDs.isEmpty == false || removedUserIDs.isEmpty == false {
                Section {
                    ForEach(appendedUserIDs, id: \.self) { userID in
                        UserRow(userID: userID, searchQuery: searchQuery) {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.green)
                        }
                    }

                    ForEach(removedUserIDs, id: \.self) { userID in
                        UserRow(userID: userID, searchQuery: searchQuery) {
                            Image(systemName: "person.badge.minus")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text(verbatim: userDetail.creationDate?.formatted(date: .abbreviated, time: .standard) ?? userDetail.objectID.description)
                }
            }
        }
        .searchable(text: $searchQuery)
    }

    var body: some View {
        #if os(macOS)
        NavigationView {
            usersDiffList
                .listStyle(.plain)
                .navigationTitle(title)
        }
        .navigationViewStyle(.columns)
        #else
        usersDiffList
            .navigationTitle(title)
        #endif
    }

    init(user: User?, diffKeyPath: KeyPath<UserDetail, [String]?>, title: Text) {
        self._userDetails = FetchRequest(
            fetchRequest: {
                let fetchRequest = UserDetail.fetchRequest()
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    user.flatMap { NSPredicate(format: "user == %@", $0.objectID) } ?? NSPredicate(value: false),
                    diffKeyPath._kvcKeyPathString.flatMap { NSPredicate(format: "%K != NULL", $0) },
                ].compactMap({ $0 }))
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \UserDetail.creationDate, ascending: false),
                ]
                if let keyPathString = diffKeyPath._kvcKeyPathString {
                    fetchRequest.propertiesToFetch = ["creationDate", keyPathString]
                } else {
                    fetchRequest.returnsObjectsAsFaults = false
                }

                return fetchRequest
            }()
        )

        self.title = title
        self.diffKeyPath = diffKeyPath
    }
}

//struct UsersDiffList_Previews: PreviewProvider {
//    static var previews: some View {
//        UsersDiffList()
//    }
//}
