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
import CoreData
import FirebaseFirestore
import Foundation //Allowing for the use of external clases
import CoreLocation //Core Location module, for the activation of functionality if user is with the pre-established scene
import SwiftSoup //Swift Soup pod imported for webscraping
import SwiftyTesseract //SwiftyTesseract Pod imported for OCR
import SQLite3 //SQLite imported for database implementation
import VideoToolbox

class Event {
    var location: String?
    var desitnation: String?
    var platform: String?
    var time: String?
    
    init(location: String?, destination: String?, platform: String?, time: String){
        self.location = location
        self.desitnation = destination
        self.platform = platform
        self.time = time
        
    }
}

struct event {
    static var location: String = ""
    static var destination: String = ""
    static var platform: String = ""
    static var time: String = ""
}

extension UIImage {  //Extention for UI image used from https://stackoverflow.com/questions/8072208/how-to-turn-a-cvpixelbuffer-into-a-uiimage - Allowing conversion of current frame to UI image
    
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, CLLocationManagerDelegate {

    
    //Test Station Variables
    let startPoint: String = "penarth"
    let endPoint: String = "cardiff-queen-street"
    let locationPermit = CLLocationManager()
    let swiftyTesseract = SwiftyTesseract(language: .english) //Definition of Swifty Tesseract training Languge
    var eventList = [Event]()
    
    @IBOutlet var sceneView: ARSCNView!
    
    
    
    
    
//    var infoPoints = [String: InfoPoints]() // Decleare string of sign information to be diplayed when corrispondoing sign is shown
    
    //Signinfo to be declared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
       
        let overlayScene = SKScene()
        overlayScene.scaleMode = .aspectFit
        sceneView.delegate = self
        sceneView.session.delegate = self as ARSessionDelegate
        sceneView.delegate = self // Set the view's delegate
        
        //MARK: Location Initialisation
        
        locationPermit.delegate = self as CLLocationManagerDelegate
        locationPermit.desiredAccuracy = kCLLocationAccuracyBest
        locationPermit.requestAlwaysAuthorization() //Request Allways On location for effective computation
        locationPermit.startUpdatingLocation()
        
        
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
    
    //Calculate
    
    func gatherValues() {
        let eventDatabase = Firestore.firestore()
        eventDatabase.collection("Event").getDocuments { (snapshot , error) in
            if error != nil {
                print("Error when gathering Event Values \(String(describing: error))")
            }
            else{
                for document in (snapshot?.documents)! {
                    event.location = document.data()["location"] as? String ?? ""
                    event.destination = document.data()["Destination"] as? String ?? ""
                    event.platform = document.data()["Platform"] as? String ?? ""
                    event.time = document.data()["time"] as? String ?? ""
                    
                    let eventInstance = Event(location: event.location, destination: event.destination, platform: event.platform , time: event.time )
                    
                    self.eventList += [eventInstance]
                    
                }
            }
        }
    }
    

    func calculateData() {
        //Take location and time as parameter
        //Function to determine which data to map to information point interface
        //Need to access data store with user behaviour
        //Query SQL data
        //Assignment of new events to event table can be achived following significant location adjustments
    }
    
    func textParsing(ocrOutput: String, expectedDesination:String) -> (String) {
        //Perform parsing of OCR result upon the recognition of train times information point
        // Parse location as first line
        var platform: String = ""
        var selectedLine: [String] = []
        let lines = ocrOutput.components(separatedBy: "\n") //Implement array of lines to iterate through - First line depicts current location
        let destination = lines[0] //First line is location - CAN BE USED TO VALIDATE LOCATION GATHERED FROM COORDS
        
        if ocrOutput == "" //Simple Error Handeling
        {
            platform = ""
        }
        else {
            for line in lines[2...] { //From 3rd line onwards loop in order to gather train time
                if line.contains(expectedDesination) { //talk about oN is dis.
                selectedLine = line.components(separatedBy: " ") //Find line concerning expected destination
                }
            }
        }
        //MARK: NEEDs error handeling if OCR fails
        platform = selectedLine[1]
    
        print(platform)
        
        return (platform) //May need to return all values for parsing
    }
    
    
    func timeScrape(startPoint: String, endPoint: String) -> [String] { //Returning Arrays of platform and train times
        var arrivalTime = ""
        let URLString = String("https://www.thetrainline.com/live/departures/" + startPoint + "-to-" + endPoint) //Concatinate URL
        let sourceURL = NSURL(string: URLString)
        let html = try! String (contentsOf: sourceURL! as URL, encoding: .utf8)
        
        do {
            let siteDocument: Document = try SwiftSoup.parseBodyFragment(html)
            let componants = try siteDocument.getAllElements() //Get all elementes ready to be filtered]
            
            for i in componants {
                arrivalTime = try i.getElementsByClass("scheduled-time").text()
                break; //Limiting amount of information per fetch
            }
            
        } catch {
            print("Unable to parse URL")
        }
        
        let times = arrivalTime.components(separatedBy: " ")
        return times
    }
    

//    func readValues() {
//
//        //first empty the list of heroes
//        eventList.removeAll()
//
//        //this is our select query
//        let queryString = "SELECT * FROM Events"
//
//        //statement pointer
//        var stmt: OpaquePointer?
//
//        //preparing the query
//        if sqlite3_prepare(database, queryString, -1, &stmt, nil) != SQLITE_OK{
//            let errmsg = String(cString: sqlite3_errmsg(database)!)
//            print("error preparing insert: \(errmsg)")
//            return
//        }
//
//        //traversing through all the records
//        while(sqlite3_step(stmt) == SQLITE_ROW){
//            let id = sqlite3_column_int(stmt, 0)
//            let location = String(cString: sqlite3_column_text(stmt, 1))
//            let destination = String(cString: sqlite3_column_text(stmt, 2))
//            let platform = String(cString: sqlite3_column_text(stmt, 3))
//            let time = String(cString: sqlite3_column_text(stmt, 4))
//
//            //adding values to list
//            eventList.append(Event(id: Int(id), location: String(describing: location), destination: String(describing: destination), platform: String(describing: platform), time: String(describing: time)))
//        }
//
//        print("database values read")
//        print(eventList)
//    }
    
    //Renderer serving to latch software elements to recongnised information points
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let interfacePostion = anchor as? ARImageAnchor else {
            fatalError("Unable to find anchor point for software overlay")
        }
        
        //MARK: TRAIN TIME INFO POINT
        
        var trainTimes: [String] = []
        var timeDescription: String = "" //Varibale placeholder for gathered train times
        
        let positionBoarder: Float = 0.1
        
        let pointName = interfacePostion.referenceImage.name //Determine information point
        print(pointName!)
        
        
        //MARK: Can these be replaced with classes
        var expectedPlatform: String = "" //Must determine train time information point and perform OCR before platform result
        
        var expectDestination: String = "Penarth"  //FOR NOW ----Need to Use location infromation to parse expected destination
        
        var journeyDescription: String = ""
        var requiredPlatform: String = "2"
        var promptImage:String = "" //Variable for the defintion of a 
        let overlay = SCNPlane(width: interfacePostion.referenceImage.physicalSize.width, height: interfacePostion.referenceImage.physicalSize.height)
        var ocrResultVar: String = ""
       
    gatherValues()
        
        overlay.firstMaterial?.diffuse.contents = UIColor.clear //UIImage(named: "Proceed")
        let overlayNode = SCNNode(geometry: overlay)
        
        
        let node  = SCNNode()
        overlayNode.eulerAngles.x = -.pi / 2
        node.addChildNode(overlayNode)
        
        let imagefromscene = sceneView.session.currentFrame?.capturedImage
        guard let image = UIImage(pixelBuffer: imagefromscene!) else { return node }
        swiftyTesseract.performOCR(on: image) { ocrResult in
            ocrResultVar = ocrResult!
            print("OCR Result:" + ocrResultVar)
        }
        

         if (pointName?.contains("TrainTimes"))! { //TRAIN TIMES SIGN
            let imagefromscene = sceneView.session.currentFrame?.capturedImage
            
            guard let image = UIImage(pixelBuffer: imagefromscene!) else { return node }
            swiftyTesseract.performOCR(on: image) { ocrResult in
                guard let ocrResult = ocrResult else { return }
                print("OCR Result:" + ocrResult)
                //Location function to be called here to compute current station
                let requiredPlatform =  self.textParsing(ocrOutput: ocrResult, expectedDesination: expectDestination) //Set return result to current platform retrived through OCR
                
                //DATABase Query here
                
                journeyDescription = ("Go to Platform " + requiredPlatform + " for " + expectDestination + " train") //Need to fetch expected train informatiom
                promptImage = "Proceed"
            }
        }
            
         else {
            
            let imagefromscene = sceneView.session.currentFrame?.capturedImage
            guard let image = UIImage(pixelBuffer: imagefromscene!) else { return node }
            swiftyTesseract.performOCR(on: image) { ocrResult in
                ocrResultVar = ocrResult!
                print("OCR Result:" + ocrResultVar)
            }
                //Location function to be called here to compute current station
            
            if (!(ocrResultVar.contains("2"))) {
                
                print(ocrResultVar)
                promptImage = "Halt"
                ocrResultVar = ""
                
              
            }

            else if ((ocrResultVar.contains("2"))) { // Correct PLATFORM SIGN
                trainTimes = self.timeScrape(startPoint: self.startPoint, endPoint: self.endPoint)
                timeDescription = String(trainTimes[0] + "\n" + trainTimes[1] + "\n" + trainTimes[2]) //Limit information shown to user for UI clarity
                journeyDescription =  String(self.startPoint + " -> " + self.endPoint)
                promptImage = "Proceed"
                print(ocrResultVar)
                
                ocrResultVar = ""
                
            }
        }
        
        
        //Varaibles used as node should be manipulated by previouse if statement
        let headingNode = infoNode(pointName!, font: UIFont.boldSystemFont(ofSize: 200))
        headingNode.angleFromLeftPos()
        headingNode.position.x += Float(overlay.width / 2) + positionBoarder
        headingNode.position.y += Float(overlay.height / 2)
        overlayNode.addChildNode(headingNode)
        
        let journeyNode = infoNode(journeyDescription, font: UIFont.boldSystemFont(ofSize: 150))
        journeyNode.angleFromLeftPos()
        journeyNode.position.x += Float(overlay.width / 2) + positionBoarder
        journeyNode.position.y = Float(headingNode.position.y / 2) + positionBoarder
        overlayNode.addChildNode(journeyNode)
        
        let timesNode = infoNode(timeDescription, width: 1000, font: UIFont.systemFont(ofSize: 100))
        timesNode.angleFromLeftPos()
        timesNode.position.x += Float(overlay.width / 2) + positionBoarder
        timesNode.position.y = Float(journeyNode.position.y / 4) - positionBoarder
        overlayNode.addChildNode(timesNode)
        
        let alertNode = SCNPlane(width: interfacePostion.referenceImage.physicalSize.height, height:
            interfacePostion.referenceImage.physicalSize.width / 8 * 5)
        alertNode.firstMaterial?.diffuse.contents = UIImage(named: promptImage) //MARK: Shoudl be determined by previous if statement
        let imageNode = SCNNode(geometry: alertNode)
        imageNode.position.x -= Float(overlay.width)
        imageNode.position.y = Float(timesNode.position.y / 2) - positionBoarder
        overlayNode.addChildNode(imageNode)
        
        
       
        return node //Output Interface 
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
    
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        // Present an error message to the user
//
//    }
//
    func sessionWasInterrupted(_ session: ARSession) {
        print("Inter")

    }
//
//    func sessionInterruptionEnded(_ session: ARSession) {
//        // Reset tracking and/or remove existing anchors if consistent tracking is required
//
//    }
    
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
