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
import MapKit
import Vision
import CoreData
import FirebaseFirestore
import Foundation //Allowing for the use of external clases
import CoreLocation //Core Location module, for the activation of functionality if user is with the pre-established scene
import SwiftSoup //Swift Soup pod imported for webscraping
import SwiftyTesseract //SwiftyTesseract Pod imported for OCR
import SQLite3 //SQLite imported for database implementation
import VideoToolbox
import MobileCoreServices

class Event {
    var location: String?
    var destination: String?
    var platform: String?
    var time: String?
    
    init(location: String?, destination: String?, platform: String?, time: String){
        self.location = location
        self.destination = destination
        self.platform = platform
        self.time = time
    }
}

struct event { //Intial Struct Concept for Storing events
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
    var destinationList:[String] = []
    
    var currentStationLocation: String = ""
    var currentStationPostCode: String = ""
    var expectedDestination: String = ""
    var requiredPlatform: String = ""
    var finalDestination: String = ""
    var timeDescription: String = ""
    var eventStore : [[String]] = [  ["BS1 6BX", "Penarth", "1", "Evening"], ["BS1 6LQ", "Penarth", "2", "Evening"], ["BS1 6BX", "Penarth", "2", "Evening"], ["BS1 6LQ", "Bristol-Temple-Meads", "2", "Evening"], ["BS1 6LQ", "Cardiff", "1", "Evening"] ]  //Database Storage - Events will be identifiable through the postcode value
  
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
        
      
        self.timeDescription = getCurrentTime()
        
        
        if let lastLocation = self.locationPermit.location {
            let geocoder = CLGeocoder()
            
            geocoder.reverseGeocodeLocation(lastLocation, completionHandler: { (localPoints, error) in
                if error == nil {
                    let locationResult = localPoints?[0]
                    print ("Postcode: " + (locationResult?.postalCode)!) //Return location Postcode to be passed into initial location feild
                    self.currentStationPostCode = String((locationResult?.postalCode)!)
                    
                    self.currentStationPostCode = (locationResult?.postalCode!)!
                }
            })
        }
        
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
    
    

