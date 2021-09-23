//
//  SettingsMainView.swift
//  SettingsMainView
//
//  Created by Jaehong Kang on 2021/08/16.
//

import SwiftUI
import CoreData
import TweetNestKit

enum SettingsNavigationItem: Hashable {
    case general
    case accounts
}

struct SettingsMainView: View {
    #if os(macOS)
    @State var selectedNavigationItem: SettingsNavigationItem = .general
    #else
    @State var selectedNavigationItem: SettingsNavigationItem?
    #endif

    #if os(macOS)
    var body: some View {
        TabView(selection: $selectedNavigationItem) {
            SettingsGeneralView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsNavigationItem.general)

            SettingsAccountsView()
                .tabItem {
                    Label("Accounts", systemImage: "person.2")
                }
                .tag(SettingsNavigationItem.accounts)
        }
        .frame(minWidth: 600, minHeight: 300)
    }
    #else
    var body: some View {
        Form {
            Section {
                NavigationLink(
                    tag: SettingsNavigationItem.general,
                    selection: $selectedNavigationItem
                ) {
                    SettingsGeneralView()
                } label: {
                    Label("General", systemImage: "gearshape")
                }

                NavigationLink(
                    tag: SettingsNavigationItem.accounts,
                    selection: $selectedNavigationItem
                ) {
                    SettingsAccountsView()
                } label: {
                    Label("Accounts", systemImage: "person.2")
                }
            }

            Section {
                let marketingVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                let buildVersionString = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap({String("(\($0))")})
                let versionString = [marketingVersionString, buildVersionString].compactMap({$0}).joined(separator: " ")

                TweetNestStack {
                    Text("App Version")
                    #if !os(watchOS)
                    Spacer()
                    #endif
                    Text(versionString)
                    .foregroundColor(.secondary)
                }
                #if !os(watchOS)
                .contextMenu {
                    Button(
                        action: {
                            #if canImport(AppKit)
                            NSPasteboard.general.setString(versionString, forType: .string)
                            #elseif canImport(UIKit)
                            UIPasteboard.general.string = versionString
                            #endif
                        },
                        label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    )
                }
                #endif
            } header: {
                Text("About")
            }
        }
        .navigationTitle(Text("Settings"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    #endif
}

struct SettingsMainView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsMainView()
    }
}
