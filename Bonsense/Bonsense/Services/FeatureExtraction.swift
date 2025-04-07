//
//  FeatureExtraction.swift
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

import Foundation
import UIKit
import Accelerate
import CoreImage
import CoreGraphics
import CoreImage.CIFilterBuiltins

struct FeatureExtractor {
	// Constants
	let roiSize = CGSize(width: 256, height: 256)
	
	// MARK: - Image Processing Functions
	
	func normalizeImage(_ image: CIImage) -> CIImage {
		// Convert RGB to LAB
		let labImage = convertRGBToLab(inputImage: image)
		
		// Create a filter to replace L channel with constant value
		let colorMatrix = CIFilter.colorMatrix()
		colorMatrix.inputImage = labImage
		
		// Matrix to set L channel to 0.5 (128/255 in normalized space)
		// First row sets L to 0.5, other channels unchanged
		colorMatrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 0)
		colorMatrix.gVector = CIVector(x: 0, y: 1, z: 0, w: 0)
		colorMatrix.bVector = CIVector(x: 0, y: 0, z: 1, w: 0)
		colorMatrix.biasVector = CIVector(x: 0.5, y: 0, z: 0, w: 0)
		
		guard let normalizedLab = colorMatrix.outputImage else {
			return image
		}
		
		// Convert back to RGB
		return convertLabToRGB(inputImage: normalizedLab)
	}
	
	func getCenterROI(_ image: CIImage, size: CGSize) -> CIImage {
		let imageSize = image.extent.size
		
		// Calculate center coordinates
		let centerX = imageSize.width / 2
		let centerY = imageSize.height / 2
		
		// Calculate ROI boundaries
		let startX = centerX - (size.width / 2)
		let startY = centerY - (size.height / 2)
		
		// Create ROI rectangle
		let roi = CGRect(x: max(0, startX),
						 y: max(0, startY),
						 width: min(imageSize.width - startX, size.width),
						 height: min(imageSize.height - startY, size.height))
		
		// Crop the image
		return image.cropped(to: roi)
	}
	
	// MARK: - Feature Extraction
	
	func extractFeatures(from image: UIImage, normalize: Bool = true, augment: Bool = false) -> [Float] {
		guard let ciImage = CIImage(image: image) else {
			fatalError("Failed to create CIImage from UIImage")
		}
		
		// Get center ROI
		let roiImage = getCenterROI(ciImage, size: roiSize)
		
		// Normalize if requested
		let processedImage = normalize ? normalizeImage(roiImage) : roiImage
		
		 // Convert to UIImage for pixel access
		let context = CIContext()
		guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
			return []
		}
		let uiImage = UIImage(cgImage: cgImage)
		
		// Extract features from base image
		var features: [Float] = []
		
		 // RGB features (9 features: means, std devs, variances)
		let rgbFeatures = extractRGBFeatures(from: uiImage)
		features.append(contentsOf: rgbFeatures)
		
		// HSV features (6 features: means and std devs only)
		let hsvFeatures = extractHSVFeatures(from: uiImage)
		features.append(contentsOf: hsvFeatures)
		
		// LAB features (3 features: means only)
		let labFeatures = extractLABFeatures(from: uiImage)
		features.append(contentsOf: labFeatures)
		
		// Entropy (1 feature)
		let entropyValue = calculateEntropy(from: uiImage)
		features.append(entropyValue)
		
		return features  // Total: 19 features
	}
	
	// MARK: - Color Feature Extraction
	
	func extractRGBFeatures(from image: UIImage) -> [Float] {
		guard let cgImage = image.cgImage else { return [] }
		
		let width = cgImage.width
		let height = cgImage.height
		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		let bitsPerComponent = 8
		
		var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
		
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let context = CGContext(data: &pixelData,
							   width: width,
							   height: height,
							   bitsPerComponent: bitsPerComponent,
							   bytesPerRow: bytesPerRow,
							   space: colorSpace,
							   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		
		context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		
		// Arrays to store channel values
		var redValues = [Float]()
		var greenValues = [Float]()
		var blueValues = [Float]()
		
		// Extract RGB values
		for y in 0..<height {
			for x in 0..<width {
				let offset = (y * bytesPerRow) + (x * bytesPerPixel)
				// Normalize to [0,1] range
				let red = Float(pixelData[offset]) / 255.0
				let green = Float(pixelData[offset + 1]) / 255.0
				let blue = Float(pixelData[offset + 2]) / 255.0
				
				redValues.append(red)
				greenValues.append(green)
				blueValues.append(blue)
			}
		}
		
		// Calculate all statistics first
		let rMean = mean(redValues)
		let gMean = mean(greenValues)
		let bMean = mean(blueValues)
		
		let rStd = standardDeviation(redValues, mean: rMean)
		let gStd = standardDeviation(greenValues, mean: gMean)
		let bStd = standardDeviation(blueValues, mean: bMean)
		
		let rVar = variance(redValues, mean: rMean)
		let gVar = variance(greenValues, mean: gMean)
		let bVar = variance(blueValues, mean: bMean)
		
		// Add in correct order: means, then std devs, then variances
		var features: [Float] = []
		features.append(contentsOf: [rMean, gMean, bMean])
		features.append(contentsOf: [rStd, gStd, bStd])
		features.append(contentsOf: [rVar, gVar, bVar])
		
		return features
	}
	
	func extractHSVFeatures(from image: UIImage) -> [Float] {
		guard let cgImage = image.cgImage else { return [] }
		
		let width = cgImage.width
		let height = cgImage.height
		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		let bitsPerComponent = 8
		
		var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
		
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let context = CGContext(data: &pixelData,
							   width: width,
							   height: height,
							   bitsPerComponent: bitsPerComponent,
							   bytesPerRow: bytesPerRow,
							   space: colorSpace,
							   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		
		context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		
		// Arrays to store HSV values
		var hValues = [Float]()
		var sValues = [Float]()
		var vValues = [Float]()
		
		// Convert RGB to HSV
		for y in 0..<height {
			for x in 0..<width {
				let offset = (y * bytesPerRow) + (x * bytesPerPixel)
				let r = Float(pixelData[offset]) / 255.0
				let g = Float(pixelData[offset + 1]) / 255.0
				let b = Float(pixelData[offset + 2]) / 255.0
				
				let (h, s, v) = rgbToHSV(r: r, g: g, b: b)
				hValues.append(h)
				sValues.append(s)
				vValues.append(v)
			}
		}
		
		// Calculate statistics
		var features: [Float] = []
		
		// H channel
		let hMean = mean(hValues)
		let hStd = standardDeviation(hValues, mean: hMean)
		features.append(contentsOf: [hMean, hStd])
		
		// S channel
		let sMean = mean(sValues)
		let sStd = standardDeviation(sValues, mean: sMean)
		features.append(contentsOf: [sMean, sStd])
		
		// V channel
		let vMean = mean(vValues)
		let vStd = standardDeviation(vValues, mean: vMean)
		features.append(contentsOf: [vMean, vStd])
		
		return features
	}
	
	func extractLABFeatures(from image: UIImage) -> [Float] {
		guard let ciImage = CIImage(image: image) else { return [] }
		
		// Convert to LAB color space using the existing helper function
		let labImage = convertRGBToLab(inputImage: ciImage)
		
		// Create CIContext for pixel access
		let context = CIContext()
		guard let cgImage = context.createCGImage(labImage, from: labImage.extent) else { return [] }
		
		let width = cgImage.width
		let height = cgImage.height
		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		
		var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
		
		guard let context = CGContext(data: &pixelData,
									width: width,
									height: height,
									bitsPerComponent: 8,
									bytesPerRow: bytesPerRow,
									space: CGColorSpaceCreateDeviceRGB(),
									bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return [] }
		
		context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		
		// Arrays to store LAB values
		var lValues = [Float]()
		var aValues = [Float]()
		var bValues = [Float]()
		
		// Extract LAB values from pixel data
		for y in 0..<height {
			for x in 0..<width {
				let offset = (y * bytesPerRow) + (x * bytesPerPixel)
				lValues.append(Float(pixelData[offset]) / 255.0)      // L channel
				aValues.append(Float(pixelData[offset + 1]) / 255.0)  // a channel
				bValues.append(Float(pixelData[offset + 2]) / 255.0)  // b channel
			}
		}
		
		// Calculate statistics
		let lMean = mean(lValues)
		let aMean = mean(aValues)
		let bMean = mean(bValues)
		
		return [lMean, aMean, bMean]
	}
	
	// MARK: - Texture Feature Extraction
	
	func calculateEntropy(from image: UIImage) -> Float {
		// Convert to grayscale
		guard let cgImage = image.cgImage else { return 0 }
		
		let width = cgImage.width
		let height = cgImage.height
		let bytesPerPixel = 4
		let bytesPerRow = bytesPerPixel * width
		let bitsPerComponent = 8
		
		var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
		
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let context = CGContext(data: &pixelData,
							   width: width,
							   height: height,
							   bitsPerComponent: bitsPerComponent,
							   bytesPerRow: bytesPerRow,
							   space: colorSpace,
							   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
		
		context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
		
		// Calculate grayscale values
		var grayValues = [UInt8](repeating: 0, count: width * height)
		for y in 0..<height {
			for x in 0..<width {
				let offset = (y * bytesPerRow) + (x * bytesPerPixel)
				let r = Float(pixelData[offset])
				let g = Float(pixelData[offset + 1])
				let b = Float(pixelData[offset + 2])
				
				// Convert RGB to grayscale using standard weights
				let gray = UInt8((0.299 * r + 0.587 * g + 0.114 * b))
				grayValues[y * width + x] = gray
			}
		}
		
		// Calculate histogram
		var histogram = [Float](repeating: 0, count: 256)
		for value in grayValues {
			histogram[Int(value)] += 1
		}
		
		// Normalize histogram
		let totalPixels = Float(width * height)
		for i in 0..<256 {
			histogram[i] /= totalPixels
		}
		
		// Calculate entropy matching Python implementation
		var entropy: Float = 0
		for p in histogram {
			let pWithEps = p + 1e-7  // Add epsilon to match Python
			entropy -= p * log2(pWithEps)
		}
		
		return entropy
	}
	
	// MARK: - Image Augmentation
	
	func augmentImage(_ image: CIImage) -> [CIImage] {
		var augmentedImages = [image]
		
		// Rotate 90 degrees
		if let rotateFilter = CIFilter(name: "CIAffineTransform") {
			let transform = CGAffineTransform(rotationAngle: .pi/2)
			rotateFilter.setValue(image, forKey: kCIInputImageKey)
			rotateFilter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
			if let rotatedImage = rotateFilter.outputImage {
				augmentedImages.append(rotatedImage)
			}
		}
		
		// Flip horizontally
		if let flipFilter = CIFilter(name: "CIAffineTransform") {
			let transform = CGAffineTransform(scaleX: -1, y: 1)
			flipFilter.setValue(image, forKey: kCIInputImageKey)
			flipFilter.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
			if let flippedImage = flipFilter.outputImage {
				augmentedImages.append(flippedImage)
			}
		}
		
		return augmentedImages
	}
	
	// MARK: - Helper Functions
	
	func rgbToHSV(r: Float, g: Float, b: Float) -> (Float, Float, Float) {
		let maxVal = max(r, max(g, b))
		let minVal = min(r, min(g, b))
		let delta = maxVal - minVal
		
		// Calculate V
		let v = maxVal
		
		// Calculate S
		let s = maxVal == 0 ? 0 : delta / maxVal
		
		// Calculate H
		var h: Float = 0
		
		if delta == 0 {
			h = 0  // undefined, but set to 0
		} else if maxVal == r {
			h = 60 * ((g - b) / delta).truncatingRemainder(dividingBy: 6)
		} else if maxVal == g {
			h = 60 * ((b - r) / delta + 2)
		} else {
			h = 60 * ((r - g) / delta + 4)
		}
		
		if h < 0 {
			h += 360
		}
		
		// Normalize H to [0, 1]
		h /= 360
		
		return (h, s, v)
	}
	
	func convertRGBToLab(inputImage: CIImage) -> CIImage {
		let convertRGBToLabFilter = CIFilter.convertRGBtoLab()
		convertRGBToLabFilter.inputImage = inputImage
		convertRGBToLabFilter.normalize = true
		return convertRGBToLabFilter.outputImage!
	}

	func convertLabToRGB(inputImage: CIImage) -> CIImage {
		let filter = CIFilter.convertLabToRGB()
		filter.inputImage = inputImage
		filter.normalize = true
		return filter.outputImage!
	}
	
	func mean(_ values: [Float]) -> Float {
		guard !values.isEmpty else { return 0 }
		var sum: Float = 0
		vDSP_meanv(values, 1, &sum, vDSP_Length(values.count))
		return sum.isNaN ? 0 : sum
	}
	
	func variance(_ values: [Float], mean: Float) -> Float {
		guard values.count > 1 else { return 0 }
		
		// Create array of differences from mean
		var differences = [Float](repeating: 0, count: values.count)
		vDSP_vsub([mean], 1, values, 1, &differences, 1, vDSP_Length(values.count))
		
		// Square the differences
		var squaredDiffs = [Float](repeating: 0, count: values.count)
		vDSP_vsq(differences, 1, &squaredDiffs, 1, vDSP_Length(values.count))
		
		// Calculate mean of squared differences
		var result: Float = 0
		vDSP_meanv(squaredDiffs, 1, &result, vDSP_Length(values.count))
		
		return result.isNaN ? 0 : result
	}
	
	func standardDeviation(_ values: [Float], mean: Float) -> Float {
		let var_value = variance(values, mean: mean)
		return var_value > 0 ? sqrtf(var_value) : 0
	}
}

// Usage Example
func processImage(image: UIImage) -> [Float] {
	let extractor = FeatureExtractor()
	return extractor.extractFeatures(from: image)
}
