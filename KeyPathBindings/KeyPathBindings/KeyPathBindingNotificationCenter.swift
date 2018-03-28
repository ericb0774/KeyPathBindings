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

import Foundation

extension Notification.Name {
    static let keyPathValueChanged = Notification.Name("KeyPathBindingNotificationCenter.KeyPathValueChanged")
}

/// Describes a keyPath value change event.
public struct KeyPathValueChangeEvent {
    /// The object whose property value changed.
    let object: AnyObject
    /// The keyPath to the object's property.
    let keyPath: AnyKeyPath
}

private enum UserInfoKey: String {
    case keyPathValueChangeEvent
}

/// NotificationCenter upon which keyPath modification notifications are posted
/// and observed. This class cannot be instantiated. Instead, access it via
/// `NotificationCenter.keyPathBinding`.
final public class KeyPathBindingNotificationCenter: NotificationCenter {
    /// Prevent this class from being instantiated outside of this file.
    fileprivate override init() {
        super.init()
    }


    /// Adds an observer of keyPath changes for an object.
    /// The returned value must be disposed of using `removeObserver()` when no longer needed.
    ///
    /// - Parameters:
    ///   - object: The object to observe.
    ///   - keyPath: The keyPath to the object property to observe.
    ///   - handler: The handler for keyPath value changes.
    /// - Returns: An observer which must be disposed when no longer needed.
    public func addObserver(forObject object: AnyObject, keyPath: AnyKeyPath, handler: @escaping (_: KeyPathValueChangeEvent) -> Void) -> Any {
        return addObserver(forObject:object, keyPaths:[keyPath], handler:handler)
    }

    /// Adds an observer of multiple keyPath changes for an object.
    /// The returned value must be disposed of using `removeObserver()` when no longer needed.
    ///
    /// - Parameters:
    ///   - object: The object to observe.
    ///   - keyPaths: The keyPaths to the object properties to observe.
    ///   - handler: The handler for keyPath value changes.
    /// - Returns: An observer which must be disposed when no longer needed.
    public func addObserver(forObject object: AnyObject, keyPaths: Set<AnyKeyPath>, handler: @escaping (_: KeyPathValueChangeEvent) -> Void) -> Any {
        return super.addObserver(forName: .keyPathValueChanged, object: object, queue: nil) { notification in
            guard
                let userInfo = notification.userInfo,
                let changeEvent = userInfo[UserInfoKey.keyPathValueChangeEvent] as? KeyPathValueChangeEvent,
                keyPaths.contains(changeEvent.keyPath)
            else {
                return
            }

            handler(changeEvent)
        }
    }

    /// Sends a notification of a keyPath value change for an object.
    ///
    /// - Parameters:
    ///   - object: The object.
    ///   - keyPath: The object property's keyPath.
    public func notify(object: AnyObject, keyPathValueChanged keyPath: AnyKeyPath) {
        let changeEvent = KeyPathValueChangeEvent(object: object, keyPath: keyPath)
        super.post(name: .keyPathValueChanged, object: object, userInfo: [UserInfoKey.keyPathValueChangeEvent: changeEvent])
    }
}

// MARK: - NotificationCenter extension providing `keyPathBinding`

public extension NotificationCenter {

    /// The notification center to use to observe and notify about keyPath value changes.
    public static var keyPathBinding: KeyPathBindingNotificationCenter = {
        return KeyPathBindingNotificationCenter()
    }()
}
