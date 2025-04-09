//
//  OpenCVWrapper.mm
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import "OpenCVUtils.h"

/*
 * add a method convertToMat to UIImage class
 */
@interface UIImage (OpenCVWrapper)
- (void)convertToMat:(cv::Mat *)pMat :(bool)alphaExists;
@end

@implementation UIImage (OpenCVWrapper)

- (void)convertToMat:(cv::Mat *)pMat :(bool)alphaExists {
    if (self.imageOrientation == UIImageOrientationRight) {
        /*
         * When taking picture in portrait orientation,
         * convert UIImage to OpenCV Matrix in landscape right-side-up orientation,
         * and then rotate OpenCV Matrix to portrait orientation
         */
        UIImageToMat([UIImage imageWithCGImage:self.CGImage scale:1.0 orientation:UIImageOrientationUp], *pMat, alphaExists);
        cv::rotate(*pMat, *pMat, cv::ROTATE_90_CLOCKWISE);
    } else if (self.imageOrientation == UIImageOrientationLeft) {
        /*
         * When taking picture in portrait upside-down orientation,
         * convert UIImage to OpenCV Matrix in landscape right-side-up orientation,
         * and then rotate OpenCV Matrix to portrait upside-down orientation
         */
        UIImageToMat([UIImage imageWithCGImage:self.CGImage scale:1.0 orientation:UIImageOrientationUp], *pMat, alphaExists);
        cv::rotate(*pMat, *pMat, cv::ROTATE_90_COUNTERCLOCKWISE);
    } else {
        /*
         * When taking picture in landscape orientation,
         * convert UIImage to OpenCV Matrix directly,
         * and then ONLY rotate OpenCV Matrix for landscape left-side-up orientation
         */
        UIImageToMat(self, *pMat, alphaExists);
        if (self.imageOrientation == UIImageOrientationDown) {
            cv::rotate(*pMat, *pMat, cv::ROTATE_180);
        }
    }
}
@end

// Error domain for OpenCV feature extraction
static NSString *const OpenCVFeatureExtractionErrorDomain = @"com.bonsai.opencv.featureextraction";

// Error codes
typedef NS_ENUM(NSInteger, OpenCVFeatureExtractionError) {
    OpenCVFeatureExtractionErrorImageConversion = 1001,
    OpenCVFeatureExtractionErrorROIExtraction = 1002,
    OpenCVFeatureExtractionErrorColorSpaceConversion = 1003,
    OpenCVFeatureExtractionErrorComputation = 1004
};

@implementation OpenCVUtils

// Helper function to compute mean of a channel
static float computeMean(const cv::Mat& channel) {
    cv::Scalar mean = cv::mean(channel);
    return static_cast<float>(mean[0]);
}

// Helper function to compute standard deviation of a channel
static float computeStdDev(const cv::Mat& channel) {
    cv::Scalar mean, stddev;
    cv::meanStdDev(channel, mean, stddev);
    return static_cast<float>(stddev[0]);
}

// Helper function to compute entropy
static float computeEntropy(const cv::Mat& grayImage) {
    cv::Mat hist;
    int histSize = 256;
    float range[] = { 0, 256 };
    const float* histRange = { range };
    
    cv::calcHist(&grayImage, 1, 0, cv::Mat(), hist, 1, &histSize, &histRange);
    
    // Normalize histogram
    hist /= (grayImage.rows * grayImage.cols);
    
    float entropy = 0;
    for (int i = 0; i < histSize; i++) {
        float p = hist.at<float>(i);
        if (p > 0) {
            entropy -= p * log2f(p);
        }
    }
    
    return entropy;
}

// Helper function to extract ROI
static cv::Mat extractCenterROI(const cv::Mat& input, int roiSize) {
    int startX = (input.cols - roiSize) / 2;
    int startY = (input.rows - roiSize) / 2;
    
    // Ensure we don't go out of bounds
    startX = std::max(0, std::min(startX, input.cols - roiSize));
    startY = std::max(0, std::min(startY, input.rows - roiSize));
    
    return input(cv::Rect(startX, startY, roiSize, roiSize));
}

// Helper function to normalize lighting using LAB color space
static cv::Mat normalizeLighting(const cv::Mat& input) {
    cv::Mat lab;
    cv::cvtColor(input, lab, cv::COLOR_BGR2Lab);
    
    std::vector<cv::Mat> labChannels;
    cv::split(lab, labChannels);
    
    // Set L channel to constant value (128)
    labChannels[0].setTo(cv::Scalar(128));
    
    cv::merge(labChannels, lab);
    
    cv::Mat normalized;
    cv::cvtColor(lab, normalized, cv::COLOR_Lab2BGR);
    return normalized;
}

