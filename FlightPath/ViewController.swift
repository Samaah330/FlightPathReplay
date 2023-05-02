import UIKit
import RealityKit
import ARKit
import Combine
import Darwin

class ViewController: UIViewController , ARSessionDelegate, UITextViewDelegate, ARCoachingOverlayViewDelegate, ARSCNViewDelegate {
    
    @IBOutlet var arView: ARView!
    @IBOutlet var arSCNView : ARSCNView!
    var jsonData: GameData!
    var counter = 0
    var devideAmount = Float(9.0)
    var reduceSize = Float(0.2)

    var hummingBird: HummingBird._HummingBird!
    var captureSphere: CaptureSphere._CaptureSphere!
    
    // sticky notes
    var touchLocation: CGPoint!
    var trashZone: GradientView!
    var shadeView: UIView!
    var Notes = [NoteEntity]()
    weak var selectedView: NoteView?
    var lastKeyboardHeight: Double?
    var subscription: Cancellable!

    // orientation
    var prevYaw = Float(0.1)
    var prevPitch = Float(0.1)

    // maximum distance between the sphere and the hummingbird
    var maxDistance : Float = 0.0 // 2.14949
    var threshold = 2.14949
    
    var countDots = 0
    
    // line between entitys
//    var bottomLineFace = ModelEntity()
//    var bottomLineBird = ModelEntity()
    var countLine = 0
    var transparency_material_line = PhysicallyBasedMaterial()
    var listBirdLines: [ModelEntity] = []
    var listBirdAnchors: [AnchorEntity] = []
    var listBirdTransparencies: [Double] = []
    
    var listFaceLines: [ModelEntity] = []
    var listFaceAnchors: [AnchorEntity] = []
    var listFaceTransparencies: [Double] = []
    
    var line_width = 0.0008
    
    // capture sphere colors
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
        
        // increase the size of the hummingbird & birdBackground in the beginning
        hummingBird.transform.scale *= 50
        
        // If the user taps the screen, the function "myviewTapped" is called
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.myviewTapped))
        arView.addGestureRecognizer(tapGesture)
        arView.session.delegate = self
            
        // threshold is 1 / 3 of maximum distance
        threshold = threshold / 3
        
        jsonData = loadJson(fileName: "data")!
        overlayUISetup()
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
                    
                    // get positions of components
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    var captureSphereCoordinate = captureSpherePos[count]
                    var deviceCoordinate = devicePos[count]
                    var deviceRotCoordinate = deviceRot[count]
                    var birdMovementType = movementType[count]
                    var faceCoordinate = facePosition[count]
                   // var arrowCoordinate = hummingbirdPos[count + 3]
                    var lookAtPoint = lookAt[count]
                    
//                    var arrowCoordinate = hummingBirdCoordinate
//                    arrowCoordinate["x"] = (hummingBirdCoordinate["x"] ?? 0) + 0.2
//                    arrowCoordinate["y"] = (hummingBirdCoordinate["y"] ?? 0) - 0.05
//                    arrowCoordinate["z"] = (hummingBirdCoordinate["z"] ?? 0) + 0.05
                
                    // set position of hummingbird
                    self.setPosition(objectCoordinate: hummingBirdCoordinate, object: hummingBirdObj, incScale: true)
                    
                    // set position of device
                    self.setPosition(objectCoordinate: deviceCoordinate, object: self.hummingBird.device!, incScale: false)
                    
                    // set position of face
                    self.setPosition(objectCoordinate: faceCoordinate, object: self.hummingBird.face!, incScale: false)
                    
                    // set position of look at point arrow
                    //self.setPosition(objectCoordinate: lookAtPoint, object: self.hummingBird.arrow6!, incScale: false)
                    
                    // set position of bird arrow
