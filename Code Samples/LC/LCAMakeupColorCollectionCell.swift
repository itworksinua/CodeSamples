//
//  LCAMakeupColorCollectionCell.swift
//  LippyCards
//
//  Created by Admin on 13.01.18.
//  Copyright © 2018 itworksinua. All rights reserved.
//

import UIKit

class LCAMakeupColorCollectionCell: UICollectionViewCell {
    @IBOutlet weak var viewColor: UIView!
    @IBOutlet weak var labelTitle: UILabel!
    private var _isSelected: Bool = false
    
    public var makeupObj: LCAMakeup! {
        get {
            return self.makeupObj
        }
        set(newValue) {
            viewColor.backgroundColor = newValue.makeupColor
            labelTitle.text = newValue.makeupTitle
        }
    }
    
    override public var isSelected: Bool {
        get {
            return _isSelected
        }
        set(newValue) {
            if newValue {
                self.viewColor.layer.borderColor = UIColor.white.cgColor
                self.viewColor.layer.borderWidth = 3
            } else {
                self.viewColor.layer.borderWidth = 0
            }
        }
    }
}
