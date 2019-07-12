
//
//  bullet.swift
//  gifTest
//
//  Created by Drew on 7/23/18.
//  Copyright © 2018 Drew. All rights reserved.
//

import Foundation
import SceneKit
import ARKit


class Bullet: SCNNode {
    
    var timer: Timer? = nil
    
    var type = "bullet"
    
    var counter = 0
    
    init(position: SCNVector3, rotation: SCNVector4, color: UIColor, size: CGFloat) {
        super.init()
        self.name = type
        let sphere = SCNSphere(radius: size)
        let material = SCNMaterial()
        material.diffuse.contents = color
        sphere.materials = [material]
        self.geometry = sphere
        self.rotation = rotation
        self.position = position
        
        
        let physicsShape = SCNPhysicsShape(node: self, options: nil)
        self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
        self.physicsBody?.collisionBitMask = 1
        self.physicsBody?.isAffectedByGravity = false
        self.physicsBody?.contactTestBitMask = self.physicsBody!.collisionBitMask
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) {
            _ in self.moveForward()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func moveForward(){
        self.counter += 2
        self.simdPosition += self.simdWorldFront * 10
        if self.counter >= 100{
            self.timer?.invalidate()
        }
    }
    
    
}