    func lookUpCurrentLocation(completionHandler: @escaping (CLPlacemark?)
        -> Void ) {
        // Use the last reported location.
        if let lastLocation = self.locationPermit.location {
            let geocoder = CLGeocoder()
            
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation,
            completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    completionHandler(firstLocation)
                    //firstLocation.postal
                }
                else {
                    // An error occurred during geocoding.
                    completionHandler(nil)
                }
            })
        }
        else {
            // No location was available.
            completionHandler(nil)
        }
    }
    
    
    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) ->String {
//
//        var userLocationString = ""
//
//        //Delegate function allows us to handle loaction information
//        let location:CLLocationCoordinate2D = locationPermit.location!.coordinate //Determine user location
//        let userLat = location.latitude
//        let userLong = location.longitude
//        let userLocation = CLLocation(latitude: userLat, longitude: userLong)
//
//        let geoCoder = CLGeocoder()
//        userLocationString = (String(userLat+userLong))
//
//        geoCoder.reverseGeocodeLocation(manager.location!, completionHandler: {(placemarks, error)->Void in
//
//            if (error != nil) {
//                print("Reverse geocoder failed with error" + (error?.localizedDescription)!)
//                return
//            }
//
//            if (placemarks?.count)! > 0 {
//                let loactionMarkers = placemarks?[0]
//                self.locationPermit.stopUpdatingLocation()
//                let postalCode = (loactionMarkers?.postalCode != nil) ? loactionMarkers?.postalCode : ""
//                //let locality = (containsPlacemark.locality != nil) ? containsPlacemark.locality : ""
//                //let postalCode = (placemarks.postalCode != nil) ? placemarks.postalCode : ""
//                //let administrativeArea = (containsPlacemark.administrativeArea != nil) ? containsPlacemark.administrativeArea : ""
//                // let country = (containsPlacemark.country != nil) ? containsPlacemark.country : ""
//                print(postalCode)
//                userLocationString = String(postalCode!)
//            }
//        })
//
//        return userLocationString
//    }
    
    
    
//func gatherReleventEvents(_ location: String, _ timeOfDay: String, _ requiredPlatform: String) -> String { //MARK: Initial Firbase Store
//        let eventDatabase = Firestore.firestore()
//        //var eventArr = [Event]()
//        var destinationArr:[String] = []
//
//        eventDatabase.collection("Event").getDocuments { (snapshot , error) in
//            if error != nil {
//                print("Error when gathering Event Values \(String(describing: error))")
//            }
//            else{
//                for document in (snapshot?.documents)! {
//                    if (document.data()["location"] as! String) == location && (document.data()["time"] as! String) == timeOfDay {
//                        event.location = (document.data()["location"] as! String)
//                        event.destination = (document.data()["destination"] as! String)
//                        event.platform = (document.data()["platform"] as! String)
//                        event.time = (document.data()["time"] as! String)
//                        let dest = (document.data()["destination"] as! String)
//                        destinationArr.append(event.destination)
//                        //print(document.data()["destination"] as! String)
//                    }
//                    //let eventInstance = Event(location: event.location, destination: event.destination, platform: event.platform , time: event.time )
//                }
//            }
//            print(destinationArr)
//
//        }
        
//        var amount = [String: Int]() //Dictioary to store value and counts
//        var mostFrequent = ""
//
//
//
//
//
//
//        for local in destinationArr {
//            if let iter = amount[local] {
//                amount[local] = iter + 1
//            }
//            else {
//                amount[local] = 1
//            }
//        }
//
//        for key in amount.keys {
//            if mostFrequent == "" {
//                mostFrequent = key
//            }
//            else {
//                let count = amount[key]!
//                if count > amount[mostFrequent]! {
//                    mostFrequent = key
//                }
//            }
//
//        }
        
//        if (requiredPlatform != "" || expectedPlatform != "")
//        {
//            let journeyDescription = ("Go to Platform " + requiredPlatform + " for " + expectedDestination + " train") //Need to fetch expected train informatiom
//            let promptImage = "Halt"
//        }
//
//        else{
//            let journeyDescription = ("Unable to gather context from current datapoints")
//        }
        
        //return mostFrequent
   // }
 
//    func retrieveMostlikley(_ destinations: [String]) -> String {
//
//        var locationArr:[String] = []
//        var amount = [String: Int]() //Dictioary to store value and counts
//        var mostFrequent = ""
//
//        //for record in eventArr
//
//        for record in destinations {
//            locationArr.append(record)
//        }
//
//        for local in locationArr {
//            if let iter = amount[local] {
//                amount[local] = iter + 1
//            }
//            else {
//                amount[local] = 1
//            }
//        }
//
//        for key in amount.keys {
//            if mostFrequent == "" {
//                mostFrequent = key
//            }
//            else {
//                let count = amount[key]!
//                if count > amount[mostFrequent]! {
//                    mostFrequent = key
//                }
//            }
//
//        }
//
//        return mostFrequent
//    }
    
    func getCurrentTime() -> String {
        let currentDate = Date()// Date method for retrieving time elements from calander
        var calandarComponant = Calendar.current
        let format = DateFormatter()
        format.dateFormat = "HHmm"
        var timeVal: String
        var timeComp: Int
        var timeString: String
        //componants renamed to date componants
        
        timeString = ""
        
        timeVal = format.string(from: currentDate)
        
        timeComp = Int(timeVal)!
        
        if timeComp < 1200 {
            timeString = "Morning"
        }
        
        else if timeComp > 1200 && timeComp < 1600 {
             timeString = "Afternoon"
        }
        
        else if timeComp > 1600 {
             timeString = "Evening"
        }
        
        
        print("time:" + timeString)
        
        return timeString
    }
    
    func storeEvent(location: String, destination: String, time: String, platform: String) { //Store collection into database
        let eventDatabase = Firestore.firestore()
        eventDatabase.collection("Event").document("Event").setData([
            "location" : location,
            "destination" : destination,
            "time" : time,
            "platform" : platform
            ])
    }
    
    func textParsing(ocrOutput: String, expectedDesination:String) -> (String,String)  {
        //Perform parsing of OCR result upon the recognition of train times information point
        // Parse location as first line
        var platform: String = ""
        var calculatedLocation: String = ""
        var selectedLine: [String] = []
        let lines = ocrOutput.components(separatedBy: "\n") //Implement array of lines to iterate through - First line depicts current location
        let destination = lines[0] //First line is location - CAN BE USED TO VALIDATE LOCATION GATHERED FROM COORDS
        
        if ocrOutput == "" //Simple Error Handeling
        {
            platform = ""
        }
        else {
            calculatedLocation = lines[0]
            print("DestEcpt: " + calculatedLocation)
            
            for line in lines[2...] { //From 3rd line onwards loop in order to gather train time
                if line.contains(expectedDesination) { //talk about oN is dis.
                selectedLine = line.components(separatedBy: " ") //Find line concerning expected destination
                platform = selectedLine[1]
                print(platform)
                }
            }
        }
        //MARK: NEEDs error handeling if OCR fails
        
        return (calculatedLocation, platform) //May need to return all values for parsing
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
//
//    func getStationName(OCRresult: String) -> String {
//        var stationName = ""
//        var stationTextArray = ""
//
//        for line in OCRresult {
//            OCRresult.components(separatedBy: "\n")
//        }
//
//
//        return stationName
//    }
    
    
    // MARK: - ARSCNViewDelegate
    //Renderer serving to latch software elements to recongnised information points
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let interfacePostion = anchor as? ARImageAnchor else {
            fatalError("Unable to find anchor point for software overlay")
        }
        
        locationPermit.delegate = self as CLLocationManagerDelegate
        locationPermit.desiredAccuracy = kCLLocationAccuracyBest
        locationPermit.requestAlwaysAuthorization() //Request Allways On location for effective computation
        locationPermit.startUpdatingLocation()
        
        
        
        //MARK: TRAIN TIME INFO POINT
        
        var trainTimes: [String] = []
        var timeDescription: String = "" //Varibale placeholder for gathered train times

        let positionBoarder: Float = 0.1

        let pointName = interfacePostion.referenceImage.name //Determine information point
        print(pointName!)
        
        var intialLocation = ""
        
        var destList: [String] = []

        //MARK: Can these be replaced with classes
        var expectedPlatform: String = "" //Must determine train time information point and perform OCR before platform result

        var journeyDescription: String = ""
    
        var promptImage:String = "" //Variable for the defintion of a promt image
        
        let overlay = SCNPlane(width: interfacePostion.referenceImage.physicalSize.width, height: interfacePostion.referenceImage.physicalSize.height)
        
        var ocrResultVar: String = ""
       
        
        overlay.firstMaterial?.diffuse.contents = UIColor.clear //UIImage(named: "Proceed")
        let overlayNode = SCNNode(geometry: overlay)
        
        let node  = SCNNode()
        overlayNode.eulerAngles.x = -.pi / 2
        node.addChildNode(overlayNode)

        if ((pointName?.contains("arrival"))!) {
            swiftyTesseract.performOCR(on: UIImage(imageLiteralResourceName:(pointName!))) { ocrOutcome in
                guard let ocrOutcome = ocrOutcome else { return }
                print("Outcome:" + ocrOutcome)
                self.finalDestination = ocrOutcome
            }
        }
        
        
         else if (pointName?.contains("traintimes"))! { //TRAIN TIMES SIGN
//            let imagefromscene = sceneView.session.currentFrame?.capturedImage
//            
//            guard let image = UIImage(pixelBuffer: imagefromscene!) else { return node } //To be changed to reference image capture
//            swiftyTesseract.performOCR(on: image) { ocrResult in
//                ocrResultVar = ocrResult!
            
            swiftyTesseract.performOCR(on:UIImage(imageLiteralResourceName:(pointName)!)) { ocrResult in
                guard let ocrResult = ocrResult else { return }
                print("OCR Result:" + ocrResult)
                
                for (_, element) in self.eventStore.enumerated() {
                    if self.currentStationPostCode == element[0] && self.timeDescription == element[3] {  //Look at postcode and timeValues
                        destList.append(element[1])
                    }
                }
                    
                var amount = [String: Int]() //Dictioary to store value and counts
                var mostFrequent = ""
    
                for local in destList {
                    if let iter = amount[local] {
                        amount[local] = iter + 1
                    }
                    else {
                        amount[local] = 1
                    }
                }
                for key in amount.keys {
                    if mostFrequent == "" {
                        mostFrequent = key
                    }
                    else {
                        let count = amount[key]!
                        if count > amount[mostFrequent]! {
                            mostFrequent = key
                        }
                    }
        
                }
                print("expected destination: " +  mostFrequent)
                self.expectedDestination = mostFrequent

                
                
                //let mostLikly = self.gatherReleventEvents(self.currentStationPostCode, self.timeDescription, self.requiredPlatform)
                
                (self.currentStationLocation, self.requiredPlatform) = self.textParsing(ocrOutput: ocrResult, expectedDesination: self.expectedDestination) //Sets return result to current platform retrived through OCR
                print("Platform: " + self.requiredPlatform)
            }
            
            if (self.requiredPlatform != "" || self.expectedDestination != "") {
                journeyDescription = ("Go to Platform " + self.requiredPlatform + " for " + self.expectedDestination + " train") //Need to fetch expected train informatiom
                promptImage = "Halt"
            }
                
            else {
                journeyDescription = ("Unable to gather context from current datapoints")
            }
        }
        
        else if ((pointName?.contains(requiredPlatform) ?? true)) {
            trainTimes = self.timeScrape(startPoint: self.currentStationLocation, endPoint: self.expectedDestination)
            timeDescription = String(trainTimes[0] + "\n" + trainTimes[1] + "\n" + trainTimes[2]) //Limit information shown to user for UI clarity
            journeyDescription = String("Expected Route: " + self.currentStationLocation + " -> " + self.expectedDestination)
            promptImage = "Proceed"
            print(ocrResultVar)
        }
            
            
         else if (!((pointName?.contains(requiredPlatform))!)) {
            promptImage = "Halt"
            // print(ocrResultVar)
        }
        
       
            // print(ocrResultVar)
        
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
        alertNode.firstMaterial?.diffuse.contents = UIImage(named: promptImage)
        
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


// ----INTIAL DATABASE IMPLEMENTATION
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
//
//        print("database values read")
//        print(eventList)
//    }
