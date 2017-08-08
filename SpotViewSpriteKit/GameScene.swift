//
//  GameScene.swift
//  SpotViewSpriteKit
//
//  Created by Evan Chen on 7/31/17.
//  Copyright © 2017 Evan Chen. All rights reserved.
//

import SpriteKit
import GameplayKit
import Firebase
import FirebaseDatabase
class GameScene: SKScene {
    
    //MARK: GLOBAL VARIABLES
    
    var firebaseMasterBranch = Database.database().reference()
    
    var isConnected: Bool = false
    var isLaunching: Bool = true
    
    var selectMenu : SKSpriteNode?
    var addTableButton: Button?
    var addChairButton: Button?
    var removeFurnitureBin: SKSpriteNode?
    var gameCamera: SKCameraNode?
    
    var currentlySelectedNode: Furniture?
    var moveTouch = CGPoint.zero
    
    override func didMove(to view: SKView) {
        //MARK: Construct objects from editor
        gameCamera = self.childNode(withName: "camera") as? SKCameraNode
        selectMenu = gameCamera?.childNode(withName: "SelectMenu") as? SKSpriteNode
        addTableButton = selectMenu?.childNode(withName: "addTable") as? Button
        addChairButton = selectMenu?.childNode(withName: "addChair") as? Button
        removeFurnitureBin = gameCamera?.childNode(withName: "removeFurniture") as? SKSpriteNode
        self.camera = gameCamera
        //Starting observers in order of (Continuous Connection) -> (Once Load) -> (Continuous Push)
        observeFirebaseConnection{ [weak self] in
            self?.loadDataFromFirebase{ [weak self] in
                self?.isLaunching = false
                self?.startObservers()
                self?.addButtonActions()
            }
        }
    }
    
    func loadDataFromFirebase(andOnCompletion completion:@escaping ()->()){
        if !isConnected { completion() } //guard if not connected
        //One time database observe
        firebaseMasterBranch.observeSingleEvent(of: .value, with: { snapshot in
            if !snapshot.exists() { completion() } //guard if no data
            let enumerator = snapshot.children
            while let rest = enumerator.nextObject() as? DataSnapshot {
                //Iteration through all child branches in firebaseMasterBranch
                var reloadPackage = DataPackage<Any>() //packing data
                func fetchData(andOnCompletion completion:@escaping ()->()){
                    reloadPackage.position = Position(x: rest.childSnapshot(forPath: "positionX").value!, y: rest.childSnapshot(forPath: "positionY").value!)
                    reloadPackage.isGreen = rest.childSnapshot(forPath: "isGreen").value as? Bool
                    reloadPackage.furnitureType = rest.childSnapshot(forPath: "furnitureType").value as? String
                    reloadPackage.parentFurnitureID = rest.childSnapshot(forPath: "parentTableID").value as? String
                    completion()
                }
                fetchData{
                    //continue with this code after fetchData has gone to completion
                    if self.validPackage(data: reloadPackage){ //checking if package has correct values
                        
                        //reloading data form reloadPackage
                        let reloadedFurniture = Furniture(position: reloadPackage.compressPosition(), id: rest.key, type: reloadPackage.furnitureType!)
                        reloadedFurniture.toFlipState(toGreen: reloadPackage.isGreen!)
                        if(reloadedFurniture.type == "CHAIR"){
                            //special instance if type "CHAIR"
                            reloadedFurniture.parentTableID = reloadPackage.parentFurnitureID
                        }
                        //adding reloadedFurniture to scene
                        self.addChild(reloadedFurniture)
                    }
                }
            }
            //returning back flow control, proceed
            completion()
        })
        
    }
    
