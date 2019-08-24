//
//  ContextAR.swift
//  contextApp
//
//  Created by Dan Lages on 23/08/2019.
//  Copyright © 2019 Dan Lages. All rights reserved.
//

import Foundation
import CoreLocation

class Event {
    var location: String = ""
    var desitnation: String = ""
    var platform: String = ""
    var time: String = ""
    
    init(locationPermit: CLLocationManager, currTime: Int) { //Initialisation
        setLocation(locationPermit)
        setTime(currentTime: currTime)
    }
    
    func setLocation(_ permit: CLLocationManager){  //Set location value as lat and long
        let locationPeram:CLLocationCoordinate2D = permit.location!.coordinate
        location = (String(locationPeram.latitude) + String(locationPeram.longitude))
        
    }
    
    func setTime(currentTime: Int) {
        if currentTime < 1000  {
            time = "Morning"
        }
        else if currentTime > 1000 && currentTime < 1400 {
            time = "Noon"
        }
        
        else if currentTime > 1400 && currentTime < 1700 {
            time = "Afternoon"
        }
        
        else if currentTime > 1700 && currentTime < 2300 {
            time  = "Night"
        }
    }
    
    func store() { // Format and Store location within SQLite
        
    }
}


