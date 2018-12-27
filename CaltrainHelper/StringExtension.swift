//
//  StringExtension.swift
//  CaltrainHelper
//
//  Created by Jiaqi Chen on 12/26/18.
//  Copyright © 2018 Jiaqi Chen. All rights reserved.
//

import Foundation
import UIKit

extension String {
    func convertHtml() -> NSAttributedString{
        guard let data = data(using: .utf8) else { return NSAttributedString() }
        do{
            return try NSAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil)
        }catch{
            return NSAttributedString()
        }
    }
}
