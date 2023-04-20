//
//  ViewController.swift
//  FlightPath
//
//  Created by Jaewook Lee on 9/30/22.
//

import UIKit
import RealityKit
import ARKit
import Combine
import Darwin


class ViewController: UIViewController , ARSessionDelegate, UITextViewDelegate, ARCoachingOverlayViewDelegate {
    
    @IBOutlet var arView: ARView!
    
    var counter = 0
    
    var touchLocation: CGPoint!

    var hummingBird: HummingBird._HummingBird!
    var captureSphere: CaptureSphere._CaptureSphere!
    
    var prevYaw = Float(0.1)
    var prevPitch = Float(0.1)

    // maximum distance between the sphere and the hummingbird
    var maxDistance : Float = 0.0 // 2.14949
    var threshold = 2.14949
    
    var countDots = 0


   // var device: Device._Device!
    
//    if let boxScene = try? Device.loadBox() {
//        let Device = boxScene.Device
//        // Do something with box.
//    }
    
    var blueSphere = false
    var light1 = false
    var light2 = false
    var light3 = false
    var light4 = false
    var light5 = false
    var light6 = false
    var light7 = false
    
    var light1Blue = CGColor(red: 0.639215, green: 0.788235, blue: 0.968627, alpha: 0.9)
    var light2Blue = CGColor(red: 0.517647, green: 0.7254902, blue: 0.98039, alpha: 0.9)
    var light3Blue = CGColor(red: 0.4, green: 0.6627, blue: 0.98039215, alpha: 0.9)
    var light4Blue = CGColor(red: 0.2823529, green: 0.596078, blue: 0.98039, alpha: 0.9)
    var light5Blue = CGColor(red: 0.1647, green: 0.5333, blue: 0.98039215, alpha: 0.9)
    var light6Blue = CGColor(red: 0.05, green: 0.4745, blue: 0.98039, alpha: 0.9)
    var light7Blue = CGColor(red: 0.0196, green: 0.439, blue: 0.9490, alpha: 0.9)

    
    
//    if let Dots = try? Dots.loadBox() {
//        let box = Dots.Dots
//        // Do something with box.
//    }
    
    var jsonData: GameData!
    
    @IBOutlet var arSCNView : ARSCNView!
    var trashZone: GradientView!
    var shadeView: UIView!
      
    var Notes = [NoteEntity]()
    weak var selectedView: NoteView?
    var lastKeyboardHeight: Double?
    var subscription: Cancellable!
      
    struct GameData: Decodable {
        let camPos: [[String: Float]]
        let spherePos: [[String: Float]]
        let runOrder: [Int]
        let age: String
        let leftEyePos: [[String: Float]]
        let lookAtPoint: [[String: Float]]
        let deviceAcceleration: [[String: Float]]
        let hummingbirdMovementType: [String]
        let hummingbirdPos: [[String: Float]]
        let centerFacePos: [[String: Float]]
        let userName: String
        let rightEyePos: [[String: Float]]
        let userSphereFocus: [Bool]
        let deviceRotation: [[String: Float]]
        let block: Int
        let dateTime: String
        let gender: String
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // updates scene every frame interval
        subscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [unowned self] in
            self.updateScene(on: $0)
        }

        // Load the "Box" scene from the "Experience" Reality File
        hummingBird = try! HummingBird.load_HummingBird()
        captureSphere = try! CaptureSphere.load_CaptureSphere()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(hummingBird!)
        arView.scene.anchors.append(captureSphere!)
        
        // In the beginning, make sure you cannot see trailing dots behind capture sphere
        countDots = 0
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot1!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot2!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot3!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot4!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot5!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot6!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot7!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot8!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot9!)
        
        // set the transparency of the bird background to 0
        self.setTransparency(TransparencyVal: 0, DotNum: hummingBird.birdBackground!)
        
        // self.captureSphere.look(at: <#T##SIMD3<Float>#>, from: SIMD3<Float>, relativeTo: Entity?)
        
        
