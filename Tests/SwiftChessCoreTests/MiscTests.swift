//
//  MiscTests.swift
//  
//
//  Created by Navan Chauhan on 4/17/24.
//

import XCTest
@testable import SwiftChessCore

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

final class MinimaxTests: XCTestCase {
    
    func testBestMoveForWhite() { // Take with the bishop instead of the rook
        let game = try! Game(position: Game.Position(fen: "8/5B2/k5p1/4rp2/8/8/PP6/1K3R2 w - - 0 1")!)
        let move = game.bestMove(depth: 2)
        XCTAssertEqual(move, Move(start: .f7, end: .g6))
    }
    
    func testBestMoveForBlack() { // Take with the Knight
        let game = try! Game(position: Game.Position(fen: "7k/6p1/8/5p1n/2r2P2/4B1P1/R7/K7 b - - 0 1")!)
        let move = game.bestMove(depth: 2)
        XCTAssertEqual(move, Move(start: .h5, end: .g3))
    }

    
}

final class VariantTests: XCTestCase {
    
    func testVariantEnum() {
        let game = Game()
        
        XCTAssertEqual(game.variant.isUpsideDown, false)
        XCTAssertEqual(game.variant.isStandard, true)
    }
}