    func observeFirebaseConnection(andOnCompletion completion:@escaping ()->()){
        //checking if connected to firebase at all times. Continuous observe
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value, with: { (connected) in
            if let boolean = connected.value as? Bool, boolean == true {
                self.isConnected = true
                self.reloadAllColors()
                guard self.isLaunching else { return } //just launched guard
                completion()
            } else {
                self.isConnected = false
                self.turnAllNodesGrey()
                guard self.isLaunching else { return } //just launched guard
                completion()
            }
        })
        
    }
    
    func startObservers(){ //continuous observe of firebase
        guard isConnected else { return } //guard if not connected
        firebaseMasterBranch.observe(.value, with: {snapshot in
            guard self.isConnected else { return } //guard if not connected
            guard snapshot.exists() else{ return } //guard if no data
            let enumerations = snapshot.children
            var dataIDs = [String]() //Array of all object IDs
            while let rest = enumerations.nextObject() as? DataSnapshot{
                var newPackage = DataPackage<Any>() //loading datapackage
                func fetchData(andOnCompletion completion:@escaping ()->()){
                    dataIDs.append(rest.key)
                    newPackage.keyID = rest.key
                    newPackage.isGreen = rest.childSnapshot(forPath: "isGreen").value as? Bool
                    newPackage.furnitureType = rest.childSnapshot(forPath: "furnitureType").value as? String
                    newPackage.position =  Position(x: rest.childSnapshot(forPath: "positionX").value!, y: rest.childSnapshot(forPath: "positionY").value!)
                    newPackage.parentFurnitureID = rest.childSnapshot(forPath: "parentTableID").value as? String
                    completion()
                }
                fetchData{
                    //running this code after data has been packaged
                    if self.validPackage(data: newPackage){ //checking if package has correct values
                        var furnitureExists: Bool = false
                        for childNode in self.children{ //iteration through all children
                            let child = childNode as? Furniture
                            //optional casting to Furniture
                            if(child?.id == newPackage.keyID){
                                //instance of child is already on client, applying data from package into visible object
                                furnitureExists = true
                                if(child?.isGreen != newPackage.isGreen){
                                    child?.toFlipState(toGreen: newPackage.isGreen!)
                                }
                                child?.position = newPackage.compressPosition()
                                child?.type = newPackage.furnitureType
                                if(child?.type == "CHAIR"){
                                    child?.parentTableID = newPackage.parentFurnitureID
                                }
                            }
                        }
                        if(!furnitureExists){
                            //instance of child is not on client, applying new data from package onto new object
                            let newFurniture = Furniture(position: newPackage.compressPosition(), id: newPackage.keyID!, type: newPackage.furnitureType!)
                            newFurniture.toFlipState(toGreen: newPackage.isGreen!)
                            if(newFurniture.type == "CHAIR"){
                                newFurniture.parentTableID = newPackage.parentFurnitureID
                            }
                            self.addChild(newFurniture)
                        }
                    }
                }
            }
            //checking for object removal if exists on client but not in dataIDs
            for childNode in self.children{
                let child = childNode as? Furniture
                var furnitureExists: Bool = false
                for dataID in dataIDs{
                    if(child?.id==dataID){
                        furnitureExists = true
                    }
                }
                if(!furnitureExists){
                    child?.removeFromParent()
                }
            }
        })
    }
    
    func validPackage<T>(data: DataPackage<T>) -> Bool{
        //reutrns a bool checking if dataPackage has met the minimal requirements
        guard data.furnitureType != nil && data.keyID != nil && data.position != nil && data.isGreen != nil else { return false }
        return true
    }
    
    
    func addButtonActions(){
        //Button actions, closures
        addTableButton?.playAction = { [weak self] in
            if (self?.isConnected)! {
                let table = Furniture(position: (self?.addTableButton?.position)!, id: "TABLE-\(String(Date().toMillis()))", type: "TABLE")
                table.colorBlendFactor = 0
                self?.addChild(table)
                table.position = (self?.selectMenu?.position)!
            }
        }
        addChairButton?.playAction = { [weak self] in
            if (self?.isConnected)! {
                let chair = Furniture(position: (self?.addChairButton?.position)!, id: "CHAIR-\(String(Date().toMillis()))", type: "CHAIR")
                chair.colorBlendFactor = 0
                self?.addChild(chair)
                chair.position = (self?.selectMenu?.position)!
            }
        }
    }
    //function for isConnected = false
    func turnAllNodesGrey(){
        //turn all children (Furniture) gray
        for child in self.children{
            if let tableNode = child as? Furniture{
                tableNode.color = UIColor.gray
            }
        }
    }
    
    //function for isConnected = true
    func reloadAllColors(){
        //refreshing colors
        for child in self.children{
            if let tableNode = child as? Furniture{
                tableNode.color = (tableNode.isGreen)! ? UIColor.green : UIColor.red
            }
        }
    }
    
    //MARK: User Input
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return } //guard if connected to firebase
        //assigning start touch variable
        moveTouch = (touches.first?.location(in: self))!
        //applying SKNode object from point
        currentlySelectedNode = atPoint(touches.first!.location(in: self)) as? Furniture
        currentlySelectedNode?.toFlipState(toGreen: !(currentlySelectedNode?.isGreen)!) //flip furniture object if exists
        guard currentlySelectedNode?.type == "TABLE" else { return } //proceed with code only if type "TABLE"
        for allFurniture in self.children{ //iteration through all furniture objects
            if let furnitureNode = allFurniture as? Furniture{ //checking if type table has any children of type "CHAIR", flip if true
                if(furnitureNode.parentTableID == currentlySelectedNode?.id && furnitureNode != currentlySelectedNode){
                    furnitureNode.isGreen = ((currentlySelectedNode?.isGreen)!)
                    furnitureNode.color = (furnitureNode.isGreen)! ? UIColor.green : UIColor.red
                    //removing and adding chair to table for snap movement
                    let newPos = self.convert(furnitureNode.position, to: currentlySelectedNode!)
                    furnitureNode.removeFromParent()
                    currentlySelectedNode?.addChild(furnitureNode)
                    furnitureNode.position = newPos
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return } //guard for firebase connection
        //if node is selected move it, if not move camera
        if let currentNode = currentlySelectedNode{
            let currentTouch = touches.first?.location(in: self)
            if(currentTouch != moveTouch){
                currentNode.position = touches.first!.location(in: self)
            }
            moveTouch = currentTouch!
        }else{
            gameCamera?.run(SKAction.move(to: (touches.first?.location(in: gameCamera!))!, duration: 0.1))
            gameCamera?.run(SKAction.moveBy(x: (touches.first?.location(in: gameCamera!).x)! * -0.1, y: (touches.first?.location(in: gameCamera!).y)!*0.1, duration: 0.1))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return } //guard for firebase connection
        guard let furniture = currentlySelectedNode else { return } //guard for invalid release
        
        //Taking camera movement in account
        //checking ot see if node was dragged into trash bin
        if nodes(at: (touches.first?.location(in: self))!).contains(removeFurnitureBin!){
            firebaseMasterBranch.child((furniture.id)!).removeValue()
            firebaseMasterBranch.child("reload").setValue("reload")
            furniture.removeFromParent()
        }else{
            //checking if node was chair, if yes remove if not initialized properly
            var possibleTable : Furniture?
            for i in  nodes(at: (touches.first?.location(in: self))!){
                if let i2 = i as? Furniture{
                    if(i2.type == "TABLE"){
                        possibleTable = i2
                        break
                    }
                }
            }
            if possibleTable != nil{
                //checking to see if just dropped node is of type "CHAIR" onto "TABLE"
                //checking if "TABLE" for removal and re adding of chairs onto scene
                if (furniture.type == "TABLE"){
                    for chairReload in furniture.children{
                        if let chairNode = chairReload as? Furniture{
                            let newPos = furniture.convert(chairNode.position, to: self)
                            chairNode.removeFromParent()
                            chairNode.position = newPos
                            self.addChild(chairNode)
                        }
                    }
                }
                
                if(possibleTable?.type == "TABLE"){
                    //if chair exists, apply to new table
                    furniture.parentTableID = possibleTable?.id
                }
            }
            
            //applying new Data onto firebase
            furniture.colorBlendFactor = 1
            let newFurnitureBranch = firebaseMasterBranch.child((furniture.id)!)
            newFurnitureBranch.child("positionX").setValue(furniture.position.x)
            newFurnitureBranch.child("positionY").setValue(furniture.position.y)
            newFurnitureBranch.child("isGreen").setValue(furniture.isGreen)
            newFurnitureBranch.child("furnitureType").setValue(furniture.type)
            if(furniture.type == "CHAIR"){
                newFurnitureBranch.child("parentTableID").setValue(furniture.parentTableID)
            }
            if(furniture.type == "TABLE"){ //If type "TABLE", also load new information from chairs
                for possibleChair in self.children{
                    if let chair = possibleChair as? Furniture{
                        if(chair.parentTableID == currentlySelectedNode?.id){
                            let chairBranch = firebaseMasterBranch.child(chair.id!)
                            chairBranch.child("isGreen").setValue(chair.isGreen)
                            chairBranch.child("positionX").setValue(chair.position.x)
                            chairBranch.child("positionY").setValue(chair.position.y)
                        }
                    }
                }
            }
        }
    }
}