//                    self.setPosition(objectCoordinate: arrowCoordinate, object: self.hummingBird.arrow!, incScale: false)
//
                    // set rotation of device
                    self.setRotation(object: self.hummingBird.device!, rotation: deviceRotCoordinate)
            
                    // initialize capture sphere
                    self.initializeCaptureSphere(count: count, hummingBirdCoordinate: hummingBirdCoordinate, captureSphereCoordinate: captureSphereCoordinate, hummingbirdPos: hummingbirdPos, captureSpherePos: captureSpherePos, captureSphereObj: captureSphereObj)

                    self.findDistance(objectCoordinate1: hummingBirdCoordinate, objectCoordinate2: captureSphereCoordinate)
                    
                    self.hummingBird.face?.transform.scale *= 10
                    self.hummingBird.arrow6?.transform.scale *= 0
                    self.hummingBird.arrow?.scale *= 0 // 0.3
                    self.hummingBird.device?.scale *= 2
                
                    var nextHummingBirdCoordinate = hummingbirdPos[count + 1]
                    self.setOrientation(point1: hummingBirdCoordinate, point2: nextHummingBirdCoordinate, type_obj: "Bird")
                 
                    
                    // create new line every 50 * 4 = 200 frames
                    if (slow_counter % 70 == 0) {
                        
                        // create line between entitys
                        var bottomLineBird = ModelEntity()
                        var bottomLineFace = ModelEntity()
                        
                        // line between face and lookat point - (using ipad location right now)
                        self.draw2DLine(point1: faceCoordinate, point2: lookAtPoint, type_obj: "Face", counter: count, LineEntity: bottomLineFace)
                        
                        // line between hummingbird and sphere
                        self.draw2DLine(point1: hummingBirdCoordinate, point2: captureSphereCoordinate, type_obj: "Bird", counter: slow_counter, LineEntity: bottomLineBird)
                    }
                    
                    
                        
                    self.setOrientation(point1: faceCoordinate, point2: lookAtPoint, type_obj: "Face")
                    self.setOrientation(point1: deviceCoordinate, point2: captureSphereCoordinate, type_obj: "Device")
                    
                    //self.setBirdArrowColor(moveType: birdMovementType)
                    
                    // reduce size of all objects
                    self.reduceAllSize()
                    
                    // blur background
                    //self.blurBackground()
                    
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
    
    private func blurBackground() {
        
        // currently making everything black
        arView.backgroundColor = .clear
        
        let blurEffect = UIBlurEffect(style: .dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        //always fill the view
        blurEffectView.frame = self.view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(blurEffectView)
    }
    
    private func reduceAllSize() {
        self.captureSphere.captureSphere?.scale *= reduceSize
        self.captureSphere.dot1?.scale *= reduceSize
        self.captureSphere.dot2?.scale *= reduceSize
        self.captureSphere.dot3?.scale *= reduceSize
        self.captureSphere.dot4?.scale *= reduceSize
        self.captureSphere.dot5?.scale *= reduceSize
        self.captureSphere.dot6?.scale *= reduceSize
        self.captureSphere.dot7?.scale *= reduceSize
        self.captureSphere.dot8?.scale *= reduceSize
        self.captureSphere.dot9?.scale *= reduceSize
        
        self.hummingBird.hummingBird?.scale *= reduceSize
        self.hummingBird.face?.scale *= reduceSize
        self.hummingBird.device?.scale *= reduceSize
        //self.hummingBird.arrow6?.scale *= reduceSize
       // self.hummingBird.arrow?.scale *= reduceSize
    }
    
    private func initializeCaptureSphere(count: Int, hummingBirdCoordinate:  Dictionary<String, Float>, captureSphereCoordinate:  Dictionary<String, Float>, hummingbirdPos: Array<Dictionary<String, Float>>, captureSpherePos: Array<Dictionary<String, Float>>, captureSphereObj: Entity ) {
        
        self.setCaptureSpherePosition(count: count, hummingBirdCoordinate: hummingBirdCoordinate, captureSphereCoordinate: captureSphereCoordinate, hummingbirdPos: hummingbirdPos, captureSpherePos: captureSpherePos, captureSphereObj: captureSphereObj)
        
        self.setSphereTransparencyAndScale(captureSphere: self.captureSphere)
        
        // this calls the function that is triggered when you tap on the capture sphere object
        self.captureSphere.actions.colorChange.onAction = self.handleTapOnEntity(_:)
        
    }
    
    private func setSphereTransparencyAndScale(captureSphere: Entity) {
        
        let dot1 = self.captureSphere.dot1
        let dot2 = self.captureSphere.dot2
        let dot3 = self.captureSphere.dot3
        let dot4 = self.captureSphere.dot4
        let dot5 = self.captureSphere.dot5
        let dot6 = self.captureSphere.dot6
        let dot7 = self.captureSphere.dot7
        let dot8 = self.captureSphere.dot8
        let dot9 = self.captureSphere.dot9

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
        
        // increase scale of trailing dots
        self.multScaleBy2(object1: dot1!, object2: dot2!, object3: dot3!, object4: dot4!,   object5: dot5!, object6: dot6!, object7: dot7!, object8: dot8!, object9: dot9!)
    }
    
    private func setCaptureSpherePosition(count: Int, hummingBirdCoordinate:  Dictionary<String, Float>, captureSphereCoordinate:  Dictionary<String, Float>, hummingbirdPos: Array<Dictionary<String, Float>>, captureSpherePos: Array<Dictionary<String, Float>>, captureSphereObj: Entity ) {

        // set position of main capture sphere
        self.setPosition(objectCoordinate: captureSphereCoordinate, object: captureSphereObj, incScale: false)

        // initialize previous coordinates
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

    }
    
    private func draw2DLine(point1: Dictionary<String, Float>, point2: Dictionary<String, Float>, type_obj: String, counter: Int, LineEntity: ModelEntity) {
    
        let anchor = AnchorEntity()
        
        let line_opacity_value = 1.0
        
        // append onto list
        
        if (type_obj == "Face") {
            listFaceLines.append(LineEntity)
            listFaceAnchors.append(anchor)
            listFaceTransparencies.append(line_opacity_value)
        }
        else if (type_obj == "Bird") {
            listBirdLines.append(LineEntity)
            listBirdAnchors.append(anchor)
            listBirdTransparencies.append(line_opacity_value)
        }
                        
        // set position of new line
        let x1 = (point1["x"] ?? 0) / devideAmount
        let y1 = (point1["y"] ?? 0) / devideAmount
        let z1 = (point1["z"] ?? 0) / devideAmount

        let x2 = (point2["x"] ?? 0) / devideAmount
        let y2 = (point2["y"] ?? 0) / devideAmount
        let z2 = (point2["z"] ?? 0) / devideAmount

        let midPosition = SIMD3<Float>(x:(x1 + x2) / 2,
                                  y:(y1 + y2) / 2,
                                  z:(z1 + z2) / 2)

        let position1 = SIMD3<Float>(x: x1, y: y1, z: z1)
        let position2 = SIMD3<Float>(x: x2, y: y2, z: z2)

        
        anchor.position = midPosition
        anchor.look(at: position1, from: midPosition, relativeTo: nil)

        if (type_obj == "Face") {
            transparency_material_line.baseColor = .init(tint: .red)
        }

        else if (type_obj == "Bird") {
            transparency_material_line.baseColor = .init(tint: .gray)
        }
    
        transparency_material_line.blending = .transparent(opacity: .init(floatLiteral: Float(line_opacity_value)))
        
        // update opacity of all the lines
        self.setTransparencyLine(type_obj: type_obj)
        
        // create mesh
        let depth_size = simd_distance(position1, position2)

        let bottomLineMesh = MeshResource.generateBox(width: Float(line_width),
                                                      height: Float(line_width),
                                                      depth: depth_size)
        //update model with mesh
        LineEntity.model = .init(mesh: bottomLineMesh, materials: [transparency_material_line])
        
        anchor.addChild(LineEntity)
        arView.scene.addAnchor(anchor)
    
        countLine += 1
    }

    private func setTransparencyLine(type_obj: String) {
        
        if (type_obj == "Bird") {
            var j = 0
            // go through entire list and decrease transparency, delete if transparency is zero
            for transparency_val in listBirdTransparencies {
                // transparency_val -= 0.1 // error - not mutating the value
                
                listBirdTransparencies[j] -= 0.35
                
                if (transparency_val <= 0.0) {
                    
                    // delete that line
                    let firstAnchor = listBirdAnchors[0]
                    let firstLine = listBirdLines[0]
                    
                    firstAnchor.removeChild(firstLine)
                    
                    listBirdLines.remove(at: 0)
                    listBirdAnchors.remove(at: 0)
                    listBirdTransparencies.remove(at: 0)
                    break
                    
                }
                
                j += 1
            }
            
            var i = 0
            for line in listBirdLines {
                
                var transparencyMat = PhysicallyBasedMaterial()
                let transparency_val = listBirdTransparencies[i]
            
                // set color and transparency
                transparencyMat.baseColor = .init(tint: .gray)
                transparencyMat.blending = .transparent(opacity: .init(floatLiteral: Float(transparency_val)))
                
                // update the material of the line
                line.model?.materials = [transparencyMat]
                
                i += 1
            }
        }
        else if (type_obj == "Face") {
            var j = 0
            // go through entire list and decrease transparency, delete if transparency is zero
            for transparency_val in listFaceTransparencies {
                // transparency_val -= 0.1 // error - not mutating the value
                
                listFaceTransparencies[j] -= 0.35
                
                if (transparency_val <= 0.0) {
                    
                    // delete that line
                    let firstAnchor = listFaceAnchors[0]
                    let firstLine = listFaceLines[0]
                    
                    firstAnchor.removeChild(firstLine)
                    
                    listFaceLines.remove(at: 0)
                    listFaceAnchors.remove(at: 0)
                    listFaceTransparencies.remove(at: 0)
                    break
                    
                }
                
                j += 1
            }
            
            var i = 0
            for line in listFaceLines {
                
                var transparencyMat = PhysicallyBasedMaterial()
                let transparency_val = listFaceTransparencies[i]
                
                print(transparency_val)
                // set color and transparency
                transparencyMat.baseColor = .init(tint: .red)
                transparencyMat.blending = .transparent(opacity: .init(floatLiteral: Float(transparency_val)))
                
                // update the material of the line
                line.model?.materials = [transparencyMat]
                
                i += 1
            }
            
        }
    }
    
    private func setOrientation(point1: Dictionary<String, Float>, point2: Dictionary<String, Float>, type_obj: String) {

        // NOTE: pitch = x & yaw = y
         let x1 = (point1["x"] ?? 0) / devideAmount
         let y1 = (point1["y"] ?? 0) / devideAmount
         let z1 = (point1["z"] ?? 0) / devideAmount

         let x2 = (point2["x"] ?? 0) / devideAmount
         let y2 = (point2["y"] ?? 0) / devideAmount
         let z2 = (point2["z"] ?? 0) / devideAmount
        
        // face orientation
        let dx = x1 - x2
        let dy = y1 - y2
        let dz = z1 - z2
        
        let yaw = atan2(dz, dx)
                
        if (type_obj == "Face") {
            self.hummingBird.face?.orientation = simd_quatf(angle: -yaw + (.pi / 2) + .pi, axis: [0,1,0])
            //self.hummingBird.arrow6?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
        }
        
//        else if (type_obj == "Bird") {
//            self.hummingBird.arrow?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
//        }
        
        else if (type_obj == "Device") {
            self.hummingBird.device?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
        }
        
    }

    private func setBirdArrowColor(moveType: String) {
        var transparent_material = PhysicallyBasedMaterial()
        
        // then set color based on movement type
        if (moveType == "Forward Movement" || moveType == "Movement Forward After Failing" ||
            moveType == "Continuing Forward From Escape" || moveType == "Escape Movement") { // moving
            
            transparent_material.baseColor = .init(tint: .green)
        }
        
        else { // stopped
            transparent_material.baseColor = .init(tint: .red)
        }
        
        transparent_material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
        
//        if let modelEntity = self.hummingBird.arrow!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = transparent_material
//
//        }
    }

    private func setRotation(object: Entity, rotation: Dictionary<String, Float>) {
        
        // rotation in radians
        // [-pi/2, pi/2]
        let xRotation = (rotation["x"] ?? 0) / devideAmount
        let yRotation = (rotation["y"] ?? 0) / devideAmount
        let zRotation = (rotation["z"] ?? 0) / devideAmount
        
        object.orientation = simd_quatf(angle: xRotation, axis: [1,0,0]) // x - axis
        object.orientation = simd_quatf(angle: yRotation, axis: [0,1,0]) // y - axis
        object.orientation = simd_quatf(angle: zRotation, axis: [0,0,1]) // z - axis
    }
    
    private func ReturnfindDistance(objectCoordinate1: Dictionary<String, Float>, objectCoordinate2: Dictionary<String, Float>) -> Float{
        
        let x1 = (objectCoordinate1["x"] ?? 0) / devideAmount
        let y1 = (objectCoordinate1["y"] ?? 0) / devideAmount
        let z1 = (objectCoordinate1["z"] ?? 0) / devideAmount
        
        let x2 = (objectCoordinate2["x"] ?? 0) / devideAmount
        let y2 = (objectCoordinate2["y"] ?? 0) / devideAmount
        let z2 = (objectCoordinate2["z"] ?? 0) / devideAmount
        
        let xdiff = abs(x1 - x2)
        let ydiff = abs(y1 - y2)
        let zdiff = abs(z1 - z2)
        
        let xpow = pow(xdiff, 2)
        let ypow = pow(ydiff, 2)
        let zpow = pow(zdiff, 2)
        
        // calculate distance
        let distance = sqrt(zpow + ypow + zpow)
        
        return distance
    }
    
    // function finds distance between two objects
    private func findDistance(objectCoordinate1: Dictionary<String, Float>, objectCoordinate2: Dictionary<String, Float>) {
        
        let x1 = (objectCoordinate1["x"] ?? 0) / devideAmount
        let y1 = (objectCoordinate1["y"] ?? 0) / devideAmount
        let z1 = (objectCoordinate1["z"] ?? 0) / devideAmount
        
        let x2 = (objectCoordinate2["x"] ?? 0) / devideAmount
        let y2 = (objectCoordinate2["y"] ?? 0) / devideAmount
        let z2 = (objectCoordinate2["z"] ?? 0) / devideAmount
        
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

        let posx = (objectCoordinate["x"] ?? 0) / devideAmount
        let posy = (objectCoordinate["y"] ?? 0) / devideAmount
        let posz = (objectCoordinate["z"] ?? 0) / devideAmount

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
//
//    private func setColorGreen() {
//        var color_material = PhysicallyBasedMaterial()
//
//        // how you change the color of an object
//        color_material.baseColor = .init(tint: .green)
//
//        //print(self.hummingBird.birdBackground!)
//        if let modelEntity = self.hummingBird.birdBackground!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = color_material
//        }
//    }
    
//    private func setColorRed() {
//        var color_material = PhysicallyBasedMaterial()
//
//        // how you change the color of an object
//        color_material.baseColor = .init(tint: .red)
//        if let modelEntity = self.hummingBird.birdBackground!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = color_material
//        }
//    }

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

