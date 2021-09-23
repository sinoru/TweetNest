//
//  MainView.swift
//  TweetNest
//
//  Created by Jaehong Kang on 2021/02/24.
//

import SwiftUI
import TweetNestKit
import UnifiedLogging
import UserNotifications

#if canImport(CoreSpotlight)
import CoreSpotlight
#endif

struct MainView: View {
    @EnvironmentObject private var appDelegate: TweetNestAppDelegate

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.session) private var session: Session

    @State private var isPersistentContainerLoaded: Bool = false

    @State var error: TweetNestError?
    @State var showErrorAlert: Bool = false

    @State var user: User?

    var body: some View {
        AppSidebarNavigation(isPersistentContainerLoaded: $isPersistentContainerLoaded)
            .alert(isPresented: $showErrorAlert, error: error)
            .sheet(item: $user) { user in
                NavigationView {
                    Group {
                        if let userID = user.id {
                            UserView(userID: userID)
                        }
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .cancellationAction) {
                            Button("Cancel", role: .cancel) {
                                self.user = nil
                            }
                        }
                    }
                }
            }
            .task {
                do {
                    try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                } catch {
                    Logger().error("Error occurred: \(error as NSError, privacy: .public)")
                    self.error = TweetNestError(error)
                    self.showErrorAlert = true
                }
            }
            .onReceive(appDelegate.$sessionPersistentContainerStoresLoadingResult) { result in
                guard let result = result else {
                    isPersistentContainerLoaded = false
                    return
                }

                do {
                    try result.get()

                    isPersistentContainerLoaded = true
                } catch {
                    self.error = TweetNestError(error)
                    showErrorAlert = true
                }
            }
            #if canImport(CoreSpotlight)
            .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightUserActivity(_:))
            #endif
    }

    #if canImport(CoreSpotlight)
    func handleSpotlightUserActivity(_ userActivity: NSUserActivity) {
        guard
            let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            let uri = URL(string: identifier),
            let objectID = viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri),
            let user = viewContext.object(with: objectID) as? User
        else {
            return
        }

        self.user = user
    }
    #endif
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView().environment(\.managedObjectContext, Session.preview.persistentContainer.viewContext)
    }
}
#endif