//        // set tranparency of face to 0 in beginning
//        self.setTransparency(TransparencyVal: 0, DotNum: hummingBird.face!)
        
        // increase the size of the hummingbird & birdBackground in the beginning
        hummingBird.transform.scale *= 50
        hummingBird.birdBackground?.transform.scale *= 50
        
        jsonData = loadJson(fileName: "data")!
        
        // If the user taps the screen, the function "myviewTapped" is called
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.myviewTapped))
        arView.addGestureRecognizer(tapGesture)
        arView.session.delegate = self
             
        overlayUISetup()
        
        // threshold is 1 / 3 of maximum distance
        threshold = threshold / 3
    }
    
    @objc func myviewTapped(_sender: UITapGestureRecognizer) {
        
       // Ignore the tap if the user is editing a note.
       for note in Notes where note.isEditing { return }
       
       // Get the user's tap screen location.
       touchLocation = _sender.location(in: arView)

       // Cast a ray to check for its intersection with any planes
       // Cast a ray from the cameras origin through the touch location to check for intersection with any real worl surfaces along the ray
       // If ARKit finds a planar suface where the user tapped the ray cast result provides you the 3D intersection point in world Transform
       guard let raycastResult = arView.raycast(from: touchLocation, allowing: .estimatedPlane, alignment: .any).first else {
           print("no surface detected")
           return
       }

       // Create a new square note positioned at the hit test result's world position.
       let frame = CGRect(origin: touchLocation, size: CGSize(width: 150, height: 150))

       // Create an anchor positioned at the real world location
       // This is implemented as an Entity, create this Entity by calling its initalizer and passing in the ray-cast result's worldTransform
       let note = NoteEntity(frame: frame, worldTransform: raycastResult.worldTransform)

       // Center the note's view on the tap's screen location.
       note.setPositionCenter(touchLocation)

       // Add the note to the scene's entity hierarchy.
       arView.scene.addAnchor(note)

       // Add the note's view to the view hierarchy to display the entity's annotation
       guard let View = note.view else { return }
       arView.insertSubview(View, belowSubview: trashZone)

       // Save a reference to the  note.
       Notes.append(note)

       // Volunteer to handle text view callbacks.
       View.textView.delegate = self
        
        
       
    }


    @IBAction func start(_ sender: Any) {
        var slow_counter = 0
        var count = 0
        let hummingbirdPos = jsonData.hummingbirdPos
        let captureSpherePos = jsonData.spherePos
        let devicePos = jsonData.camPos
        let deviceRot = jsonData.deviceRotation
        let facePosition = jsonData.centerFacePos
        let movementType = jsonData.hummingbirdMovementType
        let lookAt = jsonData.lookAtPoint
        
        
        
        if let hummingBirdObj = self.hummingBird!.hummingBird {
            if let captureSphereObj = self.captureSphere!.captureSphere {
                
                // change timer back to 1/60 later
                var timer = Timer.scheduledTimer(withTimeInterval: 1/500, repeats: true){ t in
                    
                    // get position of hummingbird, capture sphere, & device
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    var captureSphereCoordinate = captureSpherePos[count]
                    var deviceCoordinate = devicePos[count]
                    var deviceRotCoordinate = deviceRot[count]
                    var birdMovementType = movementType[count]
                    var faceCoordinate = facePosition[count]
                   // var arrowCoordinate = hummingbirdPos[count + 3]
                    var lookAtPoint = lookAt[count]
                    
                    //. lookAtPoint
                   // print(type(of: lookAtPoint))
                    
                    var arrowCoordinate = hummingBirdCoordinate
                    arrowCoordinate["x"] = (hummingBirdCoordinate["x"] ?? 0) + 0.2
                    arrowCoordinate["y"] = (hummingBirdCoordinate["y"] ?? 0) - 0.05
                    arrowCoordinate["z"] = (hummingBirdCoordinate["z"] ?? 0) + 0.05
                    
                    // previous coordinates
                    var prev1HummingBirdCoordinate = hummingBirdCoordinate
                    var prev1CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev2HummingBirdCoordinate = hummingBirdCoordinate
                    var prev2CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev3HummingBirdCoordinate = hummingBirdCoordinate
                    var prev3CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev4HummingBirdCoordinate = hummingBirdCoordinate
                    var prev4CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev5HummingBirdCoordinate = hummingBirdCoordinate
                    var prev5CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev6HummingBirdCoordinate = hummingBirdCoordinate
                    var prev6CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev7HummingBirdCoordinate = hummingBirdCoordinate
                    var prev7CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev8HummingBirdCoordinate = hummingBirdCoordinate
                    var prev8CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev9HummingBirdCoordinate = hummingBirdCoordinate
                    var prev9CaptureSphereCoordinate = captureSphereCoordinate
        
                    if (count > 2) {
                        prev1HummingBirdCoordinate = hummingbirdPos[count - 3]
                        prev1CaptureSphereCoordinate = captureSpherePos[count - 3]
                    }
                    
                    if (count > 4) {
                        prev2HummingBirdCoordinate = hummingbirdPos[count - 5]
                        prev2CaptureSphereCoordinate = captureSpherePos[count - 5]
                    }
                    
                    if (count > 6) {
                        prev3HummingBirdCoordinate = hummingbirdPos[count - 7]
                        prev3CaptureSphereCoordinate = captureSpherePos[count - 7]
                    }
                    
                    if (count > 8) {
                        prev4HummingBirdCoordinate = hummingbirdPos[count - 9]
                        prev4CaptureSphereCoordinate = captureSpherePos[count - 9]
                    }
                    
                    if (count > 10) {
                        prev5HummingBirdCoordinate = hummingbirdPos[count - 11]
                        prev5CaptureSphereCoordinate = captureSpherePos[count - 11]
                    }
                    
                    if (count > 12) {
                        prev6HummingBirdCoordinate = hummingbirdPos[count - 13]
                        prev6CaptureSphereCoordinate = captureSpherePos[count - 13]
                    }
                    
                    if (count > 14) {
                        prev7HummingBirdCoordinate = hummingbirdPos[count - 15]
                        prev7CaptureSphereCoordinate = captureSpherePos[count - 15]
                    }
                    
                    if (count > 16) {
                        prev8HummingBirdCoordinate = hummingbirdPos[count - 17]
                        prev8CaptureSphereCoordinate = captureSpherePos[count - 17]
                    }
                    
                    if (count > 18) {
                        prev9HummingBirdCoordinate = hummingbirdPos[count - 19]
                        prev9CaptureSphereCoordinate = captureSpherePos[count - 19]
                    }
                
                    // set position of hummingbird
                    self.setPosition(objectCoordinate: hummingBirdCoordinate, object: hummingBirdObj, incScale: true)
                        
                    // set position of capture sphere
                    self.setPosition(objectCoordinate: captureSphereCoordinate, object: captureSphereObj, incScale: false)
                    
                    // set position of device
                    self.setPosition(objectCoordinate: deviceCoordinate, object: self.hummingBird.device!, incScale: false)
                    
                    // set position of face -- not showing up for some reason
                    self.setPosition(objectCoordinate: faceCoordinate, object: self.hummingBird.face!, incScale: false)
                    
                    // set position of arrow
                    self.setPosition(objectCoordinate: arrowCoordinate, object: self.hummingBird.arrow!, incScale: false)
                    //print("Device: ", deviceCoordinate)
                    // print("face: ", faceCoordinate)
                    
                    // set position of bird background as the same position of bird
                    var birdBackgroundCoordinate = hummingBirdCoordinate
                    birdBackgroundCoordinate["x"] = (hummingBirdCoordinate["x"] ?? 0) + 0.05
                    birdBackgroundCoordinate["y"] = (hummingBirdCoordinate["y"] ?? 0) - 0.02
                    
                    self.setPosition(objectCoordinate: birdBackgroundCoordinate, object: self.hummingBird.birdBackground!, incScale: false)
                    
                    // set color & transparency
                    self.setBirdBackgroundColor(background: self.hummingBird.birdBackground!, moveType: birdMovementType)
                    
                    // set rotation of device
                    self.setRotation(object: self.hummingBird.device!, rotation: deviceRotCoordinate)
                    
                    // intialize trailing dots behind capture sphere
                    let dot1 = self.captureSphere.dot1
                    let dot2 = self.captureSphere.dot2
                    let dot3 = self.captureSphere.dot3
                    let dot4 = self.captureSphere.dot4
                    let dot5 = self.captureSphere.dot5
                    let dot6 = self.captureSphere.dot6
                    let dot7 = self.captureSphere.dot7
                    let dot8 = self.captureSphere.dot8
                    let dot9 = self.captureSphere.dot9
                    
                    // set the position of these trailing dots
                    self.setPosition(objectCoordinate: prev1CaptureSphereCoordinate, object: dot1!, incScale: false)
                    self.setPosition(objectCoordinate: prev2CaptureSphereCoordinate, object: dot2!, incScale: false)
                    self.setPosition(objectCoordinate: prev3CaptureSphereCoordinate, object: dot3!, incScale: false)
                    self.setPosition(objectCoordinate: prev4CaptureSphereCoordinate, object: dot4!, incScale: false)
                    self.setPosition(objectCoordinate: prev5CaptureSphereCoordinate, object: dot5!, incScale: false)
                    self.setPosition(objectCoordinate: prev6CaptureSphereCoordinate, object: dot6!, incScale: false)
                    self.setPosition(objectCoordinate: prev7CaptureSphereCoordinate, object: dot7!, incScale: false)
                    self.setPosition(objectCoordinate: prev8CaptureSphereCoordinate, object: dot8!, incScale: false)
                    self.setPosition(objectCoordinate: prev9CaptureSphereCoordinate, object: dot9!, incScale: false)
                    
                    // set the transparency of these trailing dots
                    
                    self.countDots = 0
                    self.setTransparency(TransparencyVal: 0.9, DotNum: dot1!)
                    self.setTransparency(TransparencyVal: 0.8, DotNum: dot2!)
                    self.setTransparency(TransparencyVal: 0.7, DotNum: dot3!)
                    self.setTransparency(TransparencyVal: 0.6, DotNum: dot4!)
                    self.setTransparency(TransparencyVal: 0.5, DotNum: dot5!)
                    self.setTransparency(TransparencyVal: 0.4, DotNum: dot6!)
                    self.setTransparency(TransparencyVal: 0.3, DotNum: dot7!)
                    self.setTransparency(TransparencyVal: 0.2, DotNum: dot8!)
                    self.setTransparency(TransparencyVal: 0.1, DotNum: dot9!)
                                   
                    // this calls the function that is triggered when you tap on the capture sphere object
                    self.captureSphere.actions.colorChange.onAction = self.handleTapOnEntity(_:)
    
                    // increase scale of trailing dots
                    self.multScaleBy2(object1: dot1!, object2: dot2!, object3: dot3!, object4: dot4!,   object5: dot5!, object6: dot6!, object7: dot7!, object8: dot8!, object9: dot9!)
                    
                    self.findDistance(objectCoordinate1: hummingBirdCoordinate, objectCoordinate2: captureSphereCoordinate)
                    
                    self.hummingBird.face?.transform.scale *= 15
//                    self.hummingBird.birdBackground?.transform.scale *= 1.2
//                    self.hummingBird.hummingBird?.transform.scale *= 1.2
//                    self.hummingBird.arrow?.transform.scale *= 1.2\
//                    self.hummingBird.device?.transform.scale *= 1.2
//                    self.captureSphere.captureSphere?.transform.scale *= 1.2
//                    self.captureSphere.dot3?.transform.scale *= 1.2
//                    self.captureSphere.dot1?.transform.scale *= 1.2
//                    self.captureSphere.dot2?.transform.scale *= 1.2
//                    self.captureSphere.dot4?.transform.scale *= 1.2
//                    self.captureSphere.dot5?.transform.scale *= 1.2
//                    self.captureSphere.dot6?.transform.scale *= 1.2
//                    self.captureSphere.dot7?.transform.scale *= 1.2
//                    self.captureSphere.dot8?.transform.scale *= 1.2
//                    self.captureSphere.dot9?.transform.scale *= 1.2
                    
                    //let yRotation = 3.14159
                    //self.hummingBird.face?.orientation = simd_quatf(angle: Float(yRotation), axis: [0,1,0])
                    
                    let targetPos = SIMD3<Float>(lookAtPoint["x"] ?? 0, lookAtPoint["y"] ?? 0, lookAtPoint["z"] ?? 0)
                    let fromPos = SIMD3<Float>(faceCoordinate["x"] ?? 0, faceCoordinate["y"] ?? 0,
                                           faceCoordinate["z"] ?? 0)
                    let upVector = SIMD3<Float>(0, 1, 0)
                    
                    
                    //print(targetPos)
                    
                    // make it that face is always looking at look at point
//                    self.hummingBird.face?.look(
//                        at: targetPos,
//                        from: fromPos,
//                        relativeTo: self.hummingBird.face
//                    )
                    
                    self.hummingBird.arrow?.scale *= 0.3
                    
                    // pitch - x
                    // yaw - y
                    
                    var nextHummingBirdCoordinate = hummingbirdPos[count + 1]
                    let currentPosx = hummingBirdCoordinate["x"]
                    let currentPosy = hummingBirdCoordinate["y"]
                    let currentPosz = hummingBirdCoordinate["z"]
                    
                    let nextPosx = nextHummingBirdCoordinate["x"]
                    let nextPosy = nextHummingBirdCoordinate["y"]
                    let nextPosz = nextHummingBirdCoordinate["z"]
                    
                    let dx = (currentPosx ?? 0) - (nextPosx ?? 0)
                    let dy = (currentPosy ?? 0) - (nextPosy ?? 0)
                    let dz = (currentPosz ?? 0) - (nextPosz ?? 0)
                    
                    let yaw = atan2(dz, dx)
                    let pitch = atan2(sqrt(dz * dz + dx * dx), dy) + .pi
//
                    
//                    if (self.prevYaw != yaw) {
//                        print("yaw", yaw)
//                    }
//
//                    if (self.prevPitch != pitch) {
//                        print("pitch", pitch)
//                    }
            
                    self.hummingBird.face?.orientation = simd_quatf(angle: -.pi / 2, axis: [0,1,0])
                  //  self.hummingBird.device?.scale *= 2
                    
                    self.prevYaw = yaw
                    self.prevPitch = pitch
                    
                   // self.hummingBird.arrow?.orientation = simd_quatf(angle: pitch, axis: [1,0,0])
                    self.hummingBird.arrow?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
                    
                    self.drawLine(lookAtPoint: lookAtPoint, faceCoordinate: faceCoordinate)
                    slow_counter += 1
                    
                    // so that it moves slower, just for right now
                    if (slow_counter % 4 == 0) {
                        count += 1
                    }
                    
                    if count >= hummingbirdPos.count {
                        t.invalidate()
                    }
                    
                    
                }
            }
        }
    }
    
    private func drawLine(lookAtPoint: Dictionary<String, Float>, faceCoordinate:Dictionary<String, Float>) {

        let x1 = (faceCoordinate["x"] ?? 0)
        let y1 = (faceCoordinate["y"] ?? 0)
        let z1 = (faceCoordinate["z"] ?? 0)
        
        let x2 = (lookAtPoint["x"] ?? 0)
        let y2 = (lookAtPoint["y"] ?? 0)
        let z2 = (lookAtPoint["z"] ?? 0)
        
        // mid
        let xmid1 = (x1 + x2) / 2
        let ymid1 = (y1 + y2) / 2
        let zmid1 = (z1 + z2) / 2
        
        // b/w mid and x2
        let xmid2 = (xmid1 + x2) / 2
        let ymid2 = (ymid1 + y2) / 2
        let zmid2 = (zmid1 + z2) / 2
        
        // b/w mid and x1
        let xmid3 = (xmid1 + x1) / 2
        let ymid3 = (ymid1 + y1) / 2
        let zmid3 = (zmid1 + z1) / 2
        
        // find angle for arrow and face orientation
        
        // transparency
        var transparent_material = PhysicallyBasedMaterial()
        transparent_material.baseColor = .init(tint: .red)
        transparent_material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
    
    

    
        // set positions
        //look at point
        var objectTranslation = SIMD3<Float>(x: x2, y: y2, z: z2)
        var objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)
        self.hummingBird.arrow6?.scale *= 0.4
        self.hummingBird.arrow6?.move(to: objectTransform, relativeTo: nil)
        
        let dx = x1 - x2
        let dy = y1 - y2
        let dz = z1 - z2
        
        let yaw = atan2(dz, dx)
                
        self.hummingBird.arrow6?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
        self.hummingBird.face?.orientation = simd_quatf(angle: -yaw + (.pi / 2) + .pi, axis: [0,1,0])
        
        if let modelEntity = self.hummingBird.arrow6?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }
        
        // mid
        let objectTranslation2 = SIMD3<Float>(x: xmid1, y: ymid1, z: zmid1)
        var objectTransform2 = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation2)

        self.hummingBird.line2?.move(to: objectTransform2, relativeTo: nil)
        self.hummingBird.line2?.scale *= 0.7
        
        if let modelEntity = self.hummingBird.line2?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }
        
        

        // b/w mid and x2
        objectTranslation = SIMD3<Float>(x: xmid2, y: ymid2, z: zmid2)
        objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)
        self.hummingBird.line3?.move(to: objectTransform, relativeTo: nil)
        self.hummingBird.line3?.scale *= 0.7
        
        if let modelEntity = self.hummingBird.line3?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }

        // b/w mid and x1
        objectTranslation = SIMD3<Float>(x: xmid3, y: ymid3, z: zmid3)
        objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)
        self.hummingBird.line4?.move(to: objectTransform, relativeTo: nil)
        self.hummingBird.line4?.scale *= 0.7
        
        if let modelEntity = self.hummingBird.line4?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }
        
        // face
        objectTranslation = SIMD3<Float>(x: x1, y: y1, z: z1)
        objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)
        self.hummingBird.line5?.move(to: objectTransform, relativeTo: nil)
        self.hummingBird.line5?.scale *= 0.7
        
        if let modelEntity = self.hummingBird.line5?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }
           
    }

    private func setBirdBackgroundColor(background: Entity, moveType: String) {
        // set transparency
        var transparent_material = PhysicallyBasedMaterial()
        
        // then set color based on movement type
        if (moveType == "Forward Movement" || moveType == "Movement Forward After Failing" ||
            moveType == "Continuing Forward From Escape" || moveType == "Escape Movement") { // moving
            
            transparent_material.baseColor = .init(tint: .green)
            
            //self.hummingBird.arrow?.scale *
        }
        
        else { // stopped
            transparent_material.baseColor = .init(tint: .red)
            
            // make direction arrow disappear when it is stopped
            
            
            //self.hummingBird.arrow?.scale *= 0.001
        }
        
        
        transparent_material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
        
        
//        if let modelEntity = background.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = transparent_material
//
//        }
        
        if let modelEntity = self.hummingBird.arrow!.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
            
        }
    }

    private func setRotation(object: Entity, rotation: Dictionary<String, Float>) {
        
        // rotation in radians
        // [-pi/2, pi/2]
        let xRotation = (rotation["x"] ?? 0)
        let yRotation = (rotation["y"] ?? 0)
        let zRotation = (rotation["z"] ?? 0)
        
        object.orientation = simd_quatf(angle: xRotation, axis: [1,0,0]) // x - axis
        object.orientation = simd_quatf(angle: yRotation, axis: [0,1,0]) // y - axis
        object.orientation = simd_quatf(angle: zRotation, axis: [0,0,1]) // z - axis
    }
    
    // function finds distance between two objects
    private func findDistance(objectCoordinate1: Dictionary<String, Float>, objectCoordinate2: Dictionary<String, Float>) {
        
        let x1 = (objectCoordinate1["x"] ?? 0)
        let y1 = (objectCoordinate1["y"] ?? 0)
        let z1 = (objectCoordinate1["z"] ?? 0)
        
        let x2 = (objectCoordinate2["x"] ?? 0)
        let y2 = (objectCoordinate2["y"] ?? 0)
        let z2 = (objectCoordinate2["z"] ?? 0)
        
        let xdiff = abs(x1 - x2)
        let ydiff = abs(y1 - y2)
        let zdiff = abs(z1 - z2)
        
        let xpow = pow(xdiff, 2)
        let ypow = pow(ydiff, 2)
        let zpow = pow(zdiff, 2)
        
        // calculate distance
        let distance = sqrt(zpow + ypow + zpow)
        
        // if capture sphere and hummingbird are within a certain distance then capture sphere changes color to blue
        //if (Float(distance) < Float(threshold)) {
            
            
        setColorBlue(distance: distance)
       // }
        
        // otherwise the color of the capture sphere is gray
//        else {
//            setColorGray()
//        }
//
        // keep track of and update max distance
        if (Float(distance) > Float(maxDistance)) {
            maxDistance = Float(distance)
            
           // print(maxDistance)
        }
        
        
     
    }
    
    // function that is called when you tap on the capture sphere
    func handleTapOnEntity(_ entity: Entity?) {
        guard let entity = entity else { return }
        
        blueSphere = true
        
       // setColorBlue()
        
        
    }
    
    private func multScaleBy2(object1: Entity, object2: Entity, object3: Entity, object4: Entity, object5: Entity, object6: Entity, object7: Entity, object8: Entity, object9: Entity) {
        
        object1.transform.scale *= 2.0
        object2.transform.scale *= 2.0
        object3.transform.scale *= 2.0
        object4.transform.scale *= 2.0
        object5.transform.scale *= 2.0
        object6.transform.scale *= 2.0
        object7.transform.scale *= 2.0
        object8.transform.scale *= 2.0
        object9.transform.scale *= 2.0
        
        
    }
    
    private func setPosition(objectCoordinate: Dictionary<String, Float> , object: Entity, incScale: Bool) {

        let posx = (objectCoordinate["x"] ?? 0)
        let posy = (objectCoordinate["y"] ?? 0)
        let posz = (objectCoordinate["z"] ?? 0)

        let objectTranslation = SIMD3<Float>(x: posx, y: posy, z: posz)
        var objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)

//        let radians = device
//        objectTransform.rotation = += simd_quatf(angle: radians, axis: SIMD3<Float>(1,0,0))
        
        if (incScale) {
            
            // multiple the scale of the hummingbird by 50 since the model being used is very small
            objectTransform.scale *= 50
            
        }
        
        object.move(to: objectTransform, relativeTo: nil)

    }
    private func setColorGray() {
        
        blueSphere = false
        
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        color_material.baseColor = .init(tint: .lightGray)
        
        if let modelEntity = self.captureSphere.captureSphere!.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
        
    }
    
    private func setColorGreen() {
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        color_material.baseColor = .init(tint: .green)
        
        //print(self.hummingBird.birdBackground!)
        if let modelEntity = self.hummingBird.birdBackground!.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
    }
    
    private func setColorRed() {
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        color_material.baseColor = .init(tint: .red)
        if let modelEntity = self.hummingBird.birdBackground!.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
    }
    
    private func setColorBlue(distance: Float) {
        
        //blueSphere = true
        
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        
        if (Float(distance) > Float(threshold)) {
            
            light1 = true
            color_material.baseColor = .init(tint: .init(cgColor: light1Blue))
            
            
            
        }
        
        else if (Float(distance) > (0.7 * Float(threshold))) {
            light2 = true
            color_material.baseColor = .init(tint: .init(cgColor: light2Blue))
        }
        
       
        
        else if (Float(distance) < (0.5 * Float(threshold))) {
            
            light3 = true
            color_material.baseColor = .init(tint: .init(cgColor: light3Blue))
        }
        
        else if (Float(distance) < (0.3 * Float(threshold))) {
            
            light4 = true
            color_material.baseColor = .init(tint: .init(cgColor: light4Blue))
        }
        
        else if (Float(distance) < (0.2 * Float(threshold))) {
            
            light5 = true
            color_material.baseColor = .init(tint: .init(cgColor: light5Blue))
        }
        
        else if (Float(distance) < (0.1 * Float(threshold))) {
            
            light6 = true
            color_material.baseColor = .init(tint: .init(cgColor: light6Blue))
        }
        
        else {
            
           light7 = true
           color_material.baseColor = .init(tint: .init(cgColor: light7Blue))
        }

        
        //color_material.baseColor = .init(tint: .blue)
        
        if let modelEntity = self.captureSphere.captureSphere!.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
    }

    private func setTransparency(TransparencyVal: Float, DotNum: Entity) {
        
        countDots += 1
        
        var transparent_material = PhysicallyBasedMaterial()
     
        if (blueSphere == true) {
            transparent_material.baseColor = .init(tint: .blue)
            
            blueSphere = false
        }
        else if (light1 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light1Blue))
           
        }
        else if (light2 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light2Blue))
            
        }
        else if (light3 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light3Blue))
           
        }
        else if (light4 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light4Blue))
            
        }
        else if (light5 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light5Blue))
            
        }
        else if (light6 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light6Blue))
            
        }
        
        else if (light7 == true) {
            transparent_material.baseColor = .init(tint: .init(cgColor: light7Blue))
            
            
        }
        
        if (countDots >= 9) {
            light1 = false
            light2 = false
            light3 = false
            light4 = false
            light5 = false
            light6 = false
            light7 = false
            
            countDots = 0
        }
        
        
        
        
        
        transparent_material.blending = .transparent(opacity: .init(floatLiteral: TransparencyVal))
        
        
        if let modelEntity = DotNum.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = transparent_material
        
        }
        
    }

    private func loadJson(fileName: String) -> GameData? {
        if let url = Bundle.main.url(forResource: fileName, withExtension: "json") {
            if let data = try? Data(contentsOf: url) {
                do {
                    let decoder = JSONDecoder()
                    let json = try decoder.decode(GameData.self, from: data)
                    return json
                }
                catch {
                    print(error)
                }
            }
        }
        
        return nil
    }
    
    func updateScene(on event: SceneEvents.Update) {
        let notesToUpdate = Notes.compactMap { !$0.isEditing && !$0.isDragging ? $0 : nil }
        for note in notesToUpdate {
            // Gets the 2D screen point of the 3D world point.
            guard let projectedPoint = arView.project(note.position) else { return }

            // Calculates whether the note can be currently visible by the camera.
            let cameraForward = arView.cameraTransform.matrix.columns.2.self[SIMD3(0, 1, 2)]
            let cameraToWorldPointDirection = normalize(note.transform.translation - arView.cameraTransform.translation)
            let dotProduct = dot(cameraForward, cameraToWorldPointDirection)
            let isVisible = dotProduct < 0

            // Updates the screen position of the note based on its visibility
            note.projection = Projection(projectedPoint: projectedPoint, isVisible: isVisible)
            note.updateScreenPosition()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Add observer to the keyboardWillChangeFrameNotification to get the height of the keyboard every time its frame changes.
        let notificationName = UIResponder.keyboardWillChangeFrameNotification
        let selector = #selector(keyboardIsPoppingUp(notification:))
        NotificationCenter.default.addObserver(self, selector: selector, name: notificationName, object: nil)

    }

    // Gets the height of the keyboard every time it appears
    @objc
    func keyboardIsPoppingUp(notification: NSNotification) {

        if let keyboardFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {

            lastKeyboardHeight = keyboardFrame.height

            // Animates the selected view based on the new keyboard height.
            // Makes sure that the note is above where the keyboard pops up so the user can see it
            if let selectedView {
                animateViewToEditingFrame(selectedView,
                                                keyboardHeight: keyboardFrame.height)
            }
        }
    }
    
    
    // - Tag: TextViewDidBeginEditing
    func textViewDidBeginEditing(_ textView: UITextView) {

        // Get the main view for this note.
        guard let View = textView.firstSuperViewOfType(NoteView.self) else { return }
      
        // Clear "New Annotation" Placeholder text when the user stars to edit the note
        textView.text = ""
        textView.textColor = .white
        
        // Bring the note being edited to the front so that you cannot see other notes in the background while you are editig
        arView.insertSubview(View, belowSubview: trashZone)
        
        View.Note.isEditing = true

        selectedView = View
    }
    
    // View when the user is done editing the note and it moves back to background
    func textViewDidEndEditing(_ textView: UITextView) {
        guard let View = textView.firstSuperViewOfType(NoteView.self) else { return }
        
        View.Note.shouldAnimate = true
        
        View.Note.isEditing = false
        
        // make note smaller and bring to background, make this an animation
        // duration -> how long it takes for note to move back to the location you tapped at
        // curve -> when the note moves back to the location you tapped at, the acceleration of speed it moves back in
        UIViewPropertyAnimator(duration: 0.25, curve: .easeIn) {
            View.frame = View.lastFrame
        }.startAnimation()
    }
        
    // View when user clicks on note and starts editing it
    func animateViewToEditingFrame(_ View: NoteView, keyboardHeight: Double) {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        
        // you want the note to be above the keyboard, so adjust height for that
        let height = safeFrame.height - keyboardHeight
        
        // frame shrinks by this amount to create border between the note and the frame
        let inset_size = height * 0.1
        
        // bring the note in front, change the size of it, so that you can edit it
        UIViewPropertyAnimator(duration: 0.2, curve: .easeOut) {

            View.frame = CGRect(origin: safeFrame.origin, size: CGSize(width: safeFrame.width, height: height)).insetBy(dx: inset_size, dy: inset_size)

        }.startAnimation()
    }
    
    func overlayUISetup() {
        
        // Setting up the trashZone, which is used to delete Views and their associated Notes.
        setupTrashZone()
    }

    fileprivate func setupTrashZone() {
        trashZone = GradientView(topColor: UIColor.red.withAlphaComponent(0.7).cgColor, bottomColor: UIColor.red.withAlphaComponent(0).cgColor)
        trashZone.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(trashZone)
        NSLayoutConstraint.activate([
            trashZone.topAnchor.constraint(equalTo: arView.topAnchor),
            trashZone.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            trashZone.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            trashZone.heightAnchor.constraint(equalTo: arView.heightAnchor, multiplier: 0.33)
        ])
        trashZone.alpha = 0
    }
}

