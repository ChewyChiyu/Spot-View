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
    
    var firebaseMasterBranch = Database.database().reference()
    
    var isConnected: Bool = false
    var isLaunching: Bool = true
    
    var addTableButton: Button?
    var addChairButton: Button?
    var removeFurnitureBin: SKSpriteNode?
    var gameCamera: SKCameraNode?
    
    var currentlySelectedNode: Furniture?
    
    override func didMove(to view: SKView) {
        addTableButton = self.childNode(withName: "addTable") as? Button
        addChairButton = self.childNode(withName: "addChair") as? Button
        removeFurnitureBin = self.childNode(withName: "removeFurniture") as? SKSpriteNode
        gameCamera = self.childNode(withName: "camera") as? SKCameraNode
        self.camera = gameCamera
        observeFirebaseConnection{ [weak self] in
            self?.loadDataFromFirebase{ [weak self] in
                self?.isLaunching = false
                self?.startObservers()
                self?.addButtonActions()
            }
        }
    }
    
    func loadDataFromFirebase(andOnCompletion completion:@escaping ()->()){
        if !isConnected { completion() }
        firebaseMasterBranch.observeSingleEvent(of: .value, with: { snapshot in
            if !snapshot.exists() { completion() }
            let enumerator = snapshot.children
            while let rest = enumerator.nextObject() as? DataSnapshot {
                var reloadPackage = DataPackage<Any>()
                func fetchData(andOnCompletion completion:@escaping ()->()){
                    reloadPackage.position = Position(x: rest.childSnapshot(forPath: "positionX").value!, y: rest.childSnapshot(forPath: "positionY").value!)
                    reloadPackage.isGreen = rest.childSnapshot(forPath: "isGreen").value as? Bool
                    reloadPackage.furnitureType = rest.childSnapshot(forPath: "furnitureType").value as? String
                    reloadPackage.parentFurnitureID = rest.childSnapshot(forPath: "parentTableID").value as? String
                    completion()
                }
                fetchData{
                    let reloadedFurniture = Furniture(position: reloadPackage.compressPosition(), id: rest.key, type: reloadPackage.furnitureType!)
                    reloadedFurniture.toFlipState()
                    if(reloadedFurniture.type == "CHAIR"){
                        reloadedFurniture.parentTableID = reloadPackage.parentFurnitureID
                    }
                    self.addChild(reloadedFurniture)
                }
            }
            completion()
        })
        
    }
    
    func observeFirebaseConnection(andOnCompletion completion:@escaping ()->()){
        let connectedRef = Database.database().reference(withPath: ".info/connected")
        connectedRef.observe(.value, with: { (connected) in
            if let boolean = connected.value as? Bool, boolean == true {
                self.isConnected = true
                self.reloadAllColors()
                guard self.isLaunching else { return }
                completion()
            } else {
                self.isConnected = false
                self.turnAllNodesGrey()
                guard self.isLaunching else { return }
                completion()
            }
        })
        
    }
    
    func startObservers(){
        guard isConnected else { return }
        firebaseMasterBranch.observe(.value, with: {snapshot in
            guard self.isConnected else { return }
            guard snapshot.exists() else{ return }
            let enumerations = snapshot.children
            var dataIDs = [String]()
            while let rest = enumerations.nextObject() as? DataSnapshot{
                var newPackage = DataPackage<Any>()
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
                    if self.validPackage(data: newPackage){
                        var furnitureExists: Bool = false
                        for childNode in self.children{
                            let child = childNode as? Furniture
                            if(child?.id == newPackage.keyID){
                                furnitureExists = true
                                if(child?.isGreen != newPackage.isGreen){
                                    child?.toFlipState()
                                }
                                child?.position = newPackage.compressPosition()
                                child?.type = newPackage.furnitureType
                                if(child?.type == "CHAIR"){
                                    child?.parentTableID = newPackage.parentFurnitureID
                                }
                            }
                        }
                        if(!furnitureExists){
                            let newFurniture = Furniture(position: newPackage.compressPosition(), id: newPackage.keyID!, type: newPackage.furnitureType!)
                            newFurniture.toFlipState()
                            if(newFurniture.type == "CHAIR"){
                                newFurniture.parentTableID = newPackage.parentFurnitureID
                            }
                            self.addChild(newFurniture)
                        }
                    }
                }
            }
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
        guard data.isGreen != nil else { return false }
        guard data.position != nil else { return false }
        guard data.keyID != nil else { return false }
        guard data.furnitureType != nil else { return false }
        return true
    }
    
    
    func addButtonActions(){
        addTableButton?.playAction = { [weak self] in
            if (self?.isConnected)! {
                let table = Furniture(position: (self?.addTableButton?.position)!, id: "TABLE-\(String(Date().toMillis()))", type: "TABLE")
                table.colorBlendFactor = 0
                self?.addChild(table)
            }
        }
        addChairButton?.playAction = { [weak self] in
            if (self?.isConnected)! {
                let chair = Furniture(position: (self?.addChairButton?.position)!, id: "CHAIR-\(String(Date().toMillis()))", type: "CHAIR")
                chair.colorBlendFactor = 0
                self?.addChild(chair)
            }
        }
    }
    
    func turnAllNodesGrey(){
        for child in self.children{
            if let tableNode = child as? Furniture{
                tableNode.color = UIColor.gray
            }
        }
    }
    
    func reloadAllColors(){
        for child in self.children{
            if let tableNode = child as? Furniture{
                tableNode.color = (tableNode.isGreen)! ? UIColor.green : UIColor.red
            }
        }
    }
    
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        currentlySelectedNode = atPoint(touches.first!.location(in: self)) as? Furniture
        currentlySelectedNode?.toFlipState()
        guard currentlySelectedNode?.type == "TABLE" else { return }
        for allFurniture in self.children{
            if let furnitureNode = allFurniture as? Furniture{
                if(furnitureNode.parentTableID == currentlySelectedNode?.id && furnitureNode != currentlySelectedNode){
                    furnitureNode.isGreen = ((currentlySelectedNode?.isGreen)!)
                    furnitureNode.color = (furnitureNode.isGreen)! ? UIColor.green : UIColor.red
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        if let currentNode = currentlySelectedNode{
            currentNode.position = touches.first!.location(in: self)
        }else{
            gameCamera?.run(SKAction.move(to: (touches.first?.location(in: gameCamera!))!, duration: 0.1))
            gameCamera?.run(SKAction.moveBy(x: (touches.first?.location(in: gameCamera!).x)! * -0.1, y: (touches.first?.location(in: gameCamera!).y)!*0.1, duration: 0.1))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        guard let furniture = currentlySelectedNode else { return }
        if nodes(at: (touches.first?.location(in: self))!).contains(removeFurnitureBin!){
            firebaseMasterBranch.child((furniture.id)!).removeValue()
            firebaseMasterBranch.child("reload").setValue("reload")
            furniture.removeFromParent()
        }else{
            
            if let possibleTable = nodes(at: (touches.first?.location(in: self))!).last as? Furniture{
                if (furniture.type == "CHAIR" && possibleTable.type != "TABLE"){
                    if(furniture.parentTableID == nil){
                        furniture.removeFromParent()
                        return
                    }
                }else{
                    if(possibleTable.type == "TABLE"){
                        furniture.parentTableID = possibleTable.id
                    }
                }
            }
            
            
            furniture.colorBlendFactor = 1
            let newFurnitureBranch = firebaseMasterBranch.child((furniture.id)!)
            newFurnitureBranch.child("positionX").setValue(furniture.position.x)
            newFurnitureBranch.child("positionY").setValue(furniture.position.y)
            newFurnitureBranch.child("isGreen").setValue(furniture.isGreen)
            newFurnitureBranch.child("furnitureType").setValue(furniture.type)
            if(furniture.type == "CHAIR"){
                newFurnitureBranch.child("parentTableID").setValue(furniture.parentTableID)
            }
            if(furniture.type == "TABLE"){
                for possibleChair in self.children{
                    if let chair = possibleChair as? Furniture{
                        if(chair.parentTableID == currentlySelectedNode?.id){
                            let chairBranch = firebaseMasterBranch.child(chair.id!)
                            chairBranch.child("isGreen").setValue(chair.isGreen)
                        }
                    }
                }
            }
        }
    }
}


extension Date {
    func toMillis() -> Int64! {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

struct DataPackage<T>{
    var isGreen: Bool?
    var position: Position<T>?
    var keyID: String?
    var furnitureType: String?
    var parentFurnitureID: String?
    
    func compressPosition() -> CGPoint{
        guard position?.x != nil, let x = position?.x as? CGFloat else { return CGPoint.zero }
        guard position?.y != nil, let y = position?.y as? CGFloat else { return CGPoint.zero }
        return CGPoint(x: x,y: y)
    }
}

class Position<T>{
    var x: T?
    var y: T?
    init(x: T, y: T){
        self.x = x
        self.y = y
    }
}


class Furniture : SKSpriteNode{
    
    var isGreen: Bool?
    var id : String?
    var type: String?
    var parentTableID: String?
    
    init(position: CGPoint, id: String, type: String){
        super.init(texture: SKTexture(imageNamed: "Square"), color: UIColor.clear, size: SKTexture(imageNamed: "Square").size())
        switch(type){
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
    
    
    
    func toFlipState(){
        isGreen = !isGreen!
        self.color = (isGreen)! ? UIColor.green : UIColor.red
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
