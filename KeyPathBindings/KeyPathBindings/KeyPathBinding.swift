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

infix operator ||>

/// Creates a keyPath binding between properties of the same type between two
/// objects. The binding is always executed on the `main` dispatch queue.
///
/// - Parameters:
///   - from: The binding source object and keyPath (tuple)
///   - to: The binding destination object and keyPath (tuple)
/// - Returns: The `KeyPathBinding` instance
/// - Throws: `KeyPathBindingError` if the binding cannot be established.
public func ||> <FromType, FromValueType, ToType, ToValueType>(from: (FromType, KeyPath<FromType, FromValueType>),
                                                               to: (ToType, WritableKeyPath<ToType, ToValueType>)) throws -> KeyPathBinding<FromType, FromValueType, ToType, ToValueType> {
    return try KeyPathBinding(from: from.0, keyPath: from.1,
                              to: to.0, keyPath: to.1, dispatchQueue: .main)
}

/// Creates a keyPath binding between properties of different types between two
/// objects. The binding is always executed on the `main` dispatch queue.
///
/// - Parameters:
///   - from: The binding source object and keyPath (tuple)
///   - to: The bindng destination object, keyPath, and map closure (tuple)
/// - Returns: The `KeyPathBinding` instance
/// - Throws: `KeyPathBindingError` if the binding cannot be established.
public func ||> <FromType, FromValueType, ToType, ToValueType>(from: (FromType, KeyPath<FromType, FromValueType>),
                                                               to: (ToType, WritableKeyPath<ToType, ToValueType>, (_ source: FromType, _ destination: ToType, _ oldValue: FromValueType?, _ newValue: FromValueType) -> ToValueType)) throws -> KeyPathBinding<FromType, FromValueType, ToType, ToValueType> {
    return try KeyPathBinding(from: from.0, keyPath: from.1,
                              to: to.0, keyPath: to.1, dispatchQueue: .main, map: to.2)
}

/// Errors that can occur while creating a `KeyPathBinding`
///
/// - incompatibleTypes: Attempted to create a binding between properties of different types without a map closure.
public enum KeyPathBindingError: Error, CustomStringConvertible {
    /// Attempted to create a binding between properties of different types
    /// without a map closure.
    case incompatibleTypes(sourceType: Any.Type, destinationType: Any.Type)

    /// Attempted to create a binding to the same property on a single object.
    case sameObjectAndProperty

    public var description: String {
        switch self {
        case .incompatibleTypes(let sourceType, let destinationType):
            return "Cannot bind source keyPath type \(sourceType) with destination keyPath type \(destinationType) without a custom map function."

        case .sameObjectAndProperty:
            return "Cannot bind an object's property to itself."
        }
    }
}

/// Creates a keyPath binding from a source object's property to a destination
/// object's property.
public class KeyPathBinding<FromType, FromValueType, ToType, ToValueType> where FromType: AnyObject, ToType: AnyObject {

    // Ensure references to source and destination are weak.
    private weak var source: FromType?
    private weak var destination: ToType?

    // Type-erased keypaths.
    private let sourceKeyPath: AnyKeyPath
    private let destinationKeyPath: AnyKeyPath

    private let notificationCenter: KeyPathBindingNotificationCenter
    // Allow module-level access for testing.
    internal var observer: Any?

    private let dispatchQueue: DispatchQueue?

    /// Describes a closure which maps a source property type to the expected
    /// destination property type, allowing bindings between properties of
    /// different types.
    public typealias KeyPathBindingMapper = (_ source: FromType, _ destination: ToType, _ oldValue: FromValueType?, _ newValue: FromValueType) -> ToValueType
    private var mapper: KeyPathBindingMapper!

    /// Creates a keyPath binding object, causing changes in the source object's
    /// property to be assigned to the destination object's property over the
    /// lifetime of both objects.
    ///
    /// - Parameters:
    ///   - source: The source object.
    ///   - sourceKeyPath: The keyPath to the source object's property.
    ///   - destination: The destination object.
    ///   - destinationKeyPath: The keyPath to the destination object's property.
    ///   - notificationCenter: The `NotificationCenter` to use. Defaults to `NotificationCenter.keyPathBinding`.
    ///   - dispatchQueue: The `DispatchQueue` to use when assigning the destination property. Defaults to `nil`.
    ///   - mapper: The map closure to use if the bound properties are of different types.
    /// - Throws: `KeyPathBindingError` if the binding cannot be established.
    public init(from source: FromType, keyPath sourceKeyPath: KeyPath<FromType, FromValueType>,
                to destination: ToType, keyPath destinationKeyPath: WritableKeyPath<ToType, ToValueType>,
                notificationCenter: KeyPathBindingNotificationCenter = NotificationCenter.keyPathBinding,
                dispatchQueue: DispatchQueue? = nil,
                map mapper: KeyPathBindingMapper? = nil) throws {

        self.source = source
        self.destination = destination

        self.sourceKeyPath = sourceKeyPath
        self.destinationKeyPath = destinationKeyPath

        // Confirm source and destination types are compatible unless a custom
        // mapper is provided.
        if mapper == nil {
            let sourceKeyPathType = type(of: sourceKeyPath).valueType
            let destinationKeyPathType = type(of: destinationKeyPath).valueType

            if (sourceKeyPathType != destinationKeyPathType) && (Optional<FromValueType>.self != destinationKeyPathType) {
                throw KeyPathBindingError.incompatibleTypes(sourceType: sourceKeyPathType, destinationType: destinationKeyPathType)
            }
            else {
                if source === destination {
                    throw KeyPathBindingError.sameObjectAndProperty
                }
            }
        }

        self.dispatchQueue = dispatchQueue

        self.notificationCenter = notificationCenter

        // Default mapper simply returns the source value.
        // This cast is safe because of the above prechecks to ensure the
        // types are compatible unless a custom mapper is supplied.
        self.mapper = mapper ?? { (_, _, _, newValue) in return newValue as! ToValueType }

        self.observer = notificationCenter.addObserver(forObject: source, keyPath: sourceKeyPath) { [weak self] event in
            self?.sourceValueChanged(event)
        }

        // Send initial value.
        sourceValueChanged()
    }

    deinit {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
    }

    private func sourceValueChanged(_ event: KeyPathValueChangeEvent? = nil) {
        guard
            let source = source,
            var destination = destination,
            let sourceKeyPath = sourceKeyPath as? KeyPath<FromType, FromValueType>,
            let destinationKeyPath = destinationKeyPath as? WritableKeyPath<ToType, ToValueType>
        else {
            return
        }

        var oldValue: Any? = nil
        if let event = event {
            oldValue = event.oldValue
        }

        let value = source[keyPath: sourceKeyPath]

        func assign(oldValue: Any? = nil, newValue: FromValueType) {
            let mappedValue = mapper(source, destination, oldValue as? FromValueType, value)
            destination[keyPath: destinationKeyPath] = mappedValue
        }

        if let dispatchQueue = dispatchQueue {
            if dispatchQueue == DispatchQueue.main {
                dispatchQueue.async { assign(oldValue: oldValue, newValue: value) }
            }
            else {
                dispatchQueue.sync { assign(oldValue: oldValue, newValue: value) }
            }
        }
        else {
            if DispatchQueue.isMain {
                assign(oldValue: oldValue, newValue: value)
            }
            else {
                DispatchQueue.main.sync { assign(oldValue: oldValue, newValue: value) }
            }
        }
    }
}
