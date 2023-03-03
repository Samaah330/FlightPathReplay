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
       let touchLocation = _sender.location(in: arView)

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
        var count = 0
        let hummingbirdPos = jsonData.hummingbirdPos
        let captureSpherePos = jsonData.spherePos
        
        if let hummingBirdObj = self.hummingBird!.hummingBird {
            if let captureSphereObj = self.captureSphere!.captureSphere {
                var timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true){ t in
                    var hummingBirdCoordinate = hummingbirdPos[count]
                    if hummingBirdCoordinate["x"] != nil && hummingBirdCoordinate["y"] != nil && hummingBirdCoordinate["z"] != nil {
                        let hummingBirdTranslation = SIMD3<Float>(x: hummingBirdCoordinate["x"]!, y: hummingBirdCoordinate["y"]!, z: hummingBirdCoordinate["z"]!)
                        let hummingBirdTransform = Transform(scale: .one, rotation: simd_quatf(), translation: hummingBirdTranslation)
                        hummingBirdObj.move(to: hummingBirdTransform, relativeTo: nil)
                    }
                    
                    var captureSphereCoordinate = captureSpherePos[count]
                    if captureSphereCoordinate["x"] != nil && captureSphereCoordinate["y"] != nil && captureSphereCoordinate["z"] != nil {
                        let captureSphereTranslation = SIMD3<Float>(x: captureSphereCoordinate["x"]!, y: captureSphereCoordinate["y"]!, z: captureSphereCoordinate["z"]!)
                        let captureSphereTransform = Transform(scale: .one, rotation: simd_quatf(), translation: captureSphereTranslation)
                        captureSphereObj.move(to: captureSphereTransform, relativeTo: nil)
                    }
                    
                    // trailing dot1 behind capture sphere
                    let dot1 = self.captureSphere.dot1
                    
                    // position
                    let dot1x = (captureSphereCoordinate["x"] ?? 0) - 0.03
                    let dot1y = (captureSphereCoordinate["y"] ?? 0) - 0.03
                    let dot1z = (captureSphereCoordinate["z"] ?? 0) - 0.03
                    
                    let dot1Translation = SIMD3<Float>(x: dot1x, y: dot1y, z: dot1z)
                    var dot1Transform = Transform(scale: .one, rotation: simd_quatf(), translation: dot1Translation)
                    
                    dot1?.move(to: dot1Transform, relativeTo: nil)
                    
                    // create material w/ transparency of 0.5
                    var transparent_material = PhysicallyBasedMaterial()
                    transparent_material.blending = .transparent(opacity: .init(floatLiteral: 0.7))
                    
                    // set this material to the first dot - in order to find the name of the dot do
                    // let mat = self.captureSphere.findEntity(named: "Dot1") ; print(mat)
                    if let mat1 = self.captureSphere.findEntity(named: "simpBld_root")
                                                                          as? ModelEntity {

                        mat1.model?.materials[0] = transparent_material

                    }
              
                    
                    // trailing dot2 behind capture sphere
                    let dot2 = self.captureSphere.dot2
                    
                    let dot2x = (captureSphereCoordinate["x"] ?? 0) - 0.05
                    let dot2y = (captureSphereCoordinate["y"] ?? 0) - 0.05
                    let dot2z = (captureSphereCoordinate["z"] ?? 0) - 0.05
                    
                    let dot2Translation = SIMD3<Float>(x: dot2x, y: dot2y, z: dot2z)
                    var dot2Transform = Transform(scale: .one, rotation: simd_quatf(), translation: dot2Translation)
                
                    dot2?.move(to: dot2Transform, relativeTo: nil)
                    
                    
                    // create material w/ transparency of 0.5
                    var transparent_material2 = PhysicallyBasedMaterial()
                    transparent_material2.blending = .transparent(opacity: .init(floatLiteral: 0.5))
                    
//                    simpBld_root
                    if let mat2 = self.captureSphere.dot2?.findEntity(named: "simpBld_root") as? ModelEntity {
                        mat2.model?.materials[0] = transparent_material2
                    }
                    
                    // trailing dot3 behind capture sphere
                    let dot3 = self.captureSphere.dot3
                    
                    let dot3x = (captureSphereCoordinate["x"] ?? 0) - 0.07
                    let dot3y = (captureSphereCoordinate["y"] ?? 0) - 0.07
                    let dot3z = (captureSphereCoordinate["z"] ?? 0) - 0.07
                    
                    let dot3Translation = SIMD3<Float>(x: dot3x, y: dot3y, z: dot3z)
                    var dot3Transform = Transform(scale: .one, rotation: simd_quatf(), translation: dot3Translation)

                    dot3?.move(to: dot3Transform, relativeTo: nil)
                    
                    // create material w/ transparency of 0.5
                    var transparent_material3 = PhysicallyBasedMaterial()
                    transparent_material3.blending = .transparent(opacity: .init(floatLiteral: 0.5))
                    
                    if let mat3 = self.captureSphere.dot3?.findEntity(named: "simpBld_root") as? ModelEntity {
                        mat3.model?.materials[0] = transparent_material3
                    }
                    
                    // trailing dot4 behind capture sphere
                    let dot4 = self.captureSphere.dot4
                    
                    let dot4x = (captureSphereCoordinate["x"] ?? 0) - 0.08
                    let dot4y = (captureSphereCoordinate["y"] ?? 0) - 0.08
                    let dot4z = (captureSphereCoordinate["z"] ?? 0) - 0.08
                    
                    let dot4Translation = SIMD3<Float>(x: dot4x, y: dot4y, z: dot4z)
                    var dot4Transform = Transform(scale: .one, rotation: simd_quatf(), translation: dot4Translation)
                    
                    dot4?.move(to: dot4Transform, relativeTo: nil)
                    
                    var transparent_material4 = PhysicallyBasedMaterial()
                    transparent_material4.blending = .transparent(opacity: .init(floatLiteral: 0.5))
                    
                    if let mat4 = self.captureSphere.dot4?.findEntity(named: "simpBld_root") as? ModelEntity {
                        mat4.model?.materials[0] = transparent_material4
                    }
                    
                    count += 1
                    if count >= hummingbirdPos.count {
                        t.invalidate()
                    }
                }
            }
        }
    }
    
    
    func semiTransparentShader(_ value: Float) -> Material {

        var material = PhysicallyBasedMaterial()
        material.baseColor.texture = try! .init(.load(named: "image", in: nil))
        material.blending = .transparent(opacity: .init(floatLiteral: value))

        return material
    }
    
//    private func shouldDeceaseScaleZero(startingVal : Int) -> Bool {
//
//
//        let num_times = 10
//        for i in 0 ... num_times {
//
//            if self.counter % (startingVal + i) == 0 {
//                return true
//            }
//        }
//
//        return false
//    }
//
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

