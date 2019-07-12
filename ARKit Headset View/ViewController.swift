//
//  ViewController.swift
//  ARKit Headset View
//
//  Created by Hanley Weng on 8/7/17.
//  Copyright © 2017 CompanyName. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import AVFoundation
import CoreLocation

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    ///   ******VARIABLES********
    @IBOutlet var HUDRightView: UIView!
    @IBOutlet var HUDLeftView: UIView!
    
    @IBOutlet weak var HUDLeftHPView: UIImageView!
    @IBOutlet weak var HUDRightHPView: UIImageView!
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var sceneViewLeft: ARSCNView!
    @IBOutlet weak var sceneViewRight: ARSCNView!
    
    @IBOutlet weak var imageViewLeft: UIImageView!
    @IBOutlet weak var imageViewRight: UIImageView!
    
    @IBOutlet weak var rightScoreHUDLabel: UILabel!
    @IBOutlet weak var leftScoreHUDLabel: UILabel!
    
    @IBOutlet weak var leftChargeIV: UIImageView!
    @IBOutlet weak var rightChargeIV: UIImageView!
    
    let eyeCamera : SCNCamera = SCNCamera()
    var scene = SCNScene()
    var camera:SCNVector3?
    var capsuleNode:SCNNode?
    
    var shotCounter = 0
    var chargeCounter = 0
    var orbCounter = 0
    
    var isChargingSFX = true
    var hasUpgradedBlaster = false
    var hasIntroRun = false
    
    var orbTimer:Timer?
    var chargeTimer:Timer?
    
    
    var bulletPlayer: AVAudioPlayer?
    var themePlayer: AVAudioPlayer?
    var explodePlayer: AVAudioPlayer?
    var chargingPlayer: AVAudioPlayer?
    
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    var visionRequests = [VNRequest]()
    
    // Parametres
    let interpupilaryDistance = 0.066 // This is the value for the distance between two pupils (in metres). The Interpupilary Distance (IPD).
    let viewBackgroundColor : UIColor = UIColor.black // UIColor.white
    /*
     SET eyeFOV and cameraImageScale. UNCOMMENT any of the below lines to change FOV:
     */
    //    let eyeFOV = 38.5; var cameraImageScale = 1.739; // (FOV: 38.5 ± 2.0) Brute-force estimate based on iPhone7+
    let eyeFOV = 60; var cameraImageScale = 3.478; // Calculation based on iPhone7+ // <- Works ok for cheap mobile headsets. Rough guestimate.
    //    let eyeFOV = 90; var cameraImageScale = 6; // (Scale: 6 ± 1.0) Very Rough Guestimate.
    //    let eyeFOV = 120; var cameraImageScale = 8.756; // Rough Guestimate.
    
    ///   *******VIEW DID LOAD********
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playTheme()
//        getUpgradedBlaster()
//        capsuleIntro()
//        runUpgradeBlasterAnimation()
        
        scene.physicsWorld.contactDelegate = self

        spawnStartButton()
        orbTimer = Timer.scheduledTimer(timeInterval: 0.30, target: self, selector: #selector(updateOrbImage), userInfo: nil, repeats: true)
        
        camera = sceneView.pointOfView!.position

        sceneViewRight.addSubview(HUDRightView)
        sceneViewLeft.addSubview(HUDLeftView)
        
//        sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        // Set the view's delegate
        sceneView.delegate = self
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = false
        // Create a new scene
            // Set the scene to the view
        sceneView.scene = scene
        
        ////////////////////////////////////////////////////////////////
        // App Setup
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Scene setup
        sceneView.isHidden = true
        self.view.backgroundColor = viewBackgroundColor
        
        ////////////////////////////////////////////////////////////////
        // Set up Left-Eye SceneView
        sceneViewLeft.scene = scene
        sceneViewLeft.showsStatistics = sceneView.showsStatistics
        sceneViewLeft.isPlaying = true
        
        // Set up Right-Eye SceneView
        sceneViewRight.scene = scene
        sceneViewRight.showsStatistics = sceneView.showsStatistics
        sceneViewRight.isPlaying = true
        
        ////////////////////////////////////////////////////////////////
        // Update Camera Image Scale - according to iOS 11.3 (ARKit 1.5)
        if #available(iOS 11.3, *) {
//            print("iOS 11.3 or later")
            cameraImageScale = cameraImageScale * 1080.0 / 720.0
        } else {
//            print("earlier than iOS 11.3")
        }
        
        ////////////////////////////////////////////////////////////////
        // Create CAMERA
        eyeCamera.zNear = 0.001
        /*
         Note:
         - camera.projectionTransform was not used as it currently prevents the simplistic setting of .fieldOfView . The lack of metal, or lower-level calculations, is likely what is causing mild latency with the camera.
         - .fieldOfView may refer to .yFov or a diagonal-fov.
         - in a STEREOSCOPIC layout on iPhone7+, the fieldOfView of one eye by default, is closer to 38.5°, than the listed default of 60°
         */
        eyeCamera.fieldOfView = CGFloat(eyeFOV)
        
        ////////////////////////////////////////////////////////////////
        // Setup ImageViews - for rendering Camera Image
        self.imageViewLeft.clipsToBounds = true
        self.imageViewLeft.contentMode = UIView.ContentMode.center
        self.imageViewRight.clipsToBounds = true
        self.imageViewRight.contentMode = UIView.ContentMode.center
        
        
        // --- ML & VISION ---
        // Setup Vision Model
        guard let selectedModel = try? VNCoreMLModel(for: MegaManMLCore().model) else {
            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project. Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
        }
        // Set up Vision-CoreML Request
        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
        visionRequests = [classificationRequest]
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    override func didMove(toParent parent: UIViewController?) {
       
    }
    
    
    ///    **********CREATE GAME OBJECTS*******
    
    func makeBat() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let batNode = GameObject(userPosition: position, type: "bat", rotation: rot)
        batNode.delegate = self
        scene.rootNode.addChildNode(batNode)
        playerHealthSingleton.shared.enemies.append(batNode)
    }
    
    func makeRoll() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let rollNode = GameObject(userPosition: position, type: "roll", rotation: rot)
        rollNode.delegate = self
        scene.rootNode.addChildNode(rollNode)
    }
    
    func makeHelm() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let helmNode = GameObject(userPosition: position, type: "helm", rotation: rot)
        helmNode.delegate = self
        scene.rootNode.addChildNode(helmNode)
    }
    
    func spawnStartButton() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let startButtonNode = GameObject(userPosition: position, type: "start", rotation: rot)
        startButtonNode.delegate = self
        scene.rootNode.addChildNode(startButtonNode)
        playerHealthSingleton.shared.menuButtonPresent = true
    }
    
    func spawnLoseButton() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let loseButtonNode = GameObject(userPosition: position, type: "lose", rotation: rot)
        loseButtonNode.delegate = self
        scene.rootNode.addChildNode(loseButtonNode)
        playerHealthSingleton.shared.menuButtonPresent = true
    }
    
    func spawnWinButton() {
        let position = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let winButtonNode = GameObject(userPosition: position, type: "win", rotation: rot)
        winButtonNode.delegate = self
        scene.rootNode.addChildNode(winButtonNode)
        playerHealthSingleton.shared.menuButtonPresent = true
    }
    
    func spawnEnemy() {
        if playerHealthSingleton.shared.menuButtonPresent == false {
            let enemyNum = arc4random_uniform(3)
            if enemyNum == 0 {
                makeBat()
            } else if enemyNum == 1 {
                makeRoll()
            } else {
                makeHelm()
            }
            playerHealthSingleton.shared.enemyCount += 1
    //        print("just spawned an enemy. count is: \(playerHealthSingleton.shared.enemyCount)")
            return
        }
    }
    
    func makeYellowBullet(){
        let pos = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let sphereNode = GameObject(userPosition: pos, type: "yellow_bullet", rotation: rot)
        scene.rootNode.addChildNode(sphereNode)
    }
    
    func makeGreenBullet(){
        let pos = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let sphereNode = GameObject(userPosition: pos, type: "green_bullet", rotation: rot)
        scene.rootNode.addChildNode(sphereNode)
    }
    
    func makeBlueBullet(){
        let pos = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let sphereNode = GameObject(userPosition: pos, type: "blue_bullet",  rotation: rot)
        scene.rootNode.addChildNode(sphereNode)
    }
    
    func makePinkBullet(){
        let pos = sceneView.pointOfView!.position
        let rot = sceneView.pointOfView!.rotation
        let sphereNode = GameObject(userPosition: pos, type: "pink_bullet",  rotation: rot)
        scene.rootNode.addChildNode(sphereNode)
    }
    
    
