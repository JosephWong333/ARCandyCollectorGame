import UIKit
import RealityKit
import ARKit

class ViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet var arView: ARView!
    var roboAnchor: RoboExperience.Animoji!
    var allowsTalking = true
    
    var eyeL: Entity!
    var eyeR: Entity!
    
    var candies: [Entity] = []
    var candyTimer: Timer?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
            
        // Face Tracking from ARKIT
        let config = ARFaceTrackingConfiguration()
        arView.session.run(config)
        arView.session.delegate = self
        
        // Load the "Animoji" scene from the "Experience" Reality File
        roboAnchor = try! RoboExperience.loadAnimoji()
        
        // Add the animoji anchor to the scene
        arView.scene.anchors.append(roboAnchor)
        
        // Models
        eyeL = roboAnchor.findEntity(named: "eyeL")
        eyeR = roboAnchor.findEntity(named: "eyeR")
        
        // closure, "_" is affected object. in this case, we don't have any
//        roboAnchor.actions.endTalk.onAction = { _ in
//            self.allowsTalking = true
//        }

        // Start dropping candies
        startCandyDropping()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        candyTimer?.invalidate() // Stop timer when the view is no longer visible
    }
    
    func startCandyDropping() {
        // Drop a candy every 5 seconds
        candyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.dropCandy()
        }
    }
    
    func createCandyEntity() -> ModelEntity? {
        if Bool.random() {
            guard let model = try? Entity.loadModel(named: "Lolipop") else {
                return nil
            }
            model.generateCollisionShapes(recursive: true) // This helps with collision detection
            return model
        } else {
            guard let model = try? Entity.loadModel(named: "Candy_Corn") else {
                return nil
            }
            model.generateCollisionShapes(recursive: true) // This helps with collision detection
            return model
        }
    }
    
    func dropCandy() {
            guard let candy = createCandyEntity() else { return }

            // Get the position of the roboAnchor directly
            let anchorPosition = roboAnchor.position(relativeTo: nil)
        
        let randomOffset = Float.random(in: -0.74...0.74)
            // Took me so long to find this out after much experimenting: using position and realtive to nil, it means worldtransform!
        
        candy.position = SIMD3<Float>(anchorPosition.x + randomOffset, anchorPosition.y + 2.7, anchorPosition.z)
//            candy.position = SIMD3<Float>(eyeLWorldPosition.x, eyeLWorldPosition.y + 1, eyeLWorldPosition.z)

        candy.scale = SIMD3<Float>(0.16, 0.16, 0.16)

            // Define the collision filter
            let collisionFilter = CollisionFilter(group: .default, mask: .all)

            // Add physics for the falling effect
            let physicsBody = PhysicsBodyComponent(massProperties: .default, material: nil, mode: .dynamic)
            candy.components.set(physicsBody)
        
            // Set up collision component
            let collisionComponent = CollisionComponent(shapes: [.generateBox(size: [0.2, 0.2, 0.2])], mode: .trigger, filter: collisionFilter)
            candy.components.set(collisionComponent)

            // Create an anchor to the world origin
            let candyAnchor = AnchorEntity(world: .zero)
            candyAnchor.addChild(candy)

            // Add to scene
            candies.append(candy)
            arView.scene.addAnchor(candyAnchor)

    }
    
    // Updated session function
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        var faceAnchor: ARFaceAnchor?
        
        // loop through all the anchors to find a faceanchor
        for a in anchors {
            if let anchor = a as? ARFaceAnchor {
                faceAnchor = anchor
            }
        }
        
        guard let blendShapes = faceAnchor?.blendShapes,
              let eyeLValue = blendShapes[.eyeBlinkLeft]?.floatValue,
              let eyeRValue = blendShapes[.eyeBlinkRight]?.floatValue else { return }

        eyeL.scale.x = 1.0 - eyeLValue
        eyeR.scale.x = 1.0 - eyeRValue
        
        // Check collisions between candies and face anchor
        checkCandyCollisions()
    }

    func checkCandyCollisions() {
        let facePosition = roboAnchor.position(relativeTo: nil)
        candies.forEach { candy in
            if length(candy.position - facePosition) < 0.365 { // Collision threshold
                
                roboAnchor.notifications.talk.post() //notify scene we want to talk
                candy.removeFromParent()
                candies.removeAll { $0 == candy }
            }
        }
    }
}
