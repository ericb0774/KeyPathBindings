//
// Copyright (c) 2018 DuneParkSoftware, LLC
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import XCTest
@testable import KeyPathBindings

final class KeyPathBindingNotificationCenterTests: XCTestCase {

    var sut: KeyPathBindingNotificationCenter!

    override func setUp() {
        super.setUp()

        sut = NotificationCenter.keyPathBinding
    }

    override func tearDown() {
        sut = nil

        super.tearDown()
    }

    func test_IsNotEqualToDefaultNotificationCenter() {
        XCTAssertNotEqual(sut, NotificationCenter.default, "KeyPathBindingNotificationCenter should not be the same as the default notification center.")
    }

    func test_IsSingleton() {
        let other = NotificationCenter.keyPathBinding
        XCTAssertTrue(sut === other, "KeyPathBindingNotificationCenter should be a singleton.")
    }

    func test_ShouldSendNotificationsOfKeyPathChangesForAnObject() {
        let object = TestObject()
        var notificationCount = 0

        let observer = sut.addObserver(forObject: object, keyPath: \TestObject.intValue1) { (change) in
            XCTAssertTrue(change.object === object)
            XCTAssertTrue(change.keyPath == \TestObject.intValue1, "Received unexpected notification of keyPath change")

            notificationCount += 1
        }

        // This change should trigger a notification.
        object.intValue1 += 1
        // This change should trigger a notification which we don't receive.
        object.intValue2 += 1

        XCTAssertEqual(notificationCount, 1)
        sut.removeObserver(observer)
    }

    func test_ShouldSendNotificationsOfMultipleKeyPathChangesForAnObject() {
        let object = TestObject()
        var notificationCount = 0

        let observer = sut.addObserver(forObject: object, keyPaths: [\TestObject.intValue1, \TestObject.intValue2]) { (change) in
            XCTAssertTrue(change.object === object)
            XCTAssertTrue((change.keyPath == \TestObject.intValue1) || (change.keyPath == \TestObject.intValue2), "Received unexpected notification of keyPath change")

            notificationCount += 1
        }

        // These changes should each trigger a notification.
        object.intValue1 += 1
        object.intValue2 += 1

        XCTAssertEqual(notificationCount, 2)
        sut.removeObserver(observer)
    }

    func test_ShouldNotSendNotificationsOfChangesFromOtherObjects() {
        let object1 = TestObject()
        let object2 = TestObject()

        let observer = sut.addObserver(forObject: object1, keyPath: \TestObject.intValue1) { (change) in
            XCTFail("This notification should not have been received.")
        }

        object2.intValue1 += 1
        sut.removeObserver(observer)
    }
}
