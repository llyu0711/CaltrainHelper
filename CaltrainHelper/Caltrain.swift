//
//  Caltrain.swift
//  CaltrainHelper
//
//  Created by Jiaqi Chen on 12/22/18.
//  Copyright © 2018 Jiaqi Chen. All rights reserved.
//

import Foundation

class Caltrain {
    var number: Int
    var eta: Int
    var type: String
    
    init(number: Int, eta: Int, type: String) {
        self.number = number
        self.eta = eta
        self.type = type
    }
    
    func getNumber() -> Int {
        return self.number
    }
    
    func getEta() -> Int {
        return self.eta
    }
    
    func getType() -> String {
        return self.type
    }
    
    func setEta(eta: Int) -> Void {
        self.eta = eta
    }
}
