//
//  ImageFeatureExtraction.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

import UIKit

enum ImageFeatureExtractionError: LocalizedError {
    case featureExtractionFailed(String)
    case invalidFeatureCount(Int)
    
    var errorDescription: String? {
        switch self {
        case .featureExtractionFailed(let reason):
            return "Feature extraction failed: \(reason)"
        case .invalidFeatureCount(let count):
            return "Invalid feature count: got \(count), expected 19"
        }
    }
}

struct ImageFeatureExtractor {
    /// Expected number of features based on the Python implementation
    private static let expectedFeatureCount = 19
    
    /// Extracts features from a UIImage using OpenCV
    /// - Parameters:
    ///   - image: Input image to extract features from
    ///   - normalize: Whether to normalize lighting using LAB color space
    /// - Returns: Array of 19 features in the following order:
    ///   - RGB means (3)
    ///   - RGB standard deviations (3)
    ///   - RGB variances (3)
    ///   - HSV means (3)
    ///   - HSV standard deviations (3)
    ///   - LAB means (3)
    ///   - Entropy (1)
    /// - Throws: ImageFeatureExtractionError if extraction fails or feature count is invalid
	static func extractFeatures(from image: UIImage, normalize: Bool = true) throws -> [Float] {
		var error: NSError?
		let opencv = OpenCVUtils()
		guard let features = try? opencv.extractFeatures(image, withNormalize: true) else {
			throw ImageFeatureExtractionError.featureExtractionFailed(error?.localizedDescription ?? "Unknown error")
		}
		
		// Validate feature count
		if features.count != expectedFeatureCount {
			if features.isEmpty {
				throw ImageFeatureExtractionError.invalidFeatureCount(features.count)
			} else {
				throw ImageFeatureExtractionError.featureExtractionFailed(error?.localizedDescription ?? "Feature array was nil after success, but no error was set")
			}
		}

		// Convert NSNumber array to [Float]
		return features.map { $0.floatValue }
	}
}
