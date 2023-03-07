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
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    if hummingBirdCoordinate["x"] != nil && hummingBirdCoordinate["y"] != nil && hummingBirdCoordinate["z"] != nil {
                        let hummingBirdTranslation = SIMD3<Float>(x: hummingBirdCoordinate["x"]!, y: hummingBirdCoordinate["y"]!, z: hummingBirdCoordinate["z"]!)
                        var hummingBirdTransform = Transform(scale: .one, rotation: simd_quatf(), translation: hummingBirdTranslation)
                        
                        // multiple the scale of the hummingbird by 50 since the model being used is very small
                        hummingBirdTransform.scale *= 50
                        hummingBirdObj.move(to: hummingBirdTransform, relativeTo: nil)
                    }
                    
                    var captureSphereCoordinate = captureSpherePos[count]
                    
                    // set position of capture sphere
                    self.setPosition(captureSphereCoordinate: captureSphereCoordinate, object: captureSphereObj,  coordinatesBehind: 0.0)
                    
                    // intialize trailing dot1 behind capture sphere
                    let dot1 = self.captureSphere.dot1
                    let dot2 = self.captureSphere.dot2
                    let dot3 = self.captureSphere.dot3
                    let dot4 = self.captureSphere.dot4
                    
                    // set the position of these trailing dots
                    self.setPosition(captureSphereCoordinate: captureSphereCoordinate, object: dot1!,  coordinatesBehind: 0.02)
                    self.setPosition(captureSphereCoordinate: captureSphereCoordinate, object: dot2!,  coordinatesBehind: 0.03)
                    self.setPosition(captureSphereCoordinate: captureSphereCoordinate, object: dot3!,  coordinatesBehind: 0.04)
                    self.setPosition(captureSphereCoordinate: captureSphereCoordinate, object: dot4!,  coordinatesBehind: 0.05)
                    
                    // set the transparency of these trailing dots
                    self.setTransparency(TransparencyVal: 0.8, DotNum: dot1!)
                    self.setTransparency(TransparencyVal: 0.65, DotNum: dot2!)
                    self.setTransparency(TransparencyVal: 0.5, DotNum: dot3!)
                    self.setTransparency(TransparencyVal: 0.35, DotNum: dot4!)
                                   
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
        
        setColor()
    }
    
    private func multScaleBy2(object1: Entity, object2: Entity, object3: Entity, object4: Entity) {
        
        object1.transform.scale *= 2.0
        object2.transform.scale *= 2.0
        object3.transform.scale *= 2.0
        object4.transform.scale *= 2.0
        
        
    }
    
    private func setPosition(captureSphereCoordinate: Dictionary<String, Float> , object: Entity, coordinatesBehind: Float) {

        let posx = (captureSphereCoordinate["x"] ?? 0) - coordinatesBehind
        let posy = (captureSphereCoordinate["y"] ?? 0) - coordinatesBehind
        let posz = (captureSphereCoordinate["z"] ?? 0) - coordinatesBehind

        let objectTranslation = SIMD3<Float>(x: posx, y: posy, z: posz)
        var objectTransform = Transform(scale: .one, rotation: simd_quatf(), translation: objectTranslation)

        object.move(to: objectTransform, relativeTo: nil)

    }
    
    private func setColor() {
        
        var color_material = PhysicallyBasedMaterial()
        
        // how you change the color of an object
        color_material.baseColor = .init(tint: .blue)
        
        if let modelEntity = self.captureSphere.captureSphere?.findEntity(named: "simpBld_root") as? ModelEntity {
            modelEntity.model?.materials[0] = color_material
        }
        
    
//        if touchObject == captureSphereGround {
//            print("color change")
//        }
        
    }

    private func setTransparency(TransparencyVal: Float, DotNum: Entity) {
        
        var transparent_material = PhysicallyBasedMaterial()
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

