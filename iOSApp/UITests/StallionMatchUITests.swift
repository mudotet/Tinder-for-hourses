import XCTest

@MainActor
final class StallionMatchUITests: XCTestCase {
    func testSignUpCreateHorseSwipeAndMatchFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-mock"]
        app.launch()

        // 1. Sign Up
        let displayNameField = app.textFields["displayNameField"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 5))
        displayNameField.tap()
        displayNameField.typeText("Clara Vance")

        let emailField = app.textFields["emailField"]
        emailField.tap()
        emailField.typeText("clara@stallionmatch.com")

        let passwordField = app.secureTextFields["passwordField"]
        passwordField.tap()
        passwordField.typeText("Password123!")

        let submitAuthButton = app.buttons["submitAuthButton"]
        XCTAssertTrue(submitAuthButton.isEnabled)
        submitAuthButton.tap()

        // 2. Create First Horse Profile
        let createHorseButton = app.buttons["createFirstHorseButton"]
        XCTAssertTrue(createHorseButton.waitForExistence(timeout: 5))
        createHorseButton.tap()

        let horseNameField = app.textFields["horseNameField"]
        XCTAssertTrue(horseNameField.waitForExistence(timeout: 5))
        horseNameField.tap()
        horseNameField.typeText("Apollo")

        let horseBioField = app.textViews["horseBioField"].exists
            ? app.textViews["horseBioField"]
            : app.textFields["horseBioField"]
        horseBioField.tap()
        horseBioField.typeText("Gentle Hanoverian stallion looking for trail buddies and dressage partners.")

        let saveButton = app.buttons["saveHorseProfileButton"]
        saveButton.tap()

        // 3. Swipe Right (Like) on Discover & Verify "It's a Match!" Overlay
        let likeButton = app.buttons["likeHorseButton"]
        XCTAssertTrue(likeButton.waitForExistence(timeout: 5))
        likeButton.tap()

        let matchTitle = app.staticTexts["itsAMatchTitle"]
        XCTAssertTrue(matchTitle.waitForExistence(timeout: 5))
    }
}
