//
//  ViewController.swift
//  FlightPath
//
//  Created by Jaewook Lee on 9/30/22.
//

import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    var hummingBird: HummingBird._HummingBird!
    var captureSphere: CaptureSphere._CaptureSphere!
    
    var jsonData: GameData!
    
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
        
        // Load the "Box" scene from the "Experience" Reality File
        hummingBird = try! HummingBird.load_HummingBird()
        captureSphere = try! CaptureSphere.load_CaptureSphere()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(hummingBird!)
        arView.scene.anchors.append(captureSphere!)
        
        jsonData = loadJson(fileName: "data")!
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
                    
                    count += 1
                    if count >= hummingbirdPos.count {
                        t.invalidate()
                    }
                }
            }
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
}
