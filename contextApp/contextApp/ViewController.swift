//
//  ViewController.swift
//  contextApp
//
//  Created by Dan Lages on 15/07/2019.
//  Copyright © 2019 Dan Lages. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import SpriteKit
import Vision
import CoreLocation //Core Location module, for the activation of functionality if user is with the pre-established scene
import SwiftSoup //Swift Soup pod imported for webscraping

// Extemtion of the SCNNode pattern, adjusting the placement of the node in relation to the scanned object
extension SCNNode {
    var width: Float {
        return (boundingBox.max.x - boundingBox.min.x) + scale.x
    }
    var height: Float {
        return (boundingBox.max.y - boundingBox.min.y) + scale.y
    }
    
    func angleFromLeftPos() {
        let (min,max) = boundingBox
        pivot = SCNMatrix4MakeTranslation(min.x, (max.y - min.y) + min.y, 0)
    }
    
    func angleFromTopPos() {
        let (min, max) = boundingBox
        pivot = SCNMatrix4MakeTranslation((max.x - min.x) / 2 + min.x, (min.y - min.y) + min.y, 0)
        
    }
}

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
//    var infoPoints = [String: InfoPoints]() // Decleare string of sign information to be diplayed when corrispondoing sign is shown
    
    //Signinfo to be declared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let overlayScene = SKScene()
        overlayScene.scaleMode = .aspectFit
        sceneView.delegate = self

        sceneView.session.delegate = self as ARSessionDelegate
    
        
        // Set the view's delegate
        sceneView.delegate = self
    
        //sceneView.showsStatistics = true // Show statistics such as fps and timing information
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        //sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARImageTrackingConfiguration() // Image Tracking configuration used for the analysis of information points
        
        guard let informationPoints = ARReferenceImage.referenceImages(inGroupNamed: "InformationPoints", bundle: nil) else {
            fatalError("Unable to find reference images")
        } //Specify location of information point images as reference for scanned images
        
        configuration.trackingImages = informationPoints

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    
    func calculateData() {
        //Function to determine which data to map to information point interface
    }
    
    //Renderer serving to latch software elemebts to recongnised information points
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let interfacePostion = anchor as? ARImageAnchor else {
            fatalError("Unable to find anchor point for software overlay")
        }
        
        let positionBoarder: Float = 0.1
        
        let pointName = interfacePostion.referenceImage.name
        print(pointName!)
        let pointDescription = "Your train leaves in 10 mins"
        
        let overlay = SCNPlane(width: interfacePostion.referenceImage.physicalSize.width, height: interfacePostion.referenceImage.physicalSize.height)
        
        overlay.firstMaterial?.diffuse.contents = UIColor.clear //UIImage(named: "Proceed")
        let overlayNode = SCNNode(geometry: overlay)
        
        let node  = SCNNode()
        overlayNode.eulerAngles.x = -.pi / 2
        node.addChildNode(overlayNode)

        
        let headingNode = infoNode(pointName!, font: UIFont.boldSystemFont(ofSize: 200))
        headingNode.angleFromLeftPos()
        headingNode.position.x += Float(overlay.width / 2) + positionBoarder
        headingNode.position.y += Float(overlay.height / 2)
        overlayNode.addChildNode(headingNode)
        
        let bioNode = infoNode(pointDescription, width: 1000, font: UIFont.systemFont(ofSize: 100))
        bioNode.angleFromLeftPos()
        bioNode.position.x += Float(overlay.width / 2) + positionBoarder
        bioNode.position.y = Float(headingNode.position.y / 2) - positionBoarder
        overlayNode.addChildNode(bioNode)
        
        let alertNode = SCNPlane(width: interfacePostion.referenceImage.physicalSize.height, height: interfacePostion.referenceImage.physicalSize.width / 8 * 5)
        alertNode.firstMaterial?.diffuse.contents = UIImage(named: "ProceedSq")
        
        let imageNode = SCNNode(geometry: alertNode)
        imageNode.position.x -= Float(overlay.width)
        imageNode.position.y = Float(bioNode.position.y / 2) - positionBoarder
        overlayNode.addChildNode(imageNode)
        
        
        return node//Output Interface
    
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // Pass camera frames received from ARKit to Vision (when not already processing one)
    /// - Tag: ConsumeARFrames
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Do not enqueue other buffers for processing while another Vision task is still running.
        // The camera stream has only a finite amount of buffers available; holding too many buffers for analysis would starve the camera.
        // Retain the image buffer for Vision processing.
    
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func infoNode(_ str: String, width: Int? = nil, font: UIFont) -> SCNNode {
        let text = SCNText(string: str, extrusionDepth: 0)
        text.flatness = 0.5
        text.font = font
        
        if let maxWidth = width {
            text.containerFrame = CGRect(origin: .zero , size: CGSize(width: maxWidth, height: 500))
            text.isWrapped = true
        }
        
        let infoNode = SCNNode(geometry: text)
        infoNode.scale = SCNVector3(0.01, 0.01, 0.01)
        
        return infoNode
    }
    
//    func alertNode(_ image: UIImage, width: Int? = nil) -> SCNNode {
//
//        let alert =
//
//        let alertNode = SCNNode(geometry: UIImage)
//        alertNode.scale = SCNVector3(0.02, 0.02, 0.02)
//
//        return alertNode
//    }
    
    
}
