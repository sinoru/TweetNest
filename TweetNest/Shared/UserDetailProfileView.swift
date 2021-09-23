//
//  UserDetailProfileView.swift
//  UserDetailProfileView
//
//  Created by Jaehong Kang on 2021/08/03.
//

import SwiftUI
import TweetNestKit

struct UserDetailProfileView: View {
    @ObservedObject var userDetail: UserDetail

    @Environment(\.openURL) private var openURL

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var shouldCompactForHorizontal: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #elseif os(watchOS)
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    ProfileImage(profileImageURL: userDetail.profileImageURL)
                        #if !os(watchOS)
                        .frame(width: 48, height: 48)
                        #else
                        .frame(width: 36, height: 36)
                        #endif

                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: userDetail.name ?? userDetail.user?.id.flatMap({"#\($0)"}) ?? "")
                        if let username = userDetail.username {
                            Text(verbatim: "@\(username)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let userAttributedDescription = userDetail.userAttributedDescription.flatMap({AttributedString($0)}), userAttributedDescription.startIndex != userAttributedDescription.endIndex {
                    Text(userAttributedDescription)
                }
            }
            .padding([.top, .bottom], 8)

            if let location = userDetail.location {
                let locationQueryURL = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap({ URL(string: "http://maps.apple.com/?q=\($0)") })
                Label {
                    TweetNestStack {
                        Text("Location")
                            .layoutPriority(1)
                            .lineLimit(1)
                        #if !os(watchOS)
                        Spacer()
                        #endif
                        Group {
                            if let locationQueryURL = locationQueryURL {
                                Link(location, destination: locationQueryURL)
                            } else {
                                Text(location)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .lineLimit(1)
                        .allowsTightening(true)
                    }
                } icon: {
                    Image(systemName: "location")
                }
                .accessibilityElement()
                .accessibilityLabel(Text("Location"))
                .accessibilityValue(Text(location))
                .accessibilityAddTraits(locationQueryURL != nil ? .isButton : [])
            }

            if let url = userDetail.url {
                Label {
                    TweetNestStack {
                        Text("URL")
                            .layoutPriority(1)
                            .lineLimit(1)
                        #if !os(watchOS)
                        Spacer()
                        #endif
                        Link(url.absoluteString, destination: url)
                            .lineLimit(1)
                            .allowsTightening(true)
                    }
                } icon: {
                    Image(systemName: "safari")
                }
                .accessibilityElement()
                .accessibilityLabel(Text("URL"))
                .accessibilityValue(Text(url.absoluteString))
                .accessibilityAddTraits(.isButton)
            }

            if let userCreationDate = userDetail.userCreationDate {
                Label {
                    TweetNestStack {
                        Text("Joined")
                            .layoutPriority(1)
                            .lineLimit(1)
                        #if !os(watchOS)
                        Spacer()
                        #endif
                        Group {
                            if shouldCompactForHorizontal {
                                Text(userCreationDate.formatted(date: .numeric, time: .shortened))
                            } else {
                                Text(userCreationDate.formatted(date: .numeric, time: .standard))
                            }
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .allowsTightening(true)
                    }
                } icon: {
                    Image(systemName: "calendar")
                }
                .accessibilityElement()
                .accessibilityLabel(Text("Joined"))
                .accessibilityValue(Text(userCreationDate.formatted(date: .long, time: .standard)))
            }

            if userDetail.isProtected {
                Label("Protected", systemImage: "lock")
            }

            if userDetail.isVerified {
                Label("Verified", systemImage: "checkmark.seal")
            }
        }
    }
}

//#if DEBUG
//struct UserDetailProfileView_Previews: PreviewProvider {
//    static var previews: some View {
//        UserDetailProfileView(userDetail: nil)
//    }
//}
//#endif
