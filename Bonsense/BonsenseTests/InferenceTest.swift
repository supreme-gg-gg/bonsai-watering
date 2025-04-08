//
//  InferenceTest.swift
//  BonsenseTests
//
//  Created by Jet Chiang on 2025-04-07.
//

import Foundation
import XCTest
@testable import Bonsense

class InferenceTest: XCTestCase {
    
    func testSoilPredictionPipeline() throws {
        // Load a sample soil image from the app bundle
        guard let imagePath = Bundle(for: type(of: self)).path(forResource: "wet3", ofType: "jpg"),
              let testImage = UIImage(contentsOfFile: imagePath) else {
            XCTFail("Failed to load sample soil image")
            return
        }
        
        // Initialize prediction service
        let predictionService = try SVCPredictionService()
        
        // Attempt prediction
        let result = try predictionService.predict(image: testImage)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Prediction should return a non-empty string")
    }

    func testSoilPredictionCategories() throws {
        // Loads a dry, humid, and wet image and test all three
        let categories = ["dry", "humid", "wet"]
		let predictionService = try SVCPredictionService()
        for category in categories {
            guard let imagePath = Bundle(for: type(of: self)).path(forResource: "\(category)", ofType: "jpg"),
                  let testImage = UIImage(contentsOfFile: imagePath) else {
                XCTFail("Failed to load sample soil image for category \(category)")
                return
            }
            
            // Attempt prediction
            let result = try predictionService.predict(image: testImage)
            
            // Verify we got a result
            XCTAssertFalse(result.isEmpty, "Prediction should return a non-empty string for category \(category)")
			
			print("Prediction result for \(category) is \(result)")
        }
    }

    func testInferencePerformance() throws {
        // Load a sample soil image from the app bundle
        guard let imagePath = Bundle(for: type(of: self)).path(forResource: "dry", ofType: "jpg"),
              let testImage = UIImage(contentsOfFile: imagePath) else {
            XCTFail("Failed to load sample soil image")
            return
        }
        
        // Initialize prediction service
        let predictionService = try SVCPredictionService()
        
        // Measure performance
        measure {
            do {
                _ = try predictionService.predict(image: testImage)
            } catch {
                XCTFail("Prediction failed with error: \(error)")
            }
        }
    }
}