+ (NSString *)getOpenCVVersion {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (UIImage *)grayscaleImg:(UIImage *)image {
    cv::Mat mat;
    [image convertToMat:&mat :false];
    
    cv::Mat gray;
    
    NSLog(@"channels = %d", mat.channels());
    
    if (mat.channels() > 1) {
        cv::cvtColor(mat, gray, cv::COLOR_RGB2GRAY);
    } else {
        mat.copyTo(gray);
    }
    
    UIImage *grayImg = MatToUIImage(gray);
    return grayImg;
}

+ (UIImage *)resizeImg:(UIImage *)image :(int)width :(int)height :(int)interpolation {
    cv::Mat mat;
    [image convertToMat:&mat :false];
    
    if (mat.channels() == 4) {
        [image convertToMat:&mat :true];
    }
    
    NSLog(@"source shape = (%d, %d)", mat.cols, mat.rows);
    
    cv::Mat resized;
    cv::Size size = {width, height};
    cv::resize(mat, resized, size, 0, 0, interpolation);
    
    NSLog(@"dst shape = (%d, %d)", resized.cols, resized.rows);
    
    UIImage *resizedImg = MatToUIImage(resized);
    return resizedImg;
}

- (nullable NSArray<NSNumber *> *)extractFeatures:(UIImage *)image 
									withNormalize:(BOOL)shouldNormalize
											error:(NSError **)error {
    const int ROI_SIZE = 512;
    NSMutableArray<NSNumber *> *features = [NSMutableArray arrayWithCapacity:19];
    
    // Convert UIImage to cv::Mat
    cv::Mat mat;
    [image convertToMat:&mat :false];
    
    if (mat.empty()) {
        if (error) {
            *error = [NSError errorWithDomain:OpenCVFeatureExtractionErrorDomain
                                       code:OpenCVFeatureExtractionErrorImageConversion
                                   userInfo:@{NSLocalizedDescriptionKey: @"Failed to convert UIImage to cv::Mat"}];
        }
        return nil;
    }
    
    try {
        // Extract ROI
        cv::Mat roi = extractCenterROI(mat, ROI_SIZE);
        if (roi.empty()) {
            if (error) {
                *error = [NSError errorWithDomain:OpenCVFeatureExtractionErrorDomain
                                           code:OpenCVFeatureExtractionErrorROIExtraction
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract ROI"}];
            }
            return nil;
        }
        
        // Normalize lighting if requested
        cv::Mat processed = shouldNormalize ? normalizeLighting(roi) : roi;
        
        // Split into channels for RGB features
        std::vector<cv::Mat> rgbChannels;
        cv::split(processed, rgbChannels);
        
        // RGB means
        for (const cv::Mat& channel : rgbChannels) {
            [features addObject:@(computeMean(channel))];
        }
        
        // RGB standard deviations
        for (const cv::Mat& channel : rgbChannels) {
            [features addObject:@(computeStdDev(channel))];
        }
        
        // RGB variances (square of standard deviation)
        for (const cv::Mat& channel : rgbChannels) {
            float stddev = computeStdDev(channel);
            [features addObject:@(stddev * stddev)];
        }
        
        // Convert to HSV and split channels
        cv::Mat hsv;
        cv::cvtColor(processed, hsv, cv::COLOR_BGR2HSV);
        std::vector<cv::Mat> hsvChannels;
        cv::split(hsv, hsvChannels);
        
        // HSV means
        for (const cv::Mat& channel : hsvChannels) {
            [features addObject:@(computeMean(channel))];
        }
        
        // HSV standard deviations
        for (const cv::Mat& channel : hsvChannels) {
            [features addObject:@(computeStdDev(channel))];
        }
        
        // Convert to LAB and split channels
        cv::Mat lab;
        cv::cvtColor(processed, lab, cv::COLOR_BGR2Lab);
        std::vector<cv::Mat> labChannels;
        cv::split(lab, labChannels);
        
        // LAB means
        for (const cv::Mat& channel : labChannels) {
            [features addObject:@(computeMean(channel))];
        }
        
        // Convert to grayscale and compute entropy
        cv::Mat gray;
        cv::cvtColor(processed, gray, cv::COLOR_BGR2GRAY);
        float entropy = computeEntropy(gray);
        [features addObject:@(entropy)];
        
    } catch (const cv::Exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:OpenCVFeatureExtractionErrorDomain
                                       code:OpenCVFeatureExtractionErrorComputation
                                   userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    }
    
    return features;
}

@end
