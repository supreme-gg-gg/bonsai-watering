//
//  SVCPredictionService.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

import UIKit
import CoreML
import Accelerate

let expectedFeatureCount = 19
let modelInputName = "input_features"
let modelOutputLabelName = "classLabel"

// Scaler -> SVC
typealias CoreMLModel = SoilClassifierSVC
typealias CoreMLModelInput = SoilClassifierSVCInput
typealias CoreMLModelOutput = SoilClassifierSVCOutput

// (manual scaling) -> (manual LDA) -> SVC
typealias LDACoreMLModel = SoilClassifierLDA_SVC
typealias LDACoreMLModelInput = SoilClassifierLDA_SVCInput
typealias LDACoreMLModelOutput = SoilClassifierLDA_SVCOutput

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

class SVCPredictionService: ObservableObject {

	private let coreMLModel: CoreMLModel
	
	init() throws {
	    do {
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
	/// - Returns: The predicted soil moisture class label.
	/// - Throws: `PredictionServiceError` if any step fails.
	/// - Note: This method performs potentially long-running CPU work and should be called from a background task.
	func predict(image: UIImage) throws -> String {
	    do {
	        // Extract features using OpenCV
	        let features = try ImageFeatureExtractor.extractFeatures(from: image)
			
//			print("\n=== Feature Vector ===")
//			features.enumerated().forEach { index, value in
//				print("Feature \(index): \(value)")
//			}
//			print("====================\n")
			
			// Convert [Float] to the MLMultiArray type
			let input = CoreMLModelInput(image_features: try MLMultiArray(features))

			// Predict with the input type
			let predictionOutput = try coreMLModel.prediction(input: input)

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

// MARK: You should use SVCPredictionService unless you know what you're doing
// Directly copying matrices and scaler from scikit-learn is very risky...
// This is only done here because CoreML does not natively support LDA
class LDASVCPredictionService: ObservableObject {

	private let coreMLModel: LDACoreMLModel

	let ldaMatrix: [[Float]] = [
		[ 30.07943874,  -7.32980337],
		[-12.68969489, -65.67934916],
		[-47.35787679, 132.67606339],
		[ -2.35475466,  18.42327744],
		[  5.65184850,  -5.09312039],
		[  3.21819311,  -4.38248291],
		[ -6.70269495,   2.11117849],
		[ 12.80934002, -12.85503172],
		[ -6.93499557,  10.12842517],
		[  4.09817170,  -1.14594936],
		[ 13.05654406,  -6.11909723],
		[ -9.50037670,  -2.74691769],
		[ -2.89756126,   3.52446487],
		[  4.30499524,  -3.30719885],
		[ -6.19626952,  -7.10002957],
		[ 20.49580521,  14.29571537],
		[-10.28318525, -10.06128774],
		[-66.84806162, 126.36635268],
		[  1.00388876,  -0.67416326]
	]

	let scalerMean: [Float] = [
		126.27169498, 117.55076087, 103.63481239,  10.24689843,   6.14582683,
		 13.88165420, 146.08739691,  91.35396001, 210.40138713,  28.30218303,
		 46.86827548, 127.14799595,  24.31597739,  29.20316617,   9.80111498,
		127.29890283, 129.10712234, 136.92316862,   1.38004267
	]

	let scalerStd: [Float] = [
		4.90480188,   3.47298795,   7.91671027,   6.41002882,   7.32002545,
		4.20726322, 179.82827534, 151.16629065, 128.82278927,  13.08316559,
	   16.14677844,   4.26111359,  13.82486788,   5.81352466,   6.65461713,
		3.41918185,   1.11828182,   4.03160336,   0.22605907
	]
	
	init() throws {
	    do {
	        // load ML model
	        let config = MLModelConfiguration()
	        self.coreMLModel = try LDACoreMLModel(configuration: config)
	        print("PredictionService: Core ML model loaded successfully.")
	    } catch {
	        print("PredictionService: Error loading Core ML model - \(error)")
	        throw PredictionServiceError.modelLoadingFailed(error)
	    }
	}
	
	/// Performs prediction on the input image.
	/// - Parameter image: The UIImage to analyze.
	/// - Returns: The predicted soil moisture class label.
	/// - Throws: `PredictionServiceError` if any step fails.
	/// - Note: This method performs potentially long-running CPU work and should be called from a background task.
	/// - Important: This method uses LDA transformation and scaling before prediction. 
	/// - Warning: Make sure you are using the correct model! This one is manual scaling and LDA with CoreML SVC.
	func predict(image: UIImage) throws -> String {
	    do {
	        // Extract features using OpenCV
	        var features = try ImageFeatureExtractor.extractFeatures(from: image)
			
//			print("\n=== Feature Vector ===")
//			features.enumerated().forEach { index, value in
//				print("Feature \(index): \(value)")
//			}
//			print("====================\n")

			// Apply scaling
            features = scaleVector(inputVector: features, mean: scalerMean, std: scalerStd)

            // Apply LDA transformation
            features = applyLda(inputVector: features, ldaMatrix: ldaMatrix)
			
			// Convert [Float] to the MLMultiArray type
			let input = LDACoreMLModelInput(lda_features: try MLMultiArray(features))

			// Predict with the input type
			let predictionOutput = try coreMLModel.prediction(input: input)

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

	/// Scales the input vector using the provided mean and standard deviation.
	/// - Parameters:
	///  - inputVector: The input vector to scale.
	///  - mean: The mean vector for scaling.
	///  - std: The standard deviation vector for scaling.
	/// - Returns: The scaled vector.
	/// - Note: The input vector, mean, and std vectors must have the same dimensions.
	/// - Important: This method uses Accelerate framework for vector operations.
	private func scaleVector(inputVector: [Float], mean: [Float], std: [Float]) -> [Float] {
		guard inputVector.count == mean.count, inputVector.count == std.count else {
			print("Error: Input vector and scaler dimensions do not match.")
			return []
		}

		var result = [Float](repeating: 0, count: inputVector.count)
		var input = inputVector
		var meanVec = mean
		var stdVec = std
		
		// Subtract mean
		vDSP_vsub(&meanVec, 1, &input, 1, &result, 1, vDSP_Length(input.count))
		
		// Divide by std
		// we need to create a copy, can't write to the same buffer
		var tempResult = result
		vDSP_vdiv(&stdVec, 1, &tempResult, 1, &result, 1, vDSP_Length(input.count))
		
		return result
	}

	/// Applies LDA transformation to the input vector using the provided LDA matrix.
	/// - Parameters:
	///  - inputVector: The input vector to transform.
	///  - ldaMatrix: The LDA matrix for transformation.
	/// - Returns: The transformed vector.
	/// - Note: The input vector and LDA matrix must have compatible dimensions.
	/// - Important: This method uses Accelerate framework for matrix-vector multiplication.
	/// - Warning: The LDA matrix is expected to be in column-major order for vDSP.
	private func applyLda(inputVector: [Float], ldaMatrix: [[Float]]) -> [Float] {
		guard inputVector.count == ldaMatrix.count else {
			print("Error: Input vector and LDA matrix dimensions do not match.")
			return []
		}

		let rows = ldaMatrix.count
		let cols = ldaMatrix[0].count
		
		// Flatten the 2D matrix into 1D array (column-major order for vDSP)
		let flatMatrix = (0..<cols).flatMap { col in
			(0..<rows).map { row in ldaMatrix[row][col] }
		}
		
		var result = [Float](repeating: 0, count: cols)
		var input = inputVector
		var matrix = flatMatrix
		
		// Matrix-vector multiplication using vDSP
		vDSP_mmul(&input, 1,
				  &matrix, 1,
				  &result, 1,
				  vDSP_Length(1), vDSP_Length(cols), vDSP_Length(rows))
		
		return result
	}
}
