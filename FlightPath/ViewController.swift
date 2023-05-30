import UIKit
import RealityKit
import ARKit
import Combine
import Darwin

class ViewController: UIViewController , ARSessionDelegate, UITextViewDelegate, ARCoachingOverlayViewDelegate, ARSCNViewDelegate{
    
    @IBOutlet var arView: ARView!
    
    // Store
    let lineLengthUI = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
    let projectionUI = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))
    
    var jsonData: GameData!
    var counter = 0

    var devideAmount = Float(9.0)
    var reduceSize = Float(0.4)

    // Hummingbird and Capture Sphere Entity
    var hummingBird: HummingBird._HummingBird!
    var captureSphere: CaptureSphere._CaptureSphere!
    
    // Store
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
    
    // Stores number of spheres created
    var countSpheres = 0
    
    var listBirdLines: [ModelEntity] = []
    var listBirdAnchors: [AnchorEntity] = []
    var listBirdTransparencies: [Double] = []
    var listBirdTimes: [Double] = []
    
    // Used to create new lines between capture sphere and device every couple of frames
    var listDeviceLines: [ModelEntity] = []
    var listDeviceAnchors: [AnchorEntity] = []
    var listDeviceTransparencies: [Double] = []
    
    // Used to store and update material of lines
    var transparency_material_line = PhysicallyBasedMaterial()
    
    // Used to create spheres every couple of frames to mark catpure sphere trajectory
    var listSpheres: [ModelEntity] = []
    var listSphereAnchors: [AnchorEntity] = []
    var listSphereTransparencies: [Double] = []
    var listSphereTimes: [Double] = []
    
    // Used to store and update material of spheres
    var transparency_material_sphere = PhysicallyBasedMaterial()
    
    // Stores previous capture sohere coordinate
    var prevCapCoord : Dictionary<String, Float> = ["": 0]
    
    
    
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

    // Data extracted into variables
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
        
        // length of line - set position
        lineLengthUI.center = CGPoint(x: 100, y: 750)
        lineLengthUI.textAlignment = .center
        
        // projection - set position
        projectionUI.center = CGPoint(x: 250, y: 750)
        projectionUI.textAlignment = .center
        
        // Load the "Box" scene from the "Experience" Reality File
        hummingBird = try! HummingBird.load_HummingBird()
        captureSphere = try! CaptureSphere.load_CaptureSphere()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(hummingBird!)
        arView.scene.anchors.append(captureSphere!)
        
        // increase the size of the hummingbird & birdBackground in the beginning
        hummingBird.transform.scale *= 50
        
        // remove face for now since lookat positition has inaccurate data
        hummingBird.face?.scale *= 0
       
        // If the user taps the screen, the function "myviewTapped" is called
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.myviewTapped))
        arView.addGestureRecognizer(tapGesture)
        arView.session.delegate = self
        
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
                                
                // originally - withTimeInterval was 1/60. However it was too fast for replay. Changed to 1/500 so that the user can more clearly see what is happening because the replay is moving slower
                var timer = Timer.scheduledTimer(withTimeInterval: 1/500, repeats: true){ t in
                    
                    // get positions of components
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    var captureSphereCoordinate = captureSpherePos[count]
                    var deviceCoordinate = devicePos[count]
                    var deviceRotCoordinate = deviceRot[count]
                    var birdMovementType = movementType[count]
                    var faceCoordinate = facePosition[count]
                    var lookAtPoint = lookAt[count]

                    // set position of hummingbird
                    self.setPosition(objectCoordinate: hummingBirdCoordinate, object: hummingBirdObj, incScale: true)
                    
                    // set position of device
                    self.setPosition(objectCoordinate: deviceCoordinate, object: self.hummingBird.device!, incScale: false)
                    
                    // set position of capture sphere
                    self.setPosition(objectCoordinate: captureSphereCoordinate, object: captureSphereObj, incScale: false)
                    
                    // set orientation of device
                    self.setOrientation(point1: deviceCoordinate, point2: captureSphereCoordinate, type_obj: "Device")
            
                    // set scale of all objects in scene
                    self.setScale()
                    
                    // set transparency of bird, device, and capture sphere. Set color of capture sphere
                    self.setMaterials()
                    
            
                    // set orientation of arrow next to bird depending on the birds next coordinate - remove for now
                    //  var nextHummingBirdCoordinate = hummingbirdPos[count + 1]
//                    self.setOrientation(point1: hummingBirdCoordinate, point2: nextHummingBirdCoordinate, type_obj: "Bird")
                 
                    if (slow_counter % 15 == 0) {
                        
                        // create model Entity for line between Bird and capture sphere
                        var bottomLineBird = ModelEntity()
                    
                        // draw line between hummingbird and sphere
                        self.draw2DLine(count: slow_counter, point1: hummingBirdCoordinate, point2: captureSphereCoordinate, type_obj: "Bird", counter: slow_counter, LineEntity: bottomLineBird)
                        
                        // create model Entity for line between device and capture sphere
                        var bottomLineDevice = ModelEntity()
                        
                        // draw line between device and capture sphere
                        self.draw2DLine(count: slow_counter, point1: deviceCoordinate, point2: captureSphereCoordinate, type_obj: "Device", counter: count, LineEntity: bottomLineDevice)
                       
                        // Update length of line on shown on UI
                        self.setLineLength(lineCoordinate1: hummingBirdCoordinate, lineCoordinate2: captureSphereCoordinate)
                        
                        // Calculate and update projection shown on UI
                        self.calculateProjection(hummingBirdCoordinate: hummingBirdCoordinate, captureSphereCoordinate: captureSphereCoordinate, deviceCoordinate: deviceCoordinate, deviceRotCoordinate: deviceRotCoordinate)
                    }

                    // create new sphere to mark trajectory of sphere half as frequent as the lines drawn
                    if (slow_counter % 30 == 0) {
                        
                        // to prevent out of bounds error
                        if (self.countSpheres > 0) {
                            
                            // create model entity for sphere that marks trajectory of capture sphere
                            var sphereModel = ModelEntity()
                            
                            // draw new sphere that marks trajectory of capture sphere using the previous position of capture sphere
                            self.drawSphere(Entity: sphereModel, captureSphereCoordinate: self.prevCapCoord)
                            
                            // set previous capture sphere coordinate
                            self.prevCapCoord = captureSphereCoordinate
                        }
                        
                        self.countSpheres += 1
                    }
               
                    // slow counter used so that replay moves slower so that the user can observe more clearly what is happening in the replay.
                    slow_counter += 1
                    if (slow_counter % 4 == 0) {
                        count += 1
                    }
                    
                    // After you reached end of data gathered, end program
                    if count >= hummingbirdPos.count {
                        t.invalidate()
                    }
                }
            }
        }
    }
    
    // set the scale of all the objects in the replay
    private func setScale() {
        // remove face, arrow of bird, and arrow of face for now
        self.hummingBird.face?.transform.scale *= 0 // used to be 10
        self.hummingBird.arrowFace?.transform.scale *= 0
        self.hummingBird.arrow?.scale *= 0 // 0.3
        
        self.hummingBird.device?.scale *= (2 * reduceSize)
        self.captureSphere.captureSphere?.scale *= 0.2
        self.hummingBird.hummingBird?.scale *= reduceSize
    }
    
    // set the lengthUI for the length of the line between capture sphere and hummingbird. This is displayed in the UI
    private func setLineLength(lineCoordinate1: Dictionary<String, Float>, lineCoordinate2: Dictionary<String, Float>) {
        
        //get distance between hummngbird and sphere
        let distance = self.getDistance(objectCoordinate1: lineCoordinate1, objectCoordinate2: lineCoordinate2)
    
        let trunc = round(100000 * distance) / 100000
        self.lineLengthUI.text = "Length: " + String(trunc)

        self.view.addSubview(self.lineLengthUI)
    }
    
    // Calculate the projection between the device plane and the line between the hummingbird and capture sphere
    // Closer percentage is to 100 % the closer the line is to being parallel to plane
    // Closer percentage is to 0 % the closer the line is to being perpendicular
    private func calculateProjection(hummingBirdCoordinate: Dictionary<String, Float>, captureSphereCoordinate: Dictionary<String, Float>, deviceCoordinate:  Dictionary<String, Float>, deviceRotCoordinate:  Dictionary<String, Float>) {
        
        // find direction vector of line bw bird and catpure sphere
        let xHum = (hummingBirdCoordinate["x"] ?? 0)
        let yHum = (hummingBirdCoordinate["y"] ?? 0)
        let zHum = (hummingBirdCoordinate["z"] ?? 0)
        
        let xCap = (captureSphereCoordinate["x"] ?? 0)
        let yCap = (captureSphereCoordinate["y"] ?? 0)
        let zCap = (captureSphereCoordinate["z"] ?? 0)
    
        let lineVector1 = simd_float3(xCap - xHum,  yCap - yHum, zCap - zHum)
    
        // find direction vector of line bw device and catpure sphere - (use this line as the normal line of the device plane)
        let xDev = (deviceCoordinate["x"] ?? 0)
        let yDev = (deviceCoordinate["y"] ?? 0)
        let zDev = (deviceCoordinate["z"] ?? 0)
    
        let lineVector2 = simd_float3(xCap - xDev, xCap - yDev, zCap - zDev)

        // calculate dot product between normal line of plane and line vector between hummingbird and capture sphere
        let dot = simd_dot(lineVector1, lineVector2)
        
        // calculate magnitudes of both line vectors
        var line1Mag = sqrt(pow(lineVector1[0], 2) + pow(lineVector1[1], 2) + pow(lineVector1[2], 2))
        var line2Mag = sqrt(pow(lineVector2[0], 2) + pow(lineVector2[1], 2) + pow(lineVector2[2], 2))

        // perpendicular - 90
        // parallel - 0
        let angle_rad = acos(dot / (line2Mag * line1Mag))
        let angle_deg = abs(90 - ((angle_rad * 180 ) / .pi))

        // convert to percentage scale with 0 being perp and 100 being parallel
        var perc = Int(100 - ((angle_deg * 100) / 90))
    
        self.projectionUI.text = "Projection: " + String(perc) + "%"
        
        self.view.addSubview(self.projectionUI)
        
    }
    
    private func makeRotationMatrix(rotX: Float, rotY: Float, rotZ: Float) -> simd_float3x3 {
        let rows = [
            simd_float3(cos(rotY) * cos(rotZ), cos(rotX) * sin(rotZ) + sin(rotX) * sin(rotY) * cos(rotZ), sin(rotX) * sin(rotZ) - cos(rotX) * sin(rotY) * cos(rotZ)),
            
            simd_float3(-cos(rotY) * sin(rotZ),
                         cos(rotX) * cos(rotZ) - sin(rotX) * sin(rotY) * sin(rotZ),
                         sin(rotX) * cos(rotZ) + cos(rotX) * sin(rotY) * sin(rotZ)),
            
            simd_float3(sin(rotY), -sin(rotX) * cos(rotY), cos(rotX) * cos(rotY))
        ]
        
        return float3x3(rows: rows)
    }

    private func reduceAllSize() {
 
    }
  
    
    private func setMaterials() {
        
        var material = PhysicallyBasedMaterial()
         
        // set transparency of "screen" of device
        material.blending = .transparent(opacity: .init(floatLiteral: 0.1))
        if let modelEntity = hummingBird.device?.findEntity(named: "Screen") as? ModelEntity {
            modelEntity.model?.materials[0] = material
        
        }
        
        // set transparency of "body" of device
        material.blending = .transparent(opacity: .init(floatLiteral: 0.5))
        if let modelEntity = hummingBird.device?.findEntity(named: "Body") as? ModelEntity {
            modelEntity.model?.materials[0] = material
        
        }
        
        // set transparency of bird
        material.blending = .transparent(opacity: .init(floatLiteral: 0.8))
        if let modelEntity = hummingBird.hummingBird?.findEntity(named: "Cube_001_Cube_002") as? ModelEntity{
            modelEntity.model?.materials[0] = material
        
        }
        
        // set color and transparency of capture sphere
        material.baseColor = .init(tint: .gray)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.8))
        if let modelEntity = captureSphere.captureSphere?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = material

        }
    }
    
    private func drawSphere(Entity: ModelEntity, captureSphereCoordinate: Dictionary<String, Float>) {
        
        let anchor = AnchorEntity()
        let opacity_val = 0.65
        
        listSpheres.append(Entity)
        listSphereAnchors.append(anchor)
        listSphereTransparencies.append(opacity_val)
        listSphereTimes.append(0)
        
        // set position of new sphere
        let position = SIMD3<Float>(x: (captureSphereCoordinate["x"] ?? 0) / devideAmount,
                                    y: (captureSphereCoordinate["y"] ?? 0) / devideAmount,
                                    z: (captureSphereCoordinate["z"] ?? 0) / devideAmount)
        
        anchor.position = position
        
        // set color & transparency
        transparency_material_sphere.baseColor = .init(tint: .gray)
        transparency_material_sphere.blending = .transparent(opacity: .init(floatLiteral: Float(opacity_val)))
        
        // update opacity of all the spheres
        self.setTransparencySphere()
        
        // create mesh
        var sphereMesh = MeshResource.generateSphere(radius: 0.0067) // might need to change radius value
        
        // update model with mesh
        Entity.model = .init(mesh: sphereMesh, materials: [transparency_material_sphere])

        anchor.addChild(Entity)
        arView.scene.addAnchor(anchor)
        
        var i = 0
        for time_val in listSphereTimes {
            listSphereTimes[i] += 1
            
            i += 1
        }
        
    }
    
    private func setTransparencySphere() {
        
        var j = 0
        // go through entire list and decrease transparency, delete if transparency is zero
        for transparency_val in listSphereTransparencies {
            
            listSphereTransparencies[j] -= 0.15
            
            if (transparency_val <= 0.0) {
        
                // delete that line
                let firstAnchor = listSphereAnchors[0]
                let firstLine = listSpheres[0]
                
                firstAnchor.removeChild(firstLine)
                
                listSpheres.remove(at: 0)
                listSphereAnchors.remove(at: 0)
                listSphereTransparencies.remove(at: 0)
                listSphereTimes.remove(at: 0)
                break
                
            }
            
            j += 1
        }
        
        var i = 0
        for sphere in listSpheres {
            
            var transparencyMat = PhysicallyBasedMaterial()
            let transparency_val = listSphereTransparencies[i]
        
            // set color and transparency
            transparencyMat.baseColor = .init(tint: .gray)
            transparencyMat.blending = .transparent(opacity: .init(floatLiteral: Float(transparency_val)))
            
            // update the material of the line
            sphere.model?.materials = [transparencyMat]
            
            i += 1
        }
        
        // now iterate through bird times list and see if any are greater than 3. If they are remove those lines
        
        var k = 0
        for time in listSphereTimes {

            if (listSphereTimes[k] >= 5) {

                // delete that line
                let firstAnchor = listSphereAnchors[k]
                let firstLine = listSpheres[k]

                firstAnchor.removeChild(firstLine)

                listSpheres.remove(at: k)
                listSphereAnchors.remove(at: k)
                listSphereTransparencies.remove(at: k)
                listSphereTimes.remove(at: k)
                break
            }

            k += 1

        }
        
    }
    
    private func draw2DLine(count: Int, point1: Dictionary<String, Float>, point2: Dictionary<String, Float>, type_obj: String, counter: Int, LineEntity: ModelEntity) {
        
        if listDeviceAnchors.count > 0{
            
            // remove prev line bewtween device and sphere
            let firstAnchor = listDeviceAnchors.last
            let firstLine = listDeviceLines.last
           
            firstAnchor?.removeChild(firstLine!)
           
            listDeviceLines.remove(at: listDeviceAnchors.count - 1)
            listDeviceAnchors.remove(at: listDeviceAnchors.count - 1)
        
        }
    
    
        let anchor = AnchorEntity()
        let line_opacity_value = 1.0
        
        // append onto list
        
        if (type_obj == "Device") {
            listDeviceLines.append(LineEntity)
            listDeviceAnchors.append(anchor)
            listDeviceTransparencies.append(line_opacity_value)
        
        }
        else if (type_obj == "Bird") {
            listBirdLines.append(LineEntity)
            listBirdAnchors.append(anchor)
            listBirdTransparencies.append(line_opacity_value)
            listBirdTimes.append(0)
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

        if (type_obj == "Device") {
            transparency_material_line.baseColor = .init(tint: .blue)
            transparency_material_line.blending = .transparent(opacity: .init(floatLiteral: Float(0.5)))
        }

        else if (type_obj == "Bird") {
            transparency_material_line.baseColor = .init(tint: .red)
            transparency_material_line.blending = .transparent(opacity: .init(floatLiteral: Float(line_opacity_value)))
        }
        
        // update opacity of all the lines
        self.setTransparencyLine(count: count, type_obj: type_obj)
        
        // create mesh
        let depth_size = simd_distance(position1, position2)
        
        var bottomLineMesh = MeshResource.generateBox(size: Float(0.0))
        if (type_obj == "Bird") {
            bottomLineMesh = MeshResource.generateBox(width: Float(line_width),
                                                          height: Float(line_width),
                                                          depth: depth_size)
        }
        
        else if (type_obj == "Device") {
            
            bottomLineMesh = MeshResource.generateBox(width: Float(line_width * 2),
                                                          height: Float(line_width * 2),
                                                          depth: depth_size)
        }

      
        //update model with mesh
        LineEntity.model = .init(mesh: bottomLineMesh, materials: [transparency_material_line])
        
        anchor.addChild(LineEntity)
        arView.scene.addAnchor(anchor)
        
        if (type_obj == "Bird") {
            // go through list of times and add one to each
            var i = 0
            for time_val in listBirdTimes {
                listBirdTimes[i] += 1
                
                i += 1
            }
        }

    }

    // i am adding a line evety second, and only keeping the lines from the past 3 seconds, so I only end up with 3 lines
    private func setTransparencyLine(count: Int, type_obj: String) {
        

        if (type_obj == "Bird") {
            var j = 0
            // go through entire list and decrease transparency, delete if transparency is zero
            for transparency_val in listBirdTransparencies {
                // transparency_val -= 0.1 // error - not mutating the value
                
                listBirdTransparencies[j] -= 0.15// 0.35
                
                if (transparency_val <= 0.0) {
            
                    // delete that line
                    let firstAnchor = listBirdAnchors[0]
                    let firstLine = listBirdLines[0]
                    
                    firstAnchor.removeChild(firstLine)
                    
                    listBirdLines.remove(at: 0)
                    listBirdAnchors.remove(at: 0)
                    listBirdTransparencies.remove(at: 0)
                    listBirdTimes.remove(at: 0)
                    break
                    
                }
                
                j += 1
            }
            
            var i = 0
            for line in listBirdLines {
                
                var transparencyMat = PhysicallyBasedMaterial()
                let transparency_val = listBirdTransparencies[i]
            
                // set color and transparency
                transparencyMat.baseColor = .init(tint: .red)
                transparencyMat.blending = .transparent(opacity: .init(floatLiteral: Float(transparency_val)))
                
                // update the material of the line
                line.model?.materials = [transparencyMat]
                
                i += 1
            }
            
            // now iterate through bird times list and see if any are greater than 3. If they are remove those lines
            
            var k = 0
            for time in listBirdTimes {

                if (listBirdTimes[k] >= 5) {

                    // delete that line
                    let firstAnchor = listBirdAnchors[k]
                    let firstLine = listBirdLines[k]

                    firstAnchor.removeChild(firstLine)

                    listBirdLines.remove(at: k)
                    listBirdAnchors.remove(at: k)
                    listBirdTransparencies.remove(at: k)
                    listBirdTimes.remove(at: k)
                    break
                }

                k += 1

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
        }
        
        // set orientation of arrow, indicating direction of bird. Remove for now.
//        else if (type_obj == "Bird") {
//            self.hummingBird.arrow?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
//        }
        
        else if (type_obj == "Device") {
            self.hummingBird.device?.orientation = simd_quatf(angle: -yaw + (.pi / 2), axis: [0,1,0])
        }
        
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
    
    private func getDistance(objectCoordinate1: Dictionary<String, Float>, objectCoordinate2: Dictionary<String, Float>) -> Float{
        
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

        if (incScale) {
            // multiple the scale of the hummingbird by 50 since the model being used is very small
            objectTransform.scale *= 50
            
        }
        
        object.move(to: objectTransform, relativeTo: nil)

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

