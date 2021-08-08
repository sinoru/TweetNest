//
//  AccountsEditorView.swift
//  AccountsEditorView
//
//  Created by Jaehong Kang on 2021/08/04.
//

import SwiftUI
import TweetNestKit

struct AccountsEditorView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            SortDescriptor.init(\.sortOrder, order: .forward),
            SortDescriptor.init(\.creationDate, order: .reverse),
        ],
        animation: .default)
    private var accounts: FetchedResults<Account>

    var body: some View {
        List {
            ForEach(accounts) { account in
                let username = account.user?.sortedUserDatas?.last?.username
                Label(Text(verbatim: username.flatMap({"@\($0)"}) ?? "#\(account.id.formatted())")) {
                    ProfileImage(userData: account.user?.sortedUserDatas?.last)
                        .frame(width: 24, height: 24)
                }
                .accessibilityLabel(Text(verbatim: username.flatMap({"@\($0)"}) ?? "#\(account.id.formatted())"))
            }
            .onDelete(perform: deleteAccounts)
            .onMove(perform: moveAccounts)
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .navigationTitle(Text("Accounts"))
    }

    private func deleteAccounts(offsets: IndexSet) {
        withAnimation {
            offsets.map { accounts[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func moveAccounts(fromOffsets source: IndexSet, toOffset destination: Int) {
        withAnimation {
            var accounts = Array(accounts)
            accounts.move(fromOffsets: source, toOffset: destination)
            accounts.enumerated().forEach {
                $0.element.sortOrder = Int16($0.offset)
            }

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AccountsEditorView_Previews: PreviewProvider {
    static var previews: some View {
        AccountsEditorView()
    }
}
