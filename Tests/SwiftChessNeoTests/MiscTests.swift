//
//  SwiftChessNeoPlayer.swift
//  
//
//  Created by Navan Chauhan on 4/17/24.
//

import XCTest
@testable import SwiftChessNeo

final class PlayerTests: XCTestCase {
    
    func testPlayerStruct() {
        let player1 = Player(kind: .human, name: "Magnus Carlsen", elo: 2900)
        let player2 = Player(kind: .human, name: "Magnus Carlsen", elo: 2900)
        let player3 = Player(kind: .computer, name: "Magnot Carlsen", elo: 2900)
        
        XCTAssertEqual(player1.kind.isHuman, true)
        XCTAssertEqual(player1.kind.isComputer, false)
        XCTAssertEqual(player3.kind.isHuman, false)
        XCTAssertEqual(player3.kind.isComputer, true)
        
        XCTAssertEqual(player1, player2)
        XCTAssertNotEqual(player1, player3)
        
        XCTAssertEqual(player1.kind.description, "Human")
        XCTAssertEqual(player3.kind.description, "Computer")
        
        XCTAssertEqual(player1.description, "Player(kind: Human, name: Magnus Carlsen, elo: 2900)")
    }

}