//MARK: Date
extension Date { //extention for Time Stamp
    func toMillis() -> Int64! {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

//MARK: DataPackage
struct DataPackage<T>{ //Package Specific for Spot View
    var isGreen: Bool?
    var position: Position<T>?
    var keyID: String?
    var furnitureType: String?
    var parentFurnitureID: String?
    
    func compressPosition() -> CGPoint{ //Translating generic position to CGPoint
        guard position?.x != nil, let x = position?.x as? CGFloat else { return CGPoint.zero }
        guard position?.y != nil, let y = position?.y as? CGFloat else { return CGPoint.zero }
        return CGPoint(x: x,y: y)
    }
}


//MARK: Position
class Position<T>{ //generic position class
    var x: T?
    var y: T?
    init(x: T, y: T){
        self.x = x
        self.y = y
    }
}

//MARK: Furniture

class Furniture : SKSpriteNode{ //Main Object of Spot View
    
    var isGreen: Bool?
    var id : String?
    var type: String?
    var parentTableID: String?
    
    init(position: CGPoint, id: String, type: String){
        var selfTexture = SKTexture()
        switch(type){
        case "TABLE":
            selfTexture = SKTexture(imageNamed: "icons8-Table-64")
            break
        case "CHAIR":
            selfTexture = SKTexture(imageNamed: "icons8-Chair-64")
            break
        default:
            break
        }
        super.init(texture: selfTexture, color: UIColor.clear, size: selfTexture.size())
        switch(type){ //specific to types
        case "TABLE":
            self.size = CGSize(width: 50, height: 50)
            self.zPosition = 1
            break
        case "CHAIR":
            self.size = CGSize(width: 30, height: 30)
            self.zPosition = 2
            break
        default:
            break
        }
        self.colorBlendFactor =  1
        self.isGreen = true
        self.id = id
        self.type = type
        self.position = position
    }
    
    
    func toFlipState(toGreen: Bool){ //flipping bool to assigned color
        func green(){
            isGreen = true
            self.color = UIColor.green
        }
        
        func red(){
            isGreen = false
            self.color = UIColor.red
        }
        _ = (toGreen) ? green() : red()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
