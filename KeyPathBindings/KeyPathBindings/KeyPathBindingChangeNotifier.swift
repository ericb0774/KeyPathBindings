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

/// Describes an object that sends notifications about value changes via
/// keyPath.
public protocol KeyPathBindingChangeNotifier {

    /// Sends a notification about a value change by keyPath.
    ///
    /// - Parameter keyPathValueChanged: The keyPath.
    func notify(keyPathValueChanged: AnyKeyPath)

    /// Sends a notification about a value change by keyPath.
    ///
    /// - Parameter keyPathValueChanged: The keyPath.
    func notify<FromType, ValueType>(keyPathValueChanged: WritableKeyPath<FromType, ValueType>)

    /// Sends a notification about a value change by keyPath on a given object.
    ///
    /// - Parameters:
    ///   - object: The object whose value changed.
    ///   - keyPathValueChanged: The keyPath.
    func notify(object: AnyObject, keyPathValueChanged: AnyKeyPath)

    /// Sends a notification about a value change by keyPath on a given object.
    ///
    /// - Parameters:
    ///   - object: The object whose value changed.
    ///   - keyPathValueChanged: The keyPath.
    func notify<FromType, ValueType>(object: AnyObject, keyPathValueChanged: WritableKeyPath<FromType, ValueType>)
}

public extension KeyPathBindingChangeNotifier where Self: AnyObject {
    public func notify(keyPathValueChanged keyPath: AnyKeyPath) {
        notify(object: self, keyPathValueChanged: keyPath)
    }

    public func notify<FromType, ValueType>(keyPathValueChanged keyPath: WritableKeyPath<FromType, ValueType>) {
        notify(object: self, keyPathValueChanged: keyPath)
    }

    public func notify(object: AnyObject, keyPathValueChanged keyPath: AnyKeyPath) {
        NotificationCenter.keyPathBinding.notify(object: object, keyPathValueChanged: keyPath)
    }

    public func notify<FromType, ValueType>(object: AnyObject, keyPathValueChanged keyPath: WritableKeyPath<FromType, ValueType>) {
        NotificationCenter.keyPathBinding.notify(object: object, keyPathValueChanged: keyPath)
    }
}
