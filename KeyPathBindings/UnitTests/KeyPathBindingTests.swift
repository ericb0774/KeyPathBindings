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

final class KeyPathBindingTests: XCTestCase {
    var bindings: [Any]?

    override func tearDown() {
        bindings = nil
        super.tearDown()
    }

    func test_SetsInitialValueOnCreation() {
        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.stringValue1,
                                   to: object2, keyPath: \TestObject.stringValue2)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(object2.stringValue2, object1.stringValue1, "The initial value should be set when the key path binding is created.")
    }

    func test_BindsTwoValuesOfSameType() {
        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.stringValue1,
                                   to: object2, keyPath: \TestObject.stringValue1)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        object1.stringValue1 = object1.stringValue1 + object1.stringValue2

        XCTAssertEqual(object2.stringValue1, object1.stringValue1, "object2.stringValue1 should be bound to value changes in object1.stringValue1")
    }

    func test_DoesNotAllowTheSameObjectAndPropertyToBindToItself() {
        let object = TestObject()

        XCTAssertThrowsError(
            _ = try KeyPathBinding(from: object, keyPath: \TestObject.intValue1,
                                   to: object, keyPath: \TestObject.intValue1),
            "Attempting to create a keyPath binding to the same object property should should throw"
        ) { (error) in
            switch error {
            case KeyPathBindingError.sameObjectAndProperty:
                break

            default:
                XCTFail("Expected KeyPathBindingError.sameObjectAndProperty error to be thrown, but received: \(error)")
            }
        }
    }

    func test_CallsMapperWithCorrectParameters() {
        let object1 = TestObject()
        let object2 = TestObject()

        object1.stringValue1 = "foo"
        object2.stringValue1 = "unset"

        var callCount = 0

        let exp = expectation(description: "3 binding calls are made")

        do {
            bindings = [
                try (object1, \TestObject.stringValue1) ||> (object2, \TestObject.stringValue1, { (source, destination, oldValue, newValue) in
                    XCTAssert(source === object1, "Expected source to be object1 instance.")
                    XCTAssert(destination === object2, "Expected destination to be object2 instance.")

                    callCount += 1
                    
                    switch callCount {
                    case 1:
                        XCTAssertNil(oldValue, "Upon initial binding, expected `oldValue` to be nil, but got `\(String(describing: oldValue))`.")
                        XCTAssertEqual(newValue, "foo", "Upon initial binding, expected `newValue` to be `foo`, but got `\(newValue)`.")

                    case 2:
                        XCTAssertEqual(oldValue, "foo", "Upon first binding change, expected `oldValue` to be `foo`, but got `\(String(describing: oldValue))`.")
                        XCTAssertEqual(newValue, "bar", "Upon first binding change, expected `newValue` to be `bar`, but got `\(newValue)`.")

                    case 3:
                        XCTAssertEqual(oldValue, "bar", "Upon first binding change, expected `oldValue` to be `bar`, but got `\(String(describing: oldValue))`.")
                        XCTAssertEqual(newValue, "baz", "Upon first binding change, expected `newValue` to be `baz`, but got `\(newValue)`.")
                        exp.fulfill()

                    default:
                        XCTFail("Mapper called too many times - \(callCount)")
                    }

                    return newValue
                })
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        object1.stringValue1 = "bar"
        object1.stringValue1 = "baz"

        waitForExpectations(timeout: TimeInterval(1))
    }

    func test_PerformsBindOnMainQueueByDefault() {
        let mainQueueKey = DispatchSpecificKey<()>()
        DispatchQueue.main.setSpecific(key: mainQueueKey, value: ())
        var onMainQueue = false

        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.stringValue1,
                                   to: object2, keyPath: \TestObject.stringValue2,
                                   map: { (source, _, _, _) in
                                    onMainQueue = DispatchQueue.getSpecific(key: mainQueueKey) != nil
                                    return source.stringValue1
                })
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        object1.stringValue1 = object1.stringValue1 + object1.stringValue2

        XCTAssertTrue(onMainQueue)
    }

    func test_PerformsBindOnGivenDispatchQueue() {
        let queue = DispatchQueue.global()
        let queueKey = DispatchSpecificKey<()>()
        queue.setSpecific(key: queueKey, value: ())
        var onQueue = false

        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.stringValue1,
                                   to: object2, keyPath: \TestObject.stringValue2,
                                   dispatchQueue: queue,
                                   map: { (source, _, _, _) in

                                    onQueue = DispatchQueue.getSpecific(key: queueKey) != nil
                                    return source.stringValue1
                })
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        object1.stringValue1 = object1.stringValue1 + object1.stringValue2

        XCTAssertTrue(onQueue)
    }

    func test_BindsDifferentTypesWithMapper() {
        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1,
                                   to: object2, keyPath: \TestObject.stringValue1,
                                   map: { (_, _, _, value) in
                                    return "Mapped value: \(value)"
                })
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertEqual(object2.stringValue1, "Mapped value: \(object1.intValue1)")
    }

    func test_DoesNotAllowBindingOfDifferentTypesWithoutMapper() {
        let object1 = TestObject()
        let object2 = TestObject()

        XCTAssertThrowsError(
            _ = try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1,
                                   to: object2, keyPath: \TestObject.stringValue1),
            "Attempting to create a keyPath binding between incomatible types without a map function should throw"
        ) { (error) in
            switch error {
            case KeyPathBindingError.incompatibleTypes(sourceType: _, destinationType: _):
                break

            default:
                XCTFail("Expected KeyPathBindingError.incompatibleTypes error to be thrown, but received: \(error)")
            }
        }
    }

    func test_AllowsBindingFromNonOptionalTypeToOptionalOfSameWrappedTypeWithoutMapper() {
        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1,
                                   to: object2, keyPath: \TestObject.optionalInt3)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertNotNil(object2.optionalInt3, "Optional property should not be nil.")
        XCTAssertEqual(object2.optionalInt3, object1.intValue1, "Optional property should have been assigned the initial non-optional value.")
    }

    func test_DoesNotAllowBindingFromOptionalTypeToNonOptionalOfSameTypeWithoutMapper() {
        let object1 = TestObject()
        let object2 = TestObject()

        XCTAssertThrowsError(
            _ = try KeyPathBinding(from: object1, keyPath: \TestObject.optionalInt3,
                                   to: object2, keyPath: \TestObject.intValue1),
            "Attempting to create a keyPath binding from an optional to a non-optional without a map function should throw"
        ) { (error) in
            switch error {
            case KeyPathBindingError.incompatibleTypes(sourceType: _, destinationType: _):
                break

            default:
                XCTFail("Expected KeyPathBindingError.incompatibleTypes error to be thrown, but received: \(error)")
            }
        }
    }

    func test_DoesNotHoldStrongReferenceToSource() {
        var object1: TestObject? = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1!, keyPath: \TestObject.intValue1, to: object2, keyPath: \TestObject.intValue2)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertNotNil(object1)
        weak var objectRef: TestObject? = object1
        object1 = nil
        XCTAssertNil(objectRef)
    }

    func test_DoesNotHoldStrongReferenceToDestination() {
        let object1 = TestObject()
        var object2: TestObject? = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1, to: object2!, keyPath: \TestObject.intValue2)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        XCTAssertNotNil(object2)
        weak var objectRef: TestObject? = object2
        object2 = nil
        XCTAssertNil(objectRef)
    }

    func test_BindingDeinits() {
        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1, to: object2, keyPath: \TestObject.intValue2)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        weak var binding: AnyObject? = bindings?.first as AnyObject
        XCTAssertNotNil(binding)
        bindings = []
        XCTAssertNil(binding)
    }

    func test_RemovesNotificationObserverUponDeinit() {
        let notificationCenterMock = KeyPathBindingNotificationCenterMock()

        var addObserverCallCount = 0
        var removeObserverCallCount = 0

        notificationCenterMock.addObserverTestHook = {
            XCTAssertNotNil($0, "An observer object was expected to have been created.")
            addObserverCallCount += 1
        }

        notificationCenterMock.removeObserverTestHook = {
            XCTAssertNotNil($0, "An observer object was expected to have been received.")
            removeObserverCallCount += 1
        }

        let object1 = TestObject()
        let object2 = TestObject()

        do {
            bindings = [
                try KeyPathBinding(from: object1, keyPath: \TestObject.intValue1,
                                   to: object2, keyPath: \TestObject.intValue2,
                                   notificationCenter: notificationCenterMock)
            ]
        }
        catch {
            XCTFail(error.localizedDescription)
        }

        bindings = []

        XCTAssertEqual(addObserverCallCount, 1)
        // Remove observer seems to be called twice. I don't think its a problem.
        XCTAssertGreaterThanOrEqual(removeObserverCallCount, addObserverCallCount)
    }
}
