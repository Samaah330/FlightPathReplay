//
//  ScreenSpaceComponent.swift
//  FlightPath
//
//  Created by kimstudent2 on 11/3/22.
//

import Foundation
import RealityKit
import UIKit

import RealityKit
import UIKit

/// - Tag: HasScreenSpaceView
protocol HasScreenSpaceView: Entity {
    var screenSpaceComponent: ScreenSpaceComponent { get set }
}


struct ScreenSpaceComponent: Component {
    var view: NoteView?
    
    // Indicates whether the note is being dragged with pan touch input.
    var isDragging = false
    
    // Indicates whether the note is currently being edited.
    var isEditing = false
    
    // Indicates whether the note should animate to a new position (as opposed to moving instantaneously to a new position).
    var shouldAnimate = false
    
    //Contains a screen space projection
    var projection: Projection?
}

struct Projection {
    
    let projectedPoint: CGPoint
    let isVisible: Bool
    
}

extension HasScreenSpaceView {
    
    var view: NoteView? {
        get { screenSpaceComponent.view }
        set { screenSpaceComponent.view = newValue }
    }
    
    var isDragging: Bool {
        get { screenSpaceComponent.isDragging }
        set { screenSpaceComponent.isDragging = newValue }
    }
    
    var isEditing: Bool {
        get { screenSpaceComponent.isEditing }
        set { screenSpaceComponent.isEditing = newValue }
    }
    
    var shouldAnimate: Bool {
        get { screenSpaceComponent.shouldAnimate }
        set { screenSpaceComponent.shouldAnimate = newValue }
    }
    
    var projection: Projection? {
        get { screenSpaceComponent.projection }
        set { screenSpaceComponent.projection = newValue }
    }
    
    // Returns the center point of the enity's screen space view
    func getCenterPoint(_ point: CGPoint) -> CGPoint {
        guard let view = view else {
            fatalError("Called getCenterPoint(_point:) on a screen space component with no view.")
        }
        let xCoord = CGFloat(point.x) - (view.frame.width) / 2
        let yCoord = CGFloat(point.y) - (view.frame.height) / 2
        return CGPoint(x: xCoord, y: yCoord)
    }
    
    // Centers the entity's screen space view on the specified screen location.
    func setPositionCenter(_ position: CGPoint) {
        let centerPoint = getCenterPoint(position)
        guard let view = view else {
            fatalError("Called centerOnHitLocation(_hitLocation:) on a screen space component with no view.")
        }
        view.frame.origin = CGPoint(x: centerPoint.x, y: centerPoint.y)
        
        // Updating the lastFrame of the NoteView
        view.lastFrame = view.frame
    }
    
    // Animates the entity's screen space view to the the specified screen location, and updates the shouldAnimate state of the entity.
    func animateTo(_ point: CGPoint) {

        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .linear) {
            self.setPositionCenter(point)
        }
        // ...

        animator.addCompletion {
            switch $0 {
            case .end:
                self.screenSpaceComponent.shouldAnimate = false
            default:
                self.screenSpaceComponent.shouldAnimate = true
            }
        }

        animator.startAnimation()
    }
    
    // Updates the screen space position of an entity's screen space view to the current projection.
    func updateScreenPosition() {
        guard let projection = projection else { return }
        let projectedPoint = projection.projectedPoint
        
        // Hides the note if it can not visible from the current point of view
        isEnabled = projection.isVisible
        view?.isHidden = !isEnabled

        if shouldAnimate {
            animateTo(projectedPoint)
        } else {
            setPositionCenter(projectedPoint)
        }
    }
}
