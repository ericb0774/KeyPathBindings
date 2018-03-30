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

public enum KeyPathBindingError: Error, CustomStringConvertible {
    case incompatibleTypes(sourceType: Any.Type, destinationType: Any.Type)

    public var description: String {
        switch self {
        case .incompatibleTypes(let sourceType, let destinationType):
            return "Cannot bind source keyPath type \(sourceType) with destination keyPath type \(destinationType) without a custom map function."
        }
    }
}

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

    public typealias KeyPathBindingMapper = (_ source: FromType, _ sourceValue: FromValueType, _ destination: ToType) -> ToValueType
    private var mapper: KeyPathBindingMapper!

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

            if sourceKeyPathType != destinationKeyPathType {
                throw KeyPathBindingError.incompatibleTypes(sourceType: sourceKeyPathType, destinationType: destinationKeyPathType)
            }
        }

        self.dispatchQueue = dispatchQueue

        self.notificationCenter = notificationCenter

        // Default mapper simply returns the source value.
        // This cast is safe because of the above prechecks to ensure the
        // types are compatible unless a custom mapper is supplied.
        self.mapper = mapper ?? { (_, sourceValue, _) in return sourceValue as! ToValueType }

        self.observer = notificationCenter.addObserver(forObject: source, keyPath: sourceKeyPath) { [weak self] (_) in
            self?.sourceValueChanged()
        }

        // Send initial value.
        sourceValueChanged()
    }

    deinit {
        if let observer = observer {
            notificationCenter.removeObserver(observer)
        }
    }

    private func sourceValueChanged() {
        guard
            let source = source,
            var destination = destination,
            let sourceKeyPath = sourceKeyPath as? KeyPath<FromType, FromValueType>,
            let destinationKeyPath = destinationKeyPath as? WritableKeyPath<ToType, ToValueType>
        else {
            return
        }

        let value = source[keyPath: sourceKeyPath]

        func assign(value: FromValueType) {
            let mappedValue = mapper(source, value, destination)
            destination[keyPath: destinationKeyPath] = mappedValue
        }

        if let dispatchQueue = dispatchQueue {
            dispatchQueue.sync {
                assign(value: value)
            }
        }
        else {
            if DispatchQueue.isMain {
                assign(value: value)
            }
            else {
                DispatchQueue.main.sync {
                    assign(value: value)
                }
            }
        }
    }
}
