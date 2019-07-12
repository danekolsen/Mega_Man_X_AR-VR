//
//  enemy.swift
//  ARKit Headset View
//
//  Created by Developer on 7/24/18.
//  Copyright © 2018 CompanyName. All rights reserved.
//

import Foundation
import SceneKit
import ARKit


///   ******SINGLETON********
class playerHealthSingleton{
    
    static let shared = playerHealthSingleton()
    
    var playerHealth = 100
    var killCount = 0
    var enemyCount = 0
    var menuButtonPresent = true
    var capsulePosition:SCNVector3?
    
    var enemies: [GameObject] = []
    
    private init(){
    }
}

///   ******PROTOCOL*********
protocol EnemyDelegate:class {
    func hurtPlayer()
    func enemyKilled()
}

///   *******GAMEOBJECT********
class GameObject:SCNNode{
    
    var batTimer:Timer? = nil
    var rollTimer:Timer? = nil
    var bulletTimer: Timer? = nil
    var helmTimer: Timer? = nil
    var capsuleTimer:Timer? = nil
    
    var delegate: EnemyDelegate!
    
    var batCounter = 0
    var rollCounter = 0
    var bulletCounter = 0
    var explosionCounter = 0
    var capsuleCounter = 0
    var helmCounter = 0
    
    var hasBeenHit = false
    
    var xRotation = Float(1.0)
    
    var image:UIImage?
    
    var material = SCNMaterial()
    
    var playerPosition: SCNVector3?
    
    var tempType: String?
    var tempPlayerPos: SCNVector3?
    
    
    ///   *******INIT*******
    init(userPosition: SCNVector3, type:String, rotation: SCNVector4){
        super.init()
        self.name = type
        playerPosition = userPosition
        if type == "start" {
            let position = SCNVector3(x: 0.0, y: 0.0, z: -10.0)
            material.diffuse.contents = UIImage(named: "start.png")
            let square = SCNPlane(width: 2.5, height: 2.0)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.001, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.isAffectedByGravity = false
        }
        
        if type == "lose" {
            let position = SCNVector3(x: 0.0, y: 0.0, z: -10.0)
            material.diffuse.contents = UIImage(named: "lose.jpg")
            let square = SCNPlane(width: 2.5, height: 2.5)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.001, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.isAffectedByGravity = false
        }
        
        if type == "win" {
            let position = SCNVector3(x: 0.0, y: 0.0, z: -10.0)
            material.diffuse.contents = UIImage(named: "win.png")
            let square = SCNPlane(width: 2.5, height: 2.5)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.001, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.isAffectedByGravity = false
        }
        
        if type == "yellow_bullet" || type == "green_bullet" || type == "blue_bullet" || type == "pink_bullet"{
            var sphere = SCNSphere(radius: 0.2)
            let material = SCNMaterial()
            if type == "yellow_bullet"{
                material.diffuse.contents = UIColor.yellow
            }else if type == "green_bullet"{
                material.diffuse.contents = UIImage(named: "gorb_0")
                sphere = SCNSphere(radius: 0.8)
            }else if type == "blue_bullet"{
                material.diffuse.contents = UIImage(named: "orb_0")
                sphere = SCNSphere(radius: 1.5)
            }else{
                material.diffuse.contents = UIImage(named: "porb_0")
                sphere = SCNSphere(radius: 2.5)
            }
            sphere.materials = [material]
            self.geometry = sphere
            self.rotation = rotation
            self.position = userPosition
            
            let physicsShape = SCNPhysicsShape(node: self, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.isAffectedByGravity = false
            
            self.physicsBody?.categoryBitMask = 1
            self.physicsBody?.collisionBitMask = 1
            if type == "blue_bullet"{
                self.physicsBody?.contactTestBitMask = 1 | 2
            } else {
                self.physicsBody?.contactTestBitMask = 1
            }
            self.bulletTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) {
                _ in self.moveForward()
            }
        }
        
        if type == "floor"{
            let floorPosition = SCNVector3(x: (userPosition.x), y: (userPosition.y - 2.0), z: (userPosition.z - 4.0))
            let floorMaterial = SCNMaterial()
            floorMaterial.isDoubleSided = true
            floorMaterial.diffuse.contents = UIImage(named: "floor.png")
            let floorPlane = SCNPlane(width: 4.0, height: 4.0)
            floorPlane.materials = [floorMaterial]
            self.geometry = floorPlane
            self.position = floorPosition
            //        let rot = SCNVector4(x: (sceneView.pointOfView?.position.x)!, y: ((sceneView.pointOfView?.position.y)! - 2.0), z: (sceneView.pointOfView?.position.z)!, w: 120.0)
            //        floorNode.rotation = rot
            self.eulerAngles = SCNVector3Make(Float.pi/2, 0, 0)
        }
        
        if type == "capsule"{
            capsuleTimer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(animateCapsule), userInfo: nil, repeats: true)
            let capPosition = SCNVector3(x: (userPosition.x), y: (userPosition.y - 3.5), z: (userPosition.z - 4.0))
            material.diffuse.contents = UIImage(named: "capsule_0.png")
            let square = SCNTube(innerRadius: 0.8, outerRadius: 0.8, height: 3.5)
            square.materials = [material]
            let capsuleRot = SCNVector4(x: rotation.x, y: (rotation.y - 2.0), z: (rotation.z), w: 80.1)
            self.geometry = square
            self.position = capPosition
            self.rotation = capsuleRot
            let movePosition = SCNVector3(x: userPosition.x, y: userPosition.y, z: (userPosition.z - 4.0))
            playerHealthSingleton.shared.capsulePosition = movePosition
            let action = SCNAction.move(to: movePosition, duration: 1.0)
            self.runAction(action)
            
        }
        
