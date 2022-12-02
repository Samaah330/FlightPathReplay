//
//  KeyboardDismissButton.swift
//  FlightPath
//
//  Created by kimstudent2 on 11/3/22.
//

import Foundation
import UIKit

extension UITextView {

    // Adds a UIToolbar with a dismiss button as UITextView's inputAccesssoryView (which appears on top of the keyboard)
    func addDismissButton() {
        let dismissToolbar = UIToolbar(frame: CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 44)))
                
        let dismissButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))
        dismissToolbar.items = [dismissButton]
        inputAccessoryView = dismissToolbar
    }

    @objc
    func dismissKeyboard() {
        endEditing(true)
    }

}
