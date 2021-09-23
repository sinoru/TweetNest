//
//  UserRow.swift
//  TweetNest
//
//  Created by Jaehong Kang on 2021/09/23.
//

import SwiftUI
import TweetNestKit

struct UserRow<Icon: View>: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.account) private var account: Account?

    let userID: String
    let searchQuery: String?

    let icon: Icon?

    private var displayUserID: String {
        Int64(userID).flatMap { "#\($0.twnk_formatted())" } ?? "#\(userID)"
    }

    @FetchRequest private var latestUserDetails: FetchedResults<UserDetail>

    private var latestUserDetail: UserDetail? {
        latestUserDetails.first
    }

    private var shouldBeHidden: Bool {
        guard let searchQuery = searchQuery, searchQuery.isEmpty == false else {
            return false
        }

        guard
            userID.localizedCaseInsensitiveContains(searchQuery) == false &&
                displayUserID.localizedCaseInsensitiveContains(searchQuery) == false
        else {
            return false
        }

        let fetchRequest = UserDetail.fetchRequest()
        fetchRequest.resultType = .countResultType
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "user.id == %@", userID),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "username CONTAINS[cd] %@", searchQuery),
                NSPredicate(format: "name CONTAINS[cd] %@", searchQuery),
            ])
        ])

        guard
            let count = try? viewContext.count(for: fetchRequest),
            count == 0
        else {
            return false
        }

        return true
    }

    @ViewBuilder var userLabel: some View {
        Group {
            if let latestUserDetail = latestUserDetail {
                Label {
                    NavigationLink {
                        UserView(userID: userID)
                            .environment(\.account, account)
                    } label: {
                        TweetNestStack {
                            Text(verbatim: latestUserDetail.name ?? displayUserID)
                                .lineLimit(1)

                            if let username = latestUserDetail.username {
                                Text(verbatim: "@\(username)")
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .foregroundColor(Color.gray)
                            }
                        }
                    }
                } icon: {
                    ProfileImage(profileImageURL: latestUserDetail.profileImageURL)
                        .frame(width: 24, height: 24)
                }
            } else {
                NavigationLink {
                    UserView(userID: userID)
                        .environment(\.account, account)
                } label: {
                    Text(verbatim: displayUserID)
                        .lineLimit(1)
                }
            }
        }
        #if os(watchOS)
        .labelStyle(.titleOnly)
        #endif
    }

    var body: some View {
        if shouldBeHidden == false {
            Group {
                if let icon = icon {
                    Label {
                        userLabel
                    } icon: {
                        icon
                    }
                } else {
                    userLabel
                }
            }
            .accessibilityLabel(Text(verbatim: latestUserDetail?.name ?? displayUserID))
        }
    }

    private init(userID: String, searchQuery: String? = nil, icon: Icon?) {
        self.userID = userID
        self.searchQuery = searchQuery
        self.icon = icon

        self._latestUserDetails = FetchRequest(fetchRequest: {
            let fetchRequest = UserDetail.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "user.id == %@", userID)
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \UserDetail.user?.modificationDate, ascending: false),
                NSSortDescriptor(keyPath: \UserDetail.creationDate, ascending: false),
            ]
            fetchRequest.fetchLimit = 1
            fetchRequest.returnsObjectsAsFaults = false

            return fetchRequest
        }())
    }

    init(userID: String, searchQuery: String? = nil, @ViewBuilder icon: () -> Icon) {
        self.init(userID: userID, searchQuery: searchQuery, icon: icon())
    }

    init(userID: String, searchQuery: String? = nil) where Icon == EmptyView {
        self.init(userID: userID, searchQuery: searchQuery, icon: nil)
    }
}

struct UserRow_Previews: PreviewProvider {
    static var previews: some View {
        UserRow(userID: "123456789")
    }
}
