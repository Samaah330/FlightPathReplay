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
    
    var boxAnchor: Experience.Box!
    
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
        boxAnchor = try! Experience.loadBox()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(boxAnchor!)
        
        jsonData = loadJson(fileName: "data")!
    }
    
    @IBAction func start(_ sender: Any) {
        print("Button Pressed!")
        
        var count = 0
        let hummingbirdPos = jsonData.hummingbirdPos
        if let obj = self.boxAnchor!.steelBox {
            var timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true){ t in
                var coordinate = hummingbirdPos[count]
                if coordinate["x"] != nil && coordinate["y"] != nil && coordinate["z"] != nil {
                    let translation = SIMD3<Float>(x: coordinate["x"]!, y: coordinate["y"]!, z: coordinate["z"]!)
                    let transform = Transform(scale: .one, rotation: simd_quatf(), translation: translation)
                    obj.move(to: transform, relativeTo: nil)
                }
                
                count += 1
                if count >= hummingbirdPos.count {
                    t.invalidate()
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
