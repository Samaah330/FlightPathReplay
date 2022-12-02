//
//  UIViewSuperView.swift
//  FlightPath
//
//  Created by kimstudent2 on 11/3/22.
//

import Foundation
import UIKit

extension UIView {

    // Traverses a UIView's superviews until a superview of the specified type is found
    func firstSuperViewOfType<T: UIView>(_ type: T.Type) -> T? {
        var view = self
        
        print("SUPERVIEW: ", view.superview)
        while let superview = view.superview {
            if let viewOfType = superview as? T {
                return viewOfType
            } else {
                view = superview
            }
        }
        return nil
    }

}
