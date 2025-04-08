//
//  ImageFeatureTests.swift
//  BonsenseTests
//
//  Created by Jet Chiang on 2025-04-07.
//

import XCTest
@testable import Bonsense

final class ImageFeatureExtractionTests: XCTestCase {
	
	// Test image sizes
	let validSize = CGSize(width: 640, height: 360)
	
	func testBasicFeatureExtraction() throws {
		// Create a test image with known colors
		let imageSize = validSize
		UIGraphicsBeginImageContext(imageSize)
		let context = UIGraphicsGetCurrentContext()!
		
		// Fill with a solid color (red) for predictable features
		context.setFillColor(UIColor.red.cgColor)
		context.fill(CGRect(origin: .zero, size: imageSize))
		
		let testImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		
		// Extract features
		let features = try ImageFeatureExtractor.extractFeatures(from: testImage, normalize: false)
		
		// Verify feature count
		XCTAssertEqual(features.count, 19, "Should extract exactly 19 features")
		
		// For a solid red image (RGB: 1,0,0), verify expected values
		// RGB means should be (1,0,0)
		XCTAssertEqual(features[0], 1.0, accuracy: 0.1, "Red mean should be ~1.0")
		XCTAssertEqual(features[1], 0.0, accuracy: 0.1, "Green mean should be ~0.0")
		XCTAssertEqual(features[2], 0.0, accuracy: 0.1, "Blue mean should be ~0.0")
		
		// RGB standard deviations should be 0 (solid color)
		XCTAssertEqual(features[3], 0.0, accuracy: 0.1, "Red std dev should be ~0.0")
		XCTAssertEqual(features[4], 0.0, accuracy: 0.1, "Green std dev should be ~0.0")
		XCTAssertEqual(features[5], 0.0, accuracy: 0.1, "Blue std dev should be ~0.0")
	}
	
	func testSoilImageExtraction() throws {
		// Get the test bundle
		let bundle = Bundle(for: type(of: self))
		
		// Load test image from bundle
		guard let imagePath = bundle.path(forResource: "wet3", ofType: "jpg"),
			  let image = UIImage(contentsOfFile: imagePath) else {
			XCTFail("Failed to load test image")
			return
		}
		
		// Process the image
		let features = try ImageFeatureExtractor.extractFeatures(from: image, normalize: true)
		
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
	
	func testFeatureExtractionWithNormalization() throws {
		// Create a test image with varying brightness
		let imageSize = validSize
		UIGraphicsBeginImageContext(imageSize)
		let context = UIGraphicsGetCurrentContext()!
		
		// Create a gradient
		let colors = [UIColor.black.cgColor, UIColor.white.cgColor]
		let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
								colors: colors as CFArray,
								locations: [0.0, 1.0])!
		
		context.drawLinearGradient(gradient,
								 start: CGPoint(x: 0, y: 0),
								 end: CGPoint(x: imageSize.width, y: 0),
								 options: [])
		
		let testImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		
		// Extract features with and without normalization
		let featuresWithNorm = try ImageFeatureExtractor.extractFeatures(from: testImage, normalize: true)
		let featuresWithoutNorm = try ImageFeatureExtractor.extractFeatures(from: testImage, normalize: false)
		
		// Verify both return correct number of features
		XCTAssertEqual(featuresWithNorm.count, 19)
		XCTAssertEqual(featuresWithoutNorm.count, 19)
		
		// Features should be different with normalization
		XCTAssertNotEqual(featuresWithNorm, featuresWithoutNorm, "Normalized features should differ from non-normalized")
	}
	
	func testFeatureExtractionWithInvalidImage() throws {
		// Create an empty 1x1 image (invalid for feature extraction)
		UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
		let invalidImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		
		// Verify it throws appropriate error
		XCTAssertThrowsError(try ImageFeatureExtractor.extractFeatures(from: invalidImage)) { error in
			if case ImageFeatureExtractionError.featureExtractionFailed = error {
				// Expected error
			} else {
				XCTFail("Unexpected error type: \(error)")
			}
		}
	}
	
	func testFeatureRange() throws {
		// Create a test image with various colors
		let imageSize = validSize
		UIGraphicsBeginImageContext(imageSize)
		let context = UIGraphicsGetCurrentContext()!
		
		// Draw different colored rectangles
		let rectSize = CGSize(width: imageSize.width/4, height: imageSize.height)
		
		context.setFillColor(UIColor.red.cgColor)
		context.fill(CGRect(origin: CGPoint(x: 0, y: 0), size: rectSize))
		
		context.setFillColor(UIColor.green.cgColor)
		context.fill(CGRect(origin: CGPoint(x: rectSize.width, y: 0), size: rectSize))
		
		context.setFillColor(UIColor.blue.cgColor)
		context.fill(CGRect(origin: CGPoint(x: rectSize.width*2, y: 0), size: rectSize))
		
		context.setFillColor(UIColor.white.cgColor)
		context.fill(CGRect(origin: CGPoint(x: rectSize.width*3, y: 0), size: rectSize))
		
		let testImage = UIGraphicsGetImageFromCurrentImageContext()!
		UIGraphicsEndImageContext()
		
		let features = try ImageFeatureExtractor.extractFeatures(from: testImage, normalize: false)
		
		// Verify all features are within expected ranges
		for (index, feature) in features.enumerated() {
			XCTAssertFalse(feature.isNaN, "Feature \(index) should not be NaN")
			XCTAssertFalse(feature.isInfinite, "Feature \(index) should not be infinite")
			
			// Most features should be in [0,1] range, except entropy which can be higher
			if index != 18 { // not entropy
				XCTAssertGreaterThanOrEqual(feature, 0.0, "Feature \(index) should be >= 0")
				XCTAssertLessThanOrEqual(feature, 1.0, "Feature \(index) should be <= 1")
			} else {
				XCTAssertGreaterThanOrEqual(feature, 0.0, "Entropy should be >= 0")
			}
		}
	}
}