///    *******DETECT COLLISIONS*********
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        DispatchQueue.main.async {
            if contact.nodeA.name == "yellow_bullet" || contact.nodeB.name == "yellow_bullet" || contact.nodeA.name == "green_bullet" || contact.nodeB.name == "green_bullet" || contact.nodeA.name == "blue_bullet" || contact.nodeB.name == "blue_bullet" || contact.nodeA.name == "pink_bullet" || contact.nodeB.name == "pink_bullet"{
                let position = self.sceneView.pointOfView!.position
                if (contact.nodeA.name == "lose" || contact.nodeB.name == "lose") && (contact.nodeA.name == "blue_bullet" || contact.nodeB.name == "blue_bullet"){
                    contact.nodeB.name = "none"
                    contact.nodeA.name = "none"
                    contact.nodeB.removeFromParentNode()
                    contact.nodeA.removeFromParentNode()
                    playerHealthSingleton.shared.killCount = 0
                    playerHealthSingleton.shared.playerHealth = 100
                    self.HUDLeftHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.HUDRightHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.leftScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    self.rightScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    playerHealthSingleton.shared.menuButtonPresent = false
                    self.spawnEnemy()
                    self.spawnEnemy()
                    return
                }
                if (contact.nodeA.name == "start" || contact.nodeB.name == "start")  && (contact.nodeA.name == "blue_bullet" || contact.nodeB.name == "blue_bullet"){
                    contact.nodeB.name = "none"
                    contact.nodeA.name = "none"
                    self.scene.rootNode.childNode(withName: "start", recursively: true)?.removeFromParentNode()
                    self.scene.rootNode.childNode(withName: "capsuleIntro", recursively: true)?.removeFromParentNode()
                    contact.nodeB.removeFromParentNode()
                    contact.nodeA.removeFromParentNode()
                    playerHealthSingleton.shared.killCount = 0
                    playerHealthSingleton.shared.playerHealth = 100
                    self.HUDLeftHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.HUDRightHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.leftScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    self.rightScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    playerHealthSingleton.shared.menuButtonPresent = false
                    self.spawnEnemy()
                    self.spawnEnemy()
                    return
                }
                if (contact.nodeA.name == "win" || contact.nodeB.name == "win") && (contact.nodeA.name == "blue_bullet" || contact.nodeB.name == "blue_bullet"){
                    contact.nodeB.name = "none"
                    contact.nodeA.name = "none"
                    contact.nodeB.removeFromParentNode()
                    contact.nodeA.removeFromParentNode()
                    playerHealthSingleton.shared.killCount = 0
                    playerHealthSingleton.shared.playerHealth = 100
                    self.HUDLeftHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.HUDRightHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
                    self.leftScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    self.rightScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
                    playerHealthSingleton.shared.menuButtonPresent = false
                    self.spawnEnemy()
                    self.spawnEnemy()
                    return
                }
                if playerHealthSingleton.shared.menuButtonPresent == false {
                    if (contact.nodeA.name == "roll" || contact.nodeA.name == "helm" || contact.nodeA.name == "bat") && (contact.nodeB.name == "yellow_bullet" || contact.nodeB.name == "green_bullet" || contact.nodeB.name == "blue_bullet" || contact.nodeB.name == "pink_bullet"){
    //                    print("\(contact.nodeA.name!) vs. \(contact.nodeB.name!)")
                        let tempNode = contact.nodeA as! GameObject
                        if contact.nodeA.name == "helm" {
                            if tempNode.helmCounter < 8 {
                                contact.nodeB.name = "none"
                                contact.nodeA.name = "none"
                                tempNode.hasBeenHit = true
                                tempNode.tempType = "roll"
                                tempNode.tempPlayerPos = position
                                playerHealthSingleton.shared.killCount += 1
                                self.enemyKilled()
                                if playerHealthSingleton.shared.killCount < 20 {
                                    self.spawnEnemy()
                                }
                            } else {
                                return
                            }
                        } else {
                            contact.nodeB.name = "none"
                            contact.nodeA.name = "none"
                            tempNode.hasBeenHit = true
                            tempNode.tempType = "roll"
                            tempNode.tempPlayerPos = position
                            playerHealthSingleton.shared.killCount += 1
                            self.enemyKilled()
                            if playerHealthSingleton.shared.killCount < 20 {
                                self.spawnEnemy()
                            }
                        }
                    }else if (contact.nodeB.name == "roll" || contact.nodeB.name == "bat" || contact.nodeB.name == "helm") && (contact.nodeA.name == "yellow_bullet" || contact.nodeA.name == "green_bullet" || contact.nodeA.name == "blue_bullet") || contact.nodeA.name == "pink_bullet"{
    //                    print("\(contact.nodeA.name!) vs. \(contact.nodeB.name!)")
                        let tempNode = contact.nodeB as! GameObject
                        if contact.nodeB.name == "helm" {
                            if tempNode.helmCounter < 8 {
                                contact.nodeB.name = "none"
                                contact.nodeA.name = "none"
                                tempNode.hasBeenHit = true
                                tempNode.tempType = "roll"
                                tempNode.tempPlayerPos = position
                                playerHealthSingleton.shared.killCount += 1
                                self.enemyKilled()
                                if playerHealthSingleton.shared.killCount < 20 {
                                    self.spawnEnemy()
                                }
                            } else {
                                return
                            }
                        } else {
                            contact.nodeB.name = "none"
                            contact.nodeA.name = "none"
                            tempNode.hasBeenHit = true
                            tempNode.tempType = "roll"
                            tempNode.tempPlayerPos = position
                            playerHealthSingleton.shared.killCount += 1
                            self.enemyKilled()
                            if playerHealthSingleton.shared.killCount < 20 {
                                self.spawnEnemy()
                            }
                        }
                    }
                }
            }
        }
    }
    
