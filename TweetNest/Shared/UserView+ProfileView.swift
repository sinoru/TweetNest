//
//  UserView+ProfileView.swift
//  TweetNest
//
//  Created by Jaehong Kang on 2021/09/23.
//

import SwiftUI
import TweetNestKit

extension UserView {
    struct ProfileView: View {
        @FetchRequest private var latestUserDetails: FetchedResults<UserDetail>

        private var latestUserDetail: UserDetail? {
            latestUserDetails.first
        }

        var body: some View {
            if let latestUserDetail = latestUserDetail {
                UserDetailProfileView(userDetail: latestUserDetail)
            }
        }

        init(user: User?) {
            self._latestUserDetails = FetchRequest(fetchRequest: {
                let fetchRequest = UserDetail.fetchRequest()
                if let user = user {
                    fetchRequest.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    fetchRequest.predicate = NSPredicate(value: false)
                }
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \UserDetail.creationDate, ascending: false),
                ]
                fetchRequest.fetchLimit = 1
                fetchRequest.returnsObjectsAsFaults = false

                return fetchRequest
            }())
        }
    }
}

struct UserView_ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserView.ProfileView(user: nil)
    }
}
