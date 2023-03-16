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

class ViewController: UIViewController , ARSessionDelegate, UITextViewDelegate, ARCoachingOverlayViewDelegate {
    
    @IBOutlet var arView: ARView!
    
    var counter = 0
    
    var touchLocation: CGPoint!

    var hummingBird: HummingBird._HummingBird!
    var captureSphere: CaptureSphere._CaptureSphere!
    
    var touchedSphere = false
    
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
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot1!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot2!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot3!)
        self.setTransparency(TransparencyVal: 0, DotNum: captureSphere.dot4!)
        
        // increase the size of the hummingbird in the beginning
        hummingBird.transform.scale *= 50
        
        jsonData = loadJson(fileName: "data")!
        
        // If the user taps the screen, the function "myviewTapped" is called
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(ViewController.myviewTapped))
        arView.addGestureRecognizer(tapGesture)
        arView.session.delegate = self
             
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
        
        if let hummingBirdObj = self.hummingBird!.hummingBird {
            if let captureSphereObj = self.captureSphere!.captureSphere {
                
                // change timer back to 1/60 later
                var timer = Timer.scheduledTimer(withTimeInterval: 1/500, repeats: true){ t in
                    
                    // get position of hummingbird and capture sphere
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    var captureSphereCoordinate = captureSpherePos[count]
                    
                    // previous coordinates
                    var prev1HummingBirdCoordinate = hummingBirdCoordinate
                    var prev1CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev2HummingBirdCoordinate = hummingBirdCoordinate
                    var prev2CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev3HummingBirdCoordinate = hummingBirdCoordinate
                    var prev3CaptureSphereCoordinate = captureSphereCoordinate
                    
                    var prev4HummingBirdCoordinate = hummingBirdCoordinate
                    var prev4CaptureSphereCoordinate = captureSphereCoordinate
                    
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
                
                    // set position of hummingbird
                    self.setPosition(objectCoordinate: hummingBirdCoordinate, object: hummingBirdObj, incScale: true)
                        
                    // set position of capture sphere
                    self.setPosition(objectCoordinate: captureSphereCoordinate, object: captureSphereObj, incScale: false)
                    
                    // intialize trailing dots behind capture sphere
                    let dot1 = self.captureSphere.dot1
                    let dot2 = self.captureSphere.dot2
                    let dot3 = self.captureSphere.dot3
                    let dot4 = self.captureSphere.dot4
                    
                    // set the position of these trailing dots
                    self.setPosition(objectCoordinate: prev1CaptureSphereCoordinate, object: dot1!, incScale: false)
                    self.setPosition(objectCoordinate: prev2CaptureSphereCoordinate, object: dot2!, incScale: false)
                    self.setPosition(objectCoordinate: prev3CaptureSphereCoordinate, object: dot3!, incScale: false)
                    self.setPosition(objectCoordinate: prev4CaptureSphereCoordinate, object: dot4!, incScale: false)
                    
                    // set the transparency of these trailing dots
                    self.setTransparency(TransparencyVal: 0.8, DotNum: dot1!)
                    self.setTransparency(TransparencyVal: 0.6, DotNum: dot2!)
                    self.setTransparency(TransparencyVal: 0.4, DotNum: dot3!)
                    self.setTransparency(TransparencyVal: 0.2, DotNum: dot4!)
                                   
                    // this calls the function that is triggered when you tap on the capture sphere object
                    self.captureSphere.actions.colorChange.onAction = self.handleTapOnEntity(_:)
    
                    // increase scale of trailing dots
                    self.multScaleBy2(object1: dot1!, object2: dot2!, object3: dot3!, object4: dot4!)
                    
                    slow_counter += 1
                    
                    // so that it moves slower, just for right now
                    if (slow_counter % 3 == 0) {
                        count += 1
                    }
                    
                    if count >= hummingbirdPos.count {
                        t.invalidate()
                    }
                }
            }
        }
    }
    
    // function that is called when you tap on the capture sphere
    func handleTapOnEntity(_ entity: Entity?) {
        guard let entity = entity else { return }
        
        touchedSphere = true
        
        setColor(DotNum: self.captureSphere.captureSphere!)
        
        
    }
    
    private func multScaleBy2(object1: Entity, object2: Entity, object3: Entity, object4: Entity) {
        
        object1.transform.scale *= 2.0
        object2.transform.scale *= 2.0
        object3.transform.scale *= 2.0
        object4.transform.scale *= 2.0
        
        
    }
    
    private func setPosition(objectCoordinate: Dictionary<String, Float> , object: Entity, incScale: Bool) {

        let posx = (objectCoordinate["x"] ?? 0)
        let posy = (objectCoordinate["y"] ?? 0)
        let posz = (objectCoordinate["z"] ?? 0)

        let objectTranslation = SIMD3<Float>(x: posx, y: posy, z: posz)
        var objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)

        if (incScale) {
            
            // multiple the scale of the hummingbird by 50 since the model being used is very small
            objectTransform.scale *= 50
            
        }
        
        object.move(to: objectTransform, relativeTo: nil)

    }
    
    private func setColor(DotNum: Entity) {
        
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        color_material.baseColor = .init(tint: .blue)
        
        if let modelEntity = DotNum.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
        
//        if let modelEntity = self.captureSphere.dot1!.findEntity(named: "simpBld_root") as? ModelEntity {
//
//            modelEntity.model?.materials[0] = color_material
//        }
//
//        if let modelEntity = self.captureSphere.dot2!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = color_material
//        }
//
//        if let modelEntity = self.captureSphere.dot3!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = color_material
//        }
//
//        if let modelEntity = self.captureSphere.dot4!.findEntity(named: "simpBld_root") as? ModelEntity {
//            modelEntity.model?.materials[0] = color_material
//        }
        
        
    }

    private func setTransparency(TransparencyVal: Float, DotNum: Entity) {
        
        var transparent_material = PhysicallyBasedMaterial()
        transparent_material.blending = .transparent(opacity: .init(floatLiteral: TransparencyVal))
        
//        if (touchedSphere == true) {
//            transparent_material.baseColor = .init(tint: .blue)
//        }
        
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