        if type == "capsuleIntro"{
            let material = SCNMaterial()
            material.diffuse.contents = UIImage(named: "capsuleIntro.png")
            let square = SCNPlane(width: 1.5, height: 1.0)
            square.materials = [material]
            self.geometry = square
            self.position = userPosition
            self.constraints = [SCNBillboardConstraint()]
        }

        if type == "bat"{
            batTimer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector: #selector(batCountDown), userInfo: nil, repeats: true)
            var x = Double(arc4random_uniform(2)+2)
            let tempx = arc4random_uniform(5)
            if tempx == 0 {
                x += 0.5
            } else if tempx == 1 {
                x -= 0.5
            } else if tempx == 2 {
                x += 1
            } else if tempx == 3 {
                x -= 1
            } else if tempx == 4 {
                x += 1.5
            } else {
                x -= 1.5
            }
            let randNeg = arc4random_uniform(11)
            if randNeg < 6{
                x *= -1
            }
            var y = Double(arc4random_uniform(1))
            let tempy = arc4random_uniform(1)
            if tempy == 0 {
                y += 0.5
            } else {
                y -= 0.5
            }
            var z = Double((arc4random_uniform(4)+4)) * -1
            let tempz = arc4random_uniform(1)
            if tempz == 0 {
                z += 0.5
            } else {
                z -= 0.5
            }
            let position = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
            material.diffuse.contents = UIImage(named: "bat0.png")
            let square = SCNPlane(width: 0.4, height: 0.4)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.001, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.isAffectedByGravity = false
            moveEnemy(destination: playerPosition!, duration: 10)
        }
        
        if type == "roll"{
             rollTimer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(rollCountDown), userInfo: nil, repeats: true)
            var x = Double(arc4random_uniform(2)+2)
            let tempx = arc4random_uniform(5)
            if tempx == 0 {
                x += 0.5
            } else if tempx == 1 {
                x -= 0.5
            } else if tempx == 2 {
                x += 1
            } else if tempx == 3 {
                x -= 1
            } else if tempx == 4 {
                x += 1.5
            } else {
                x -= 1.5
            }
            let randNeg = arc4random_uniform(11)
            if randNeg < 6{
                x *= -1
            }