///    ********UPGRADED BLASTER*******
    
    func getUpgradedBlaster(){
        print("I'M IN THE GETUPGRADEDBLASTER FUNCTION")
        let capsule = GameObject(userPosition: sceneView.pointOfView!.position, type: "capsule", rotation: scene.rootNode.rotation)
        let floor = GameObject(userPosition: sceneView.pointOfView!.position, type: "floor", rotation: sceneView.pointOfView!.rotation)
        scene.rootNode.addChildNode(floor)
        scene.rootNode.addChildNode(capsule)
    }
    
    func capsuleIntro(){

        let position = SCNVector3(x: (playerHealthSingleton.shared.capsulePosition!.x), y: ((playerHealthSingleton.shared.capsulePosition!.y)), z: ((playerHealthSingleton.shared.capsulePosition!.z) + 1))
        let introNode = GameObject(userPosition: position, type: "capsuleIntro", rotation: scene.rootNode.rotation)
        scene.rootNode.addChildNode(introNode)
        self.hasIntroRun = true
    }
    
    func runUpgradeBlasterAnimation(){

        self.playHaduoken()
        
        let introNode = self.scene.rootNode.childNode(withName: "capsuleIntro", recursively: false)
        print("INTRO NODE AFTER IS:", introNode)
        introNode?.geometry = nil
        introNode?.isHidden = true
        introNode?.opacity = 0.0
        introNode?.removeFromParentNode()
        
        
        print("INTRO NODE BEFORE IS:", self.scene.rootNode.childNode(withName: "capsuleIntro", recursively: true))
        self.scene.rootNode.childNode(withName: "capsule", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "capsuleIntro", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "floor", recursively: true)?.removeFromParentNode()
        
        
        
        self.hasUpgradedBlaster = true
        playerHealthSingleton.shared.playerHealth = 100
        playerHealthSingleton.shared.menuButtonPresent = false
        spawnStartButton()
    }
    
    
    
    
    
///    ********SOUND EFFECTS**********
    
    func playTheme() {
        guard let url = Bundle.main.url(forResource: "themeMusic", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            themePlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = themePlayer else { return }
            themePlayer?.volume = 0.2
            player.play()
        } catch {
            //            print(error.localizedDescription)
        }
    }
    
    func playYellow() {
        guard let url = Bundle.main.url(forResource: "yellow", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            bulletPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = bulletPlayer else { return }
            player.play()
        } catch {
//            print(error.localizedDescription)
        }
    }
    
    func playGreen() {
        guard let url = Bundle.main.url(forResource: "green", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            bulletPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = bulletPlayer else { return }
            player.play()
        } catch {
//            print(error.localizedDescription)
        }
    }
    
    func playBlue() {
        guard let url = Bundle.main.url(forResource: "blue", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            bulletPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = bulletPlayer else { return }
            player.play()
        } catch {
//            print(error.localizedDescription)
        }
    }
    
    func playCharging() {
        guard let url = Bundle.main.url(forResource: "charging", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            chargingPlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = chargingPlayer else { return }
            player.prepareToPlay()
            player.play()
        } catch {
//            print(error.localizedDescription)
        }
    }
    
    func playExplode() {
        guard let url = Bundle.main.url(forResource: "die", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            explodePlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = explodePlayer else { return }
            player.play()
        } catch {
            //            print(error.localizedDescription)
        }
    }
    
    func playHaduoken() {
        guard let url = Bundle.main.url(forResource: "haduoken", withExtension: "wav") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(convertFromAVAudioSessionCategory(AVAudioSession.Category.playback))
            try AVAudioSession.sharedInstance().setActive(true)
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            explodePlayer = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            guard let player = explodePlayer else { return }
            player.play()
        } catch {
            //            print(error.localizedDescription)
        }
    }
    

    ///   *********ADDITIONAL FUNCTIONS***********
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateFrame()
        }
    }
    
    func updateFrame() {
        /////////////////////////////////////////////
        // CREATE POINT OF VIEWS
        let pointOfView : SCNNode = SCNNode()
        pointOfView.transform = (sceneView.pointOfView?.transform)!
        pointOfView.scale = (sceneView.pointOfView?.scale)!
        // Create POV from Camera
        pointOfView.camera = eyeCamera
        
        // Set PointOfView for SceneView-LeftEye
        sceneViewLeft.pointOfView = pointOfView
        
        // Clone pointOfView for Right-Eye SceneView
        let pointOfView2 : SCNNode = (sceneViewLeft.pointOfView?.clone())!
        // Determine Adjusted Position for Right Eye
        let orientation : SCNQuaternion = pointOfView.orientation
        let orientationQuaternion : GLKQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
        let eyePos : GLKVector3 = GLKVector3Make(1.0, 0.0, 0.0)
        let rotatedEyePos : GLKVector3 = GLKQuaternionRotateVector3(orientationQuaternion, eyePos)
        let rotatedEyePosSCNV : SCNVector3 = SCNVector3Make(rotatedEyePos.x, rotatedEyePos.y, rotatedEyePos.z)
        let mag : Float = Float(interpupilaryDistance)
        pointOfView2.position.x += rotatedEyePosSCNV.x * mag
        pointOfView2.position.y += rotatedEyePosSCNV.y * mag
        pointOfView2.position.z += rotatedEyePosSCNV.z * mag
        
        // Set PointOfView for SceneView-RightEye
        sceneViewRight.pointOfView = pointOfView2
        
        ////////////////////////////////////////////
        // RENDER CAMERA IMAGE
        /*
         Note:
         - as camera.contentsTransform doesn't appear to affect the camera-image at the current time, we are re-rendering the image.
         - for performance, this should ideally be ported to metal
         */
        // Clear Original Camera-Image
        sceneViewLeft.scene.background.contents = UIColor.clear // This sets a transparent scene bg for all sceneViews - as they're all rendering the same scene.
        
        // Read Camera-Image
        let pixelBuffer : CVPixelBuffer? = sceneView.session.currentFrame?.capturedImage
        if pixelBuffer == nil { return }
        let ciimage = CIImage(cvPixelBuffer: pixelBuffer!)
        // Convert ciimage to cgimage, so uiimage can affect its orientation
        let context = CIContext(options: nil)
        let cgimage = context.createCGImage(ciimage, from: ciimage.extent)
        
        // Determine Camera-Image Scale
        var scale_custom : CGFloat = 1.0
        // let cameraImageSize : CGSize = CGSize(width: ciimage.extent.width, height: ciimage.extent.height) // 1280 x 720 on iPhone 7+
        // let eyeViewSize : CGSize = CGSize(width: self.view.bounds.width / 2, height: self.view.bounds.height) // (736/2) x 414 on iPhone 7+
        // let scale_aspectFill : CGFloat = cameraImageSize.height / eyeViewSize.height // 1.739 // fov = ~38.5 (guestimate on iPhone7+)
        // let scale_aspectFit : CGFloat = cameraImageSize.width / eyeViewSize.width // 3.478 // fov = ~60
        // scale_custom = 8.756 // (8.756) ~ appears close to 120° FOV - (guestimate on iPhone7+)
        // scale_custom = 6 // (6±1) ~ appears close-ish to 90° FOV - (guestimate on iPhone7+)
        scale_custom = CGFloat(cameraImageScale)
        
        // Determine Camera-Image Orientation
        let imageOrientation : UIImage.Orientation = (UIApplication.shared.statusBarOrientation == UIInterfaceOrientation.landscapeLeft) ? UIImage.Orientation.down : UIImage.Orientation.up
        
        // Display Camera-Image
        let uiimage = UIImage(cgImage: cgimage!, scale: scale_custom, orientation: imageOrientation)
        self.imageViewLeft.image = uiimage
        self.imageViewRight.image = uiimage
    }

    
