//
//  VariantTests.swift
//  
//
//  Created by Navan Chauhan on 4/17/24.
//

import XCTest
@testable import SwiftChessNeo

final class VariantTests: XCTestCase {
    
    func testVariantEnum() {
        let game = Game()
        
        XCTAssertEqual(game.variant.isUpsideDown, false)
        XCTAssertEqual(game.variant.isStandard, true)
    }
}
