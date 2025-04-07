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
    
    func testBasicPredictionPipeline() throws {
        // Create a simple test image (256x256 red square)
        let size = CGSize(width: 256, height: 256)
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let testImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Initialize prediction service
        let predictionService = try SVCPredictionService()
        
        // Attempt prediction
        let result = try predictionService.predict(image: testImage)
        
        // Verify we got a result
        XCTAssertFalse(result.isEmpty, "Prediction should return a non-empty string")
    }

    func testSoilImagePrediction() throws {
        // Load a sample soil image from the app bundle
        guard let imagePath = Bundle(for: type(of: self)).path(forResource: "dry0", ofType: "jpg"),
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

    func testInferencePerformance() throws {
        // Load a sample soil image from the app bundle
        guard let imagePath = Bundle(for: type(of: self)).path(forResource: "dry0", ofType: "jpg"),
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
