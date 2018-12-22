//
//  CaltrainStation.swift
//  CaltrainHelper
//
//  Created by Jiaqi Chen on 11/4/18.
//  Copyright © 2018 Jiaqi Chen. All rights reserved.
//

import Foundation

class CaltrainStation {
    var name: String
    var latitude: Double
    var longtitude: Double
    var nbStopCode: Int
    var sbStopCode: Int
    
    init(name: String, latitude: Double, longtitude: Double, nbStopCode: Int, sbStopCode: Int) {
        self.name = name
        self.latitude = latitude
        self.longtitude = longtitude
        self.nbStopCode = nbStopCode
        self.sbStopCode = sbStopCode
    }
    
    func getName() -> String {
        return self.name
    }
    
    func getLatitude() -> Double {
        return self.latitude
    }
    
    func getLongtitude() -> Double {
        return self.longtitude
    }
    
    func getNbCode() -> Int {
        return self.nbStopCode
    }
    
    func getSbCode() -> Int {
        return self.sbStopCode
    }
}