//    Put animation updates here probably
//    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
//        DispatchQueue.main.async {
//            // Do any desired updates to SceneKit here.
//        }
//    }

    // MARK: - MACHINE LEARNING

    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
    }

    func updateCoreML() {
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // Run Vision Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
//            print(error)
        }
    }

    func classificationCompleteHandler(request: VNRequest, error: Error?) {
        // Catch Errors
        if error != nil {
//            print("Error: " + (error?.localizedDescription)!)
            return
        }
        guard let observations = request.results else {
//            print("No results")
            return
        }
        
        
        
        // Get Classifications
        let classifications = observations[0...2] // top 3 results
            .compactMap({ $0 as? VNClassificationObservation })
            .map({ "\($0.identifier) \(String(format:" : %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        // Render Classifications
        DispatchQueue.main.async {

            let topPrediction = classifications.components(separatedBy: "\n")[0]
            let topPredictionName = topPrediction.components(separatedBy: ":")[0].trimmingCharacters(in: .whitespaces)
            let topPredictionScore:Float? = Float(topPrediction.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces))
            if (topPredictionScore != nil && topPredictionScore! > 0.85) {
                if (topPredictionName == "blueSide") {
                    self.shotCounter = self.shotCounter + 1
                    if self.shotCounter > 40 {
                        self.makeYellowBullet()
                        self.isChargingSFX = false
                        self.chargingPlayer?.stop()
                        self.playYellow()
                        self.shotCounter = 0
                    }
                }else if (topPredictionName == "yellowSide") {
                    if self.chargeCounter > 10{
                        if self.isChargingSFX == false {
                            self.isChargingSFX = true
                            self.playCharging()
                        }
                    }
                    self.shotCounter = 0
                    self.chargeCounter = self.chargeCounter + 1
                }else{
                    self.shotCounter = 0
                    self.chargeCounter = 0
                    self.leftChargeIV.image = nil
                    self.rightChargeIV.image = nil
                }
                
                
                if self.chargeCounter > 190 && self.hasUpgradedBlaster == true && self.shotCounter > 1{
                    self.makePinkBullet()
                    self.leftChargeIV.image = nil
                    self.rightChargeIV.image = nil
                    self.orbCounter = 0
                    self.isChargingSFX = false
                    self.chargingPlayer?.stop()
                    self.playBlue()
                    self.chargeCounter = 0
                }else if self.chargeCounter > 140 && self.shotCounter > 1{
                    self.makeBlueBullet()
                    self.leftChargeIV.image = nil
                    self.rightChargeIV.image = nil
                    self.orbCounter = 0
                    self.isChargingSFX = false
                    self.chargingPlayer?.stop()
                    self.playBlue()
                    self.chargeCounter = 0
                }else if self.chargeCounter > 90 && self.shotCounter > 1{
                    self.makeGreenBullet()
                    self.leftChargeIV.image = nil
                    self.rightChargeIV.image = nil
                     self.orbCounter = 0
                    self.isChargingSFX = false
                    self.chargingPlayer?.stop()
                    self.playGreen()
                    self.chargeCounter = 0
                }
                
                if self.hasUpgradedBlaster == false{
                    if let capsule = playerHealthSingleton.shared.capsulePosition{
                        if (capsule.z - (self.sceneView.pointOfView?.position.z)!) > -3.5 {
                            if self.hasIntroRun == false{
                                 self.capsuleIntro()
                            }
                        }
                        playerHealthSingleton.shared.menuButtonPresent = true
                    }
                }
                
                if self.hasUpgradedBlaster == false{
                    if let capsule = playerHealthSingleton.shared.capsulePosition{
                        if (capsule.z - (self.sceneView.pointOfView?.position.z)!) > -0.5  {
                            self.runUpgradeBlasterAnimation()
                        }
                        playerHealthSingleton.shared.menuButtonPresent = true
                    }
                }
            }
        }
    }
    
    @objc func updateOrbImage(){
        if chargeCounter >= 190 && hasUpgradedBlaster == true {
            let porb = "porb_\(orbCounter)"
            leftChargeIV.image = UIImage(named: porb)
            rightChargeIV.image = UIImage(named: porb)
            if orbCounter <= 9{
                orbCounter += 1
            }else{
                orbCounter = 0
            }
        }else if chargeCounter >= 140{
            let borb = "orb_\(orbCounter)"
            leftChargeIV.image = UIImage(named: borb)
            rightChargeIV.image = UIImage(named: borb)
            if orbCounter <= 9{
                orbCounter += 1
            }else{
                orbCounter = 0
            }
        }else if chargeCounter > 90 && chargeCounter < 140{
            let gorb = "gorb_\(orbCounter)"
            leftChargeIV.image = UIImage(named: gorb)
            rightChargeIV.image = UIImage(named: gorb)
            if orbCounter <= 9{
                orbCounter += 1
            }else{
                orbCounter = 0
            }
        }
    }
    
    
    func removeAllNodes(){
        self.scene.rootNode.childNode(withName: "none", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "yellow_bullet", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "green_bullet", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "blue_bullet", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "pink_bullet", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "bat", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "roll", recursively: true)?.removeFromParentNode()
        self.scene.rootNode.childNode(withName: "helm", recursively: true)?.removeFromParentNode()
    }
    
    
    
    
    // MARK: - HIDE STATUS BAR
    override var prefersStatusBarHidden : Bool { return true }
}

extension ViewController: EnemyDelegate {
    func hurtPlayer(){
        print("health", playerHealthSingleton.shared.playerHealth)
        HUDLeftHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
        HUDRightHPView.image = UIImage(named: "hp_\(playerHealthSingleton.shared.playerHealth)")
        if playerHealthSingleton.shared.playerHealth <= 0 {
            removeAllNodes()
            spawnLoseButton()
            return
        }
        spawnEnemy()
    }
    
    func enemyKilled() {
        leftScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
        rightScoreHUDLabel.text = "\(playerHealthSingleton.shared.killCount)"
        
//        if playerHealthSingleton.shared.killCount >= 20 {
//            removeAllNodes()
//            spawnWinButton()
//            return
//        }
        
        
        if playerHealthSingleton.shared.killCount == 10 {
            if hasUpgradedBlaster == false{
                removeAllNodes()
                getUpgradedBlaster()
                }else{
                removeAllNodes()
                spawnWinButton()
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
