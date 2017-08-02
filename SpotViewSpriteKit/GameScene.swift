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
    
    var addTableButton: Button?
    
    var currentlySelectedNode: Table?
    
    
    
    override func didMove(to view: SKView) {
        addTableButton = self.childNode(withName: "addTable") as? Button
        observeFirebaseConnection{ [weak self] in
            self?.loadDataFromFirebase{ [weak self] in
                self?.startObservers()
                self?.addButtonActions()
            }
        }
    }
    
    func loadDataFromFirebase(andOnCompletion completion:@escaping ()->()){
        guard isConnected else { return }
        firebaseMasterBranch.observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.exists() else{return}
            let enumerator = snapshot.children
            while let rest = enumerator.nextObject() as? DataSnapshot {
                var reloadPackage = DataPackage<Any>()
                func fetchData(andOnCompletion completion:@escaping ()->()){
                    reloadPackage.position = Position(x: rest.childSnapshot(forPath: "positionX").value!, y: rest.childSnapshot(forPath: "positionY").value!)
                    reloadPackage.isGreen = rest.childSnapshot(forPath: "isGreen").value as? Bool
                    completion()
                }
                fetchData{
                    let reloadedTable = Table(position: reloadPackage.compressPosition(), id: rest.key)
                    reloadedTable.toFlipState()
                    self.addChild(reloadedTable)
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
                completion()
            } else {
                self.isConnected = false
                completion()
            }
        })
    }
    
    func startObservers(){
        guard isConnected else { return }
        firebaseMasterBranch.observe(.value, with: {snapshot in
            guard snapshot.exists() else{return}
            let enumerations = snapshot.children
            while let rest = enumerations.nextObject() as? DataSnapshot{
                var newPackage = DataPackage<Any>()
                func fetchData(andOnCompletion completion:@escaping ()->()){
                    newPackage.keyID = rest.key
                    newPackage.isGreen = rest.childSnapshot(forPath: "isGreen").value as? Bool
                    
                    newPackage.position =  Position(x: rest.childSnapshot(forPath: "positionX").value!, y: rest.childSnapshot(forPath: "positionY").value!)
                    completion()
                }
                fetchData{
                    if self.validPackage(data: newPackage){
                        var tableExists: Bool = false
                        for childNode in self.children{
                            let child = childNode as? Table
                            if(child?.id == newPackage.keyID){
                                tableExists = true
                                if(child?.isGreen != newPackage.isGreen){
                                    child?.toFlipState()
                                }
                                child?.position = newPackage.compressPosition()
                            }
                        }
                        if(!tableExists){
                            let newTable = Table(position: newPackage.compressPosition(), id: newPackage.keyID!)
                            newTable.toFlipState()
                            self.addChild(newTable)
                        }
                    }
                }
            }
            
        })
    }
    
    func validPackage<T>(data: DataPackage<T>) -> Bool{
        guard data.isGreen != nil else { return false }
        guard data.position != nil else { return false }
        guard data.keyID != nil else { return false }
        return true
    }
    
    
    func addButtonActions(){
        addTableButton?.playAction = { [weak self] in
            let table = Table(position: (self?.addTableButton?.position)!, id: String(Date().toMillis()))
            table.colorBlendFactor = 0
            self?.addChild(table)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        currentlySelectedNode = atPoint(touches.first!.location(in: self)) as? Table
        currentlySelectedNode?.toFlipState()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        currentlySelectedNode?.position = touches.first!.location(in: self)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isConnected else { return }
        guard let table = currentlySelectedNode else { return }
        table.colorBlendFactor = 1
        let newTableBranch = firebaseMasterBranch.child((table.id)!)
        newTableBranch.child("positionX").setValue(table.position.x)
        newTableBranch.child("positionY").setValue(table.position.y)
        newTableBranch.child("isGreen").setValue(table.isGreen)
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

class Table : SKSpriteNode{
    
    var isGreen: Bool?
    var id : String?
    init(position: CGPoint, id: String){
        super.init(texture: SKTexture(imageNamed: "Square"), color: UIColor.clear, size: SKTexture(imageNamed: "Square").size())
        self.size = CGSize(width: 50, height: 50)
        self.colorBlendFactor =  1
        self.isGreen = true
        self.id = id
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