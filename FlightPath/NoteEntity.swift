//
//  NoteEntity.swift
//  FlightPath
//
//  Created by kimstudent2 on 11/3/22.
//

import Foundation
import ARKit
import RealityKit

// class to anchor note in place in the real world
// An Entity which has an anchoring component and a screen space view component, where the screen space view is a NoteView.
class NoteEntity: Entity, HasAnchoring, HasScreenSpaceView {

    var screenSpaceComponent = ScreenSpaceComponent()
    
    // Initializes a new NoteEntity and assigns the specified transform.
    // Also automatically initializes an associated NoteView with the specified frame.
    init(frame: CGRect, worldTransform: simd_float4x4) {
        
        // worldTransform ->  ray cast result's world transform
        super.init()
        
        // Position the entity at the tap location by setting its transformation matrix to theWorldTransform
        self.transform.matrix = worldTransform
       
        screenSpaceComponent.view = NoteView(frame: frame, note: self)
    }
    
    required init() {
    }
    
}
