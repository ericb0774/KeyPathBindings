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

import KeyPathBindings
import UIKit

class ViewController: UIViewController, KeyPathBindingChangeNotifier {

    var bindings: [Any?] = []

    @IBOutlet private weak var uptimeLabel: UILabel!
    @IBOutlet private weak var slider: UISlider!
    @IBOutlet private weak var sliderValueLabel: UILabel!
    @IBOutlet private weak var deviceTypeLabel: UILabel!

    static var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        return dateFormatter
    }()

    static let startDate = Date()

    var observer: Any?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            do {
                bindings = [
                    try (appDelegate, \AppDelegate.uptime) ||> (uptimeLabel, \UILabel.text, { (_, date, _) in
                        let calendar = Calendar.autoupdatingCurrent
                        let seconds = Int(date.timeIntervalSince(ViewController.startDate))
                        var dateComponents = DateComponents(calendar: calendar)
                        dateComponents.second = seconds
                        if let time = calendar.date(from: dateComponents) {
                            return "Uptime: \(ViewController.dateFormatter.string(from: time))"
                        }
                        return "Uptime: unavailable"
                    }),

                    try (slider, \UISlider.value) ||> (sliderValueLabel, \UILabel.text, { (_, value, _) in
                        return "\(Int(value))"
                    }),

                    // Since UIDevice.localizedModel never changes, a simple assignment could be used here ;)
                    try (UIDevice.current, \UIDevice.localizedModel) ||> (deviceTypeLabel, \UILabel.text)
                ]
            }
            catch {
                print(error.localizedDescription)
            }

            observer = NotificationCenter.keyPathBinding.addObserver(forObject: appDelegate, keyPath: \AppDelegate.uptime) { [weak self] (changeEvent) in
                print(changeEvent)

                // Cancel the observer after the first receive.
                if let observer = self?.observer {
                    NotificationCenter.keyPathBinding.removeObserver(observer)
                }
            }
        }
    }

    @IBAction private func sliderValueChanged(_ sender: UISlider?) {
        notify(object: self.slider, keyPathValueChanged: \UISlider.value)
    }

    deinit {
        if let observer = observer {
            NotificationCenter.keyPathBinding.removeObserver(observer)
        }
    }
}
