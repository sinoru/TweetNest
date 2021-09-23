//
//  TweetNestScreenTests.swift
//  TweetNest
//
//  Created by Jaehong Kang on 2021/09/16.
//

import XCTest

class TweetNestScreenTests: XCTestCase {
    static let dispalyUserName = "@TweetNest_App"

    let app = XCUIApplication()

    private var systemAlertsUIInterruptionMonitorToken: NSObjectProtocol?

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false

        app.launchArguments = ["-com.tweetnest.TweetNest.Preview"]

        self.systemAlertsUIInterruptionMonitorToken = addUIInterruptionMonitor(withDescription: "System Alerts") { (alert) -> Bool in
            let allowButton = alert.buttons["Allow"]

            if allowButton.exists {
                allowButton.tap()
                return true
            }

            return false
        }

        app.launch()

        if app.navigationBars.buttons["BackButton"].exists {
            app.navigationBars.buttons["BackButton"].tap()
        }
    }

    override func tearDownWithError() throws {
        app.terminate()

        if let systemAlertsUIInterruptionMonitorToken = self.systemAlertsUIInterruptionMonitorToken {
            removeUIInterruptionMonitor(systemAlertsUIInterruptionMonitorToken)
        }
    }

    func testLaunch() throws {
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        XCTAssertTrue(app.staticTexts[Self.dispalyUserName].waitForExistence(timeout: 5))

        wait(for: [
            expectation(for: .init(format: "exists == 0"), evaluatedWith: app.scrollBars.element, handler: nil)
        ], timeout: 5.0)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAccount() throws {
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        app.buttons["\(Self.dispalyUserName)'s Account"].tap()

        XCTAssertTrue(app.navigationBars[Self.dispalyUserName].staticTexts[Self.dispalyUserName].waitForExistence(timeout: 5))

        wait(for: [
            expectation(for: .init(format: "exists == 0"), evaluatedWith: app.scrollBars.element, handler: nil)
        ], timeout: 5.0)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Account Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFollowingsHistory() throws {
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        app.buttons["\(Self.dispalyUserName)'s Followings History"].tap()

        XCTAssertTrue(app.staticTexts["@Apple"].waitForExistence(timeout: 5))

        wait(for: [
            expectation(for: .init(format: "exists == 0"), evaluatedWith: app.scrollBars.element, handler: nil)
        ], timeout: 5.0)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Followings History Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    #if !os(watchOS)
    func testBatchDeleteTweetsForm() throws {
        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        app.buttons["\(Self.dispalyUserName)'s Account"].tap()

        XCTAssertTrue(app.navigationBars[Self.dispalyUserName].staticTexts[Self.dispalyUserName].waitForExistence(timeout: 5))

        if app.buttons["Delete"].exists {
            app.buttons["Delete"].tap()
            app.buttons["Delete Recent Tweets"].tap()
        } else if app.navigationBars[Self.dispalyUserName].buttons["More"].exists {
            app.navigationBars[Self.dispalyUserName].buttons["More"].tap()
            app.collectionViews.buttons.element(boundBy: 3).tap() // app.collectionViews/*@START_MENU_TOKEN@*/.buttons["Delete"]/*[[".cells.buttons[\"Delete\"]",".buttons[\"Delete\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
            app.buttons["Delete Recent Tweets"].tap()
        } else {
            #if os(watchOS)
            scrollDown()
            #endif

            app.buttons["Delete Recent Tweets"].tap()
        }

        XCTAssertTrue(app.switches.firstMatch.waitForExistence(timeout: 5))

        wait(for: [
            expectation(for: .init(format: "exists == 0"), evaluatedWith: app.scrollBars.element, handler: nil)
        ], timeout: 5.0)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Batch Delete Tweets Form Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollDown() {
        let relativeTouchPoint = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0))
        let relativeOffset = app.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: -1.0))
        relativeTouchPoint.press(forDuration: 0, thenDragTo: relativeOffset)
    }
    #endif
}
