//
//  OpenCVWrapper.h
//  Bonsense
//
//  Created by Jet Chiang on 2025-04-07.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVUtils : NSObject
- (NSString *)getOpenCVVersion;
- (UIImage *)grayscaleImg: (UIImage *)image;
- (UIImage *)resizeImg: (UIImage *)image
					  : (int)width
					  : (int)height
					  : (int)interpolation;
- (nullable NSArray<NSNumber *> *) extractFeatures: (UIImage *)image
									 withNormalize: (BOOL)shouldNormalize
											 error: (NSError **)error;
@end

NS_ASSUME_NONNULL_END
