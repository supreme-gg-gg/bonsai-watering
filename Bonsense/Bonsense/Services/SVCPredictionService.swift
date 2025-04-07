//
//  SVCPredictionService.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

import UIKit
import CoreML

let expectedFeatureCount = 19
typealias CoreMLModel = SoilClassifierSVC
typealias CoreMLModelInput = SoilClassifierSVCInput
typealias CoreMLModelOutput = SoilClassifierSVCOutput
let modelInputName = "input_features"
let modelOutputLabelName = "classLabel"

enum PredictionServiceError: Error, LocalizedError {
	case modelLoadingFailed(Error)
	case predictionFailed(Error)
	case featureExtractionFailed(Error)
	case resultExtractionFailed(String)

	var errorDescription: String? {
		switch self {
		case .modelLoadingFailed(let underlyingError):
			return "Failed to load prediction model: \(underlyingError.localizedDescription)"
		case .predictionFailed(let underlyingError):
			return "Core ML prediction failed: \(underlyingError.localizedDescription)"
		case .featureExtractionFailed(let underlyingError):
			// Forward the description from FeatureExtractionError if possible
			let featureErrorDesc = (underlyingError as? LocalizedError)?.errorDescription ?? underlyingError.localizedDescription
			return "Feature Extraction Failed: \(featureErrorDesc)"
		case .resultExtractionFailed(let reason):
			return "Failed to extract results: \(reason)"
		}
	}
}

enum FeatureExtractionError: Error, LocalizedError {
	case invalidImage(String)
	case processingFailed(String)

	var errorDescription: String? {
		switch self {
		case .invalidImage(let reason): return "Invalid Image: \(reason)"
		case .processingFailed(let reason): return "Processing Failed: \(reason)"
		}
	}
}

class SVCPredictionService {

	private let coreMLModel: CoreMLModel
	private let featureExtractor: FeatureExtractor

	init() throws {
		do {
			// initialize feature extractor
			self.featureExtractor = FeatureExtractor()
			
			// load ML model
			let config = MLModelConfiguration()
			self.coreMLModel = try CoreMLModel(configuration: config)
			print("PredictionService: Core ML model loaded successfully.")
		} catch {
			print("PredictionService: Error loading Core ML model - \(error)")
			throw PredictionServiceError.modelLoadingFailed(error)
		}
	}

	/// Performs prediction on the input image.
	/// - Parameter image: The UIImage to analyze.
	/// - Returns: A tuple containing the predicted label and probability dictionary.
	/// - Throws: `PredictionServiceError` if any step fails.
	/// - Note: This method performs potentially long-running CPU work and should be called from a background task.
	func predict(image: UIImage) throws -> String {
		print("PredictionService: Starting prediction...")
		do {
			// Extract features
			let features = featureExtractor.extractFeatures(from: image)
			print("PredictionService: Features extracted.")
			
			// Convert [Float] to the MLMultiArray type
			let input = CoreMLModelInput(image_features: try MLMultiArray(features))

			// Predict with the input type
			let predictionOutput = try coreMLModel.prediction(input: input)
			print("PredictionService: Core ML prediction complete.")

			// Extract results under classLabel
			let predictedLabel = predictionOutput.classLabel

			print("PredictionService: Prediction result - Label='\(predictedLabel)'")
			
			// Return tuple matching the declared return type
			return predictedLabel

		} catch let featureError as FeatureExtractionError {
			print("PredictionService: Feature extraction error - \(featureError)")
			throw PredictionServiceError.featureExtractionFailed(featureError)
		} catch {
			print("PredictionService: Core ML prediction error - \(error)")
			throw PredictionServiceError.predictionFailed(error)
		}
	}
}