            let y = -0.6
            
            var z = Double((arc4random_uniform(4)+4)) * -1
            let tempz = arc4random_uniform(1)+3
            if tempz == 0 {
                z += 0.5
            } else {
                z -= 0.5
            }
            let position = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
            material.diffuse.contents = UIImage(named: "roll0.png")
            let square = SCNPlane(width: 1.5, height: 1.5)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 1.5, height: 1.5, length: 0.1, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.collisionBitMask = 1
            self.physicsBody?.isAffectedByGravity = false
            self.physicsBody?.contactTestBitMask = self.physicsBody!.collisionBitMask
            moveEnemy(destination: playerPosition!, duration: 10)
        }
        
        if type == "helm"{
            helmTimer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector: #selector(helmCountDown), userInfo: nil, repeats: true)
            var x = Double(arc4random_uniform(2)+2)
            let tempx = arc4random_uniform(5)
            if tempx == 0 {
                x += 0.5
            } else if tempx == 1 {
                x -= 0.5
            } else if tempx == 2 {
                x += 1
            } else if tempx == 3 {
                x -= 1
            } else if tempx == 4 {
                x += 1.5
            } else {
                x -= 1.5
            }
            
            let randNeg = arc4random_uniform(11)
            if randNeg < 6{
                x *= -1
            }
            
            let y = -1.3
            
            var z = Double((arc4random_uniform(2)+2)) * -1
            let tempz = arc4random_uniform(1)
            if tempz == 0 {
                z += 0.5
            } else {
                z -= 0.5
            }
            let position = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
            material.diffuse.contents = UIImage(named: "helm0.png")
            let square = SCNPlane(width: 0.4, height: 0.4)
            square.materials = [material]
            self.geometry = square
            self.position = position
            self.constraints = [SCNBillboardConstraint()]
            
            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.1, chamferRadius: 0.0)
            let bumpNode = SCNNode(geometry: bumpBox)
            bumpNode.position = position
            
            let physicsShape = SCNPhysicsShape(node: bumpNode, options: nil)
            self.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.dynamic, shape: physicsShape)
            self.physicsBody?.collisionBitMask = 1
            self.physicsBody?.isAffectedByGravity = false
            self.physicsBody?.contactTestBitMask = self.physicsBody!.collisionBitMask
            moveEnemy(destination: playerPosition!, duration: 10)
        }

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
//
//    ///   *********REROLL********
//    func reRoll(){
//        print("rerollinnnnnn")
//        print("POSITION ON REROLL BEFORE CHANGE", self.position)
//        self.name = tempType
//
//        batCounter = 0
//        rollCounter = 0
//        bulletCounter = 0
//        explosionCounter = 0
//        helmCounter = 0
//
//        batTimer?.invalidate()
//        rollTimer?.invalidate()
//        helmTimer?.invalidate()
//        bulletTimer?.invalidate()
//
//        playerPosition = tempPlayerPos
//        if tempType == "bat"{
//            print("rerolled to a bat")
//            var x = Double(arc4random_uniform(2)+2)
//            let tempx = arc4random_uniform(5)
//            if tempx == 0 {
//                x += 0.5
//            } else if tempx == 1 {
//                x -= 0.5
//            } else if tempx == 2 {
//                x += 1
//            } else if tempx == 3 {
//                x -= 1
//            } else if tempx == 4 {
//                x += 1.5
//            } else {
//                x -= 1.5
//            }
//            let randNeg = arc4random_uniform(11)
//            if randNeg < 6{
//                x *= -1
//            }
//            var y = Double(arc4random_uniform(1))
//            let tempy = arc4random_uniform(1)
//            if tempy == 0 {
//                y += 0.5
//            } else {
//                y -= 0.5
//            }
//            var z = Double((arc4random_uniform(4)+4)) * -1
//            let tempz = arc4random_uniform(1)
//            if tempz == 0 {
//                z += 0.5
//            } else {
//                z -= 0.5
//            }
//            let destination = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
//            moveEnemy(destination: destination, duration: 0.1)
//            print("AFTER POSITION CHANGE", self.position)
//            batTimer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector: #selector(batCountDown), userInfo: nil, repeats: true)
//            material.diffuse.contents = UIImage(named: "bat0.png")
//            let square = SCNPlane(width: 0.4, height: 0.4)
//            //            let square = SCNBox(width: 0.4, height: 0.4, length: 0.4, chamferRadius: 0.0)
//            square.materials = [material]
//
//            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.001, chamferRadius: 0.0)
//            let bumpNode = SCNNode(geometry: bumpBox)
//            bumpNode.position = position
//        }
//
//        if tempType == "roll"{
//            print("rerolled to a rollll")
//            var x = Double(arc4random_uniform(2)+2)
//            let tempx = arc4random_uniform(5)
//            if tempx == 0 {
//                x += 0.5
//            } else if tempx == 1 {
//                x -= 0.5
//            } else if tempx == 2 {
//                x += 1
//            } else if tempx == 3 {
//                x -= 1
//            } else if tempx == 4 {
//                x += 1.5
//            } else {
//                x -= 1.5
//            }
//            let randNeg = arc4random_uniform(11)
//            if randNeg < 6{
//                x *= -1
//            }
//
//            let y = -0.6
//
//            var z = Double((arc4random_uniform(4)+4)) * -1
//            let tempz = arc4random_uniform(1)+3
//            if tempz == 0 {
//                z += 0.5
//            } else {
//                z -= 0.5
//            }
//            let destination = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
//            moveEnemy(destination: destination, duration: 0.1)
//            print("AFTER POSITION CHANGE", self.position)
//            rollTimer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(rollCountDown), userInfo: nil, repeats: true)
//            material.diffuse.contents = UIImage(named: "roll0.png")
//            let square = SCNPlane(width: 1.5, height: 1.5)
//            //            let square = SCNBox(width: 1.5, height: 1.5, length: 1.5, chamferRadius: 0.0)
//            square.materials = [material]
//            self.geometry = square
////            self.simdPosition = simd_float3(position)
////            self.worldPosition = position
////            self.position = SCNVector3(2.0, 2.0,1.0)
//
//            let bumpBox = SCNBox(width: 1.5, height: 1.5, length: 0.1, chamferRadius: 0.0)
//            let bumpNode = SCNNode(geometry: bumpBox)
//            bumpNode.position = position
//        }
//
//        if tempType == "helm"{
//            var x = Double(arc4random_uniform(2)+2)
//            let tempx = arc4random_uniform(5)
//            if tempx == 0 {
//                x += 0.5
//            } else if tempx == 1 {
//                x -= 0.5
//            } else if tempx == 2 {
//                x += 1
//            } else if tempx == 3 {
//                x -= 1
//            } else if tempx == 4 {
//                x += 1.5
//            } else {
//                x -= 1.5
//            }
//
//            let randNeg = arc4random_uniform(11)
//            if randNeg < 6{
//                x *= -1
//            }
//
//            let y = -1.3
//
//            var z = Double((arc4random_uniform(2)+2)) * -1
//            let tempz = arc4random_uniform(1)
//            if tempz == 0 {
//                z += 0.5
//            } else {
//                z -= 0.5
//            }
//
//            let position = SCNVector3(x: Float(x), y: Float(y), z: Float(z))
//            helmTimer = Timer.scheduledTimer(timeInterval: 0.10, target: self, selector: #selector(helmCountDown), userInfo: nil, repeats: true)
//            material.diffuse.contents = UIImage(named: "helm0.png")
//            let square = SCNPlane(width: 0.4, height: 0.4)
//            square.materials = [material]
//
//            let bumpBox = SCNBox(width: 0.4, height: 0.4, length: 0.1, chamferRadius: 0.0)
//            let bumpNode = SCNNode(geometry: bumpBox)
//            bumpNode.position = position
//        }
//        hasBeenHit = false
//        moveEnemy(destination: playerPosition!, duration: 10)
//    }

    @objc func batCountDown(){
        if playerHealthSingleton.shared.menuButtonPresent == true {
            hasBeenHit = true
        }

        if hasBeenHit == false {
            if batCounter > 5 {
                batCounter = 0
            }
            self.material.diffuse.contents = UIImage(named: "bat\(batCounter)")
            
            batCounter += 1
        } else {
            self.physicsBody?.collisionBitMask = 3
            if explosionCounter > 9{
//                reRoll()
                self.removeFromParentNode()
            }
            self.material.diffuse.contents = UIImage(named: "explosion\(explosionCounter)")
            explosionCounter += 1
        }
        if (self.position.x <= playerPosition!.x + 0.5 && self.position.x >= playerPosition!.x - 0.5)  && (self.position.z <= playerPosition!.z + 0.5 && self.position.z >= playerPosition!.z - 0.5){
            if playerHealthSingleton.shared.playerHealth >= 0 && hasBeenHit == false{
                playerHealthSingleton.shared.playerHealth -= 10
                delegate.hurtPlayer()
                hasBeenHit = true
            }
        }
    }

    @objc func rollCountDown(){
        if playerHealthSingleton.shared.menuButtonPresent == true {
            hasBeenHit = true
        }
        
        if hasBeenHit == false {
            if rollCounter > 13 {
                rollCounter = 0
            }
            self.material.diffuse.contents = UIImage(named: "roll\(rollCounter)")
            rollCounter += 1
        } else {
            if explosionCounter > 9{
//                reRoll()
                self.removeFromParentNode()
            }
            self.material.diffuse.contents = UIImage(named: "explosion\(explosionCounter)")
            explosionCounter += 1
        }
        if (self.position.x <= playerPosition!.x + 0.5 && self.position.x >= playerPosition!.x - 0.5)  && (self.position.z <= playerPosition!.z + 0.5 && self.position.z >= playerPosition!.z - 0.5){
            if playerHealthSingleton.shared.playerHealth >= 0 && hasBeenHit == false{
                delegate.hurtPlayer()
                playerHealthSingleton.shared.playerHealth -= 10
                hasBeenHit = true
            }
        }
    }
    
    @objc func helmCountDown(){
        if playerHealthSingleton.shared.menuButtonPresent == true {
            hasBeenHit = true
        }
        
        if hasBeenHit == false {
            if helmCounter > 20 {
                helmCounter = 0
            }
            self.material.diffuse.contents = UIImage(named: "helm\(helmCounter)")
            helmCounter += 1
        } else {
            if explosionCounter > 9{
                self.removeFromParentNode()
//                reRoll()
            }
            self.material.diffuse.contents = UIImage(named: "explosion\(explosionCounter)")
            explosionCounter += 1
        }
        if (self.position.x <= playerPosition!.x + 0.5 && self.position.x >= playerPosition!.x - 0.5)  && (self.position.z <= playerPosition!.z + 0.5 && self.position.z >= playerPosition!.z - 0.5){
            if playerHealthSingleton.shared.playerHealth >= 0 && hasBeenHit == false{
                delegate.hurtPlayer()
                playerHealthSingleton.shared.playerHealth -= 10
                hasBeenHit = true
            }
        }
    }
    
    @objc func animateCapsule(){
        print(capsuleCounter)
        if capsuleCounter > 3{
            capsuleCounter = 0
        }
        self.material.diffuse.contents = UIImage(named: "capsule_\(capsuleCounter)")
        capsuleCounter += 1
    }

    
    @objc func moveForward(){
        self.bulletCounter += 1
        self.simdPosition += self.simdWorldFront
        if self.bulletCounter >= 50{
            self.bulletTimer?.invalidate()
            self.physicsBody?.collisionBitMask = 2
            self.geometry = nil
            self.removeFromParentNode()
        }
    }
    
    func moveEnemy(destination: SCNVector3, duration: Double){
        let action = SCNAction.move(to: destination, duration: duration)
        self.runAction(action)
    }
}
