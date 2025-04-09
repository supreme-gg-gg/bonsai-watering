//
//  FeatureExtractionTests.swift
//  BonsenseTests
//
//  Created by Jet Chiang on 2025-04-07.
//

import XCTest
@testable import Bonsense

final class FeatureExtractionTests: XCTestCase {
    var featureExtractor: FeatureExtractor!
    
    // Constants for feature validation
    private let expectedFeatureCount = 19
    
    override func setUp() {
        super.setUp()
        featureExtractor = FeatureExtractor()
    }
    
    override func tearDown() {
        featureExtractor = nil
        super.tearDown()
    }
    
    // Helper method to create a test image
    private func createTestImage(color: UIColor, size: CGSize = CGSize(width: 256, height: 256)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // Test with solid color image
    func testProcessRedImage() {
        let redImage = createTestImage(color: .red)
        let features = processImage(image: redImage)
        
        XCTAssertFalse(features.isEmpty)
        XCTAssertEqual(features.count, expectedFeatureCount) // When augment is false
        
        // Test RGB values for red color
        let rgbFeatures = features[0..<9] // First 9 values are RGB features
        XCTAssertEqual(Array(rgbFeatures)[0], 255.0, accuracy: 1.0) // Red mean
        XCTAssertEqual(Array(rgbFeatures)[3], 0.0, accuracy: 1.0)   // Green mean
        XCTAssertEqual(Array(rgbFeatures)[6], 0.0, accuracy: 1.0)   // Blue mean
    }
    
    // Test with gradient image
    func testProcessGradientImage() {
        let gradientImage = createGradientImage()
        let features = processImage(image: gradientImage)
        
        XCTAssertFalse(features.isEmpty)
        // Test that we get non-zero standard deviation
        let stdDevs = features[1...2] // Red std dev and variance
        XCTAssertGreaterThan(Array(stdDevs)[0], 0.0)
    }
    
    // Helper method to create gradient test image
    private func createGradientImage(size: CGSize = CGSize(width: 256, height: 256)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let gradient = CAGradientLayer()
            gradient.frame = CGRect(origin: .zero, size: size)
            gradient.colors = [UIColor.red.cgColor, UIColor.blue.cgColor]
            gradient.render(in: context.cgContext)
        }
    }
    
    // Test entropy calculation
    func testEntropyCalculation() {
        // Solid color should have zero entropy
        let solidImage = createTestImage(color: .red)
        let solidFeatures = processImage(image: solidImage)
		let solidEntropy = solidFeatures.last!
        XCTAssertEqual(solidEntropy, 0.0, accuracy: 0.1)
        
        // Gradient should have non-zero entropy
        let gradientImage = createGradientImage()
        let gradientFeatures = processImage(image: gradientImage)
		let gradientEntropy = gradientFeatures.last!
        XCTAssertGreaterThan(gradientEntropy, 0.0)
    }
    
    func testRealImageProcessing() throws {
        // Get the test bundle
        let bundle = Bundle(for: type(of: self))
        
        // Load test image from bundle
        guard let imagePath = bundle.path(forResource: "dry", ofType: "jpg"),
              let image = UIImage(contentsOfFile: imagePath) else {
            XCTFail("Failed to load test image")
            return
        }
        
        // Process the image
        let features = processImage(image: image)
        
        // Validate basic structure
        XCTAssertFalse(features.isEmpty)
        XCTAssertEqual(features.count, expectedFeatureCount)
        
        // Print features for comparison with Python output
        print("\n=== Feature Vector ===")
        features.enumerated().forEach { index, value in
            print("Feature \(index): \(value)")
        }
        print("====================\n")
    }
	
	func testProcessingPerformance() {
		measure {
			let redImage = createTestImage(color: .red)
			let features = processImage(image: redImage)
			print(features.count)
			print("Processing complete")
		}
	}
}
