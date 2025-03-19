import cv2
import numpy as np

def load_and_preprocess_image(image_path, white_ref=255, black_ref=0):
    """
    Load an image, convert to grayscale, and apply brightness calibration.
    """
    # Load image
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError("Image not found or cannot be loaded.")
    
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Normalize brightness using reference white and black points
    min_val, max_val, _, _ = cv2.minMaxLoc(gray)
    normalized_gray = ((gray - min_val) / (max_val - min_val)) * (white_ref - black_ref)
    
    return normalized_gray.astype(np.uint8)

def extract_gray_level(image, roi=None):
    """
    Extract average gray level from a given region of interest (ROI).
    If ROI is None, uses the entire image.
    """
    if roi:
        x, y, w, h = roi
        roi_image = image[y:y+h, x:x+w]
    else:
        roi_image = image
    
    return np.mean(roi_image)

def apply_brightness_calibration(image, white_ref=255, black_ref=0):
    """
    Apply brightness calibration using white and black reference points.
    """
    min_val, max_val, _, _ = cv2.minMaxLoc(image)
    calibrated = ((image - min_val) / (max_val - min_val)) * (white_ref - black_ref)
    return calibrated.astype(np.uint8)

def eliminate_gloss(image, threshold=10):
    """
    Remove gloss effects by filtering out extreme bright spots.
    """
    mean_val = np.mean(image)
    filtered = np.where(image > mean_val + threshold, mean_val, image)
    return filtered.astype(np.uint8)

def estimate_soil_moisture(gray_level, GL_0=157, GL_s=75, u_s=50):
    """
    Estimate soil water content (SWC) from gray level using the model equation.
    GL_0: Gray level at saturation (100% SWC)
    GL_s: Gray level at dry soil (0% SWC)
    u_s: Maximum SWC value (saturated soil)
    These values are all specific to the calibration process.
    """
    if gray_level < GL_s or gray_level > GL_0:
        raise ValueError("Gray level out of expected range.")
    
    swc = u_s - u_s * np.sqrt((gray_level - GL_s) / (GL_0 - GL_s))
    return swc

def draw_roi(image):
    """
    Let user draw a rectangular ROI on the image.
    Returns the ROI coordinates (x, y, w, h) or None if cancelled.
    """
    cv2.namedWindow("Draw ROI", cv2.WINDOW_AUTOSIZE)
    roi = cv2.selectROI("Draw ROI", image, fromCenter=False, showCrosshair=True)
    cv2.destroyWindow("Draw ROI")
    
    # Check if ROI selection was cancelled or invalid
    if roi[2] == 0 or roi[3] == 0:  # Width or height is 0
        return None
    return roi

def resize_to_max_dimension(image, max_dimension=800):
    """
    Resize image to fit within max_dimension while maintaining aspect ratio.
    """
    height, width = image.shape[:2]
    if height <= max_dimension and width <= max_dimension:
        return image
    
    # Calculate new dimensions
    if height > width:
        new_height = max_dimension
        new_width = int(width * (max_dimension / height))
    else:
        new_width = max_dimension
        new_height = int(height * (max_dimension / width))
    
    return cv2.resize(image, (new_width, new_height), interpolation=cv2.INTER_AREA)

def process_soil_image(image_path, roi=None, max_dimension=800):
    """
    Complete pipeline: load image, preprocess, extract gray level, and estimate SWC,
    with visualization of ROI and prediction.
    """
    try:
        # Load and preprocess
        image = load_and_preprocess_image(image_path)
        
        # Apply brightness calibration
        calibrated_image = apply_brightness_calibration(image)
        
        # Remove gloss
        gloss_removed_image = eliminate_gloss(calibrated_image)
        
        # Create visualization
        display_image = cv2.cvtColor(gloss_removed_image, cv2.COLOR_GRAY2BGR)
        
        # Resize display image if too large
        display_image = resize_to_max_dimension(display_image, max_dimension)
        
        # Create window with fixed size
        cv2.namedWindow('Soil Moisture Analysis', cv2.WINDOW_AUTOSIZE)
        
        # Let user draw ROI if not provided
        if roi is None:
            roi = draw_roi(display_image)
            if roi is None:  # User cancelled ROI selection
                cv2.destroyAllWindows()
                return None, None, None
        
        # Extract gray level and estimate soil moisture
        # Note: Use original gloss_removed_image for calculations
        if roi is not None:
            # Scale ROI back to original image dimensions if needed
            scale_h = gloss_removed_image.shape[0] / display_image.shape[0]
            scale_w = gloss_removed_image.shape[1] / display_image.shape[1]
            orig_roi = (
                int(roi[0] * scale_w),
                int(roi[1] * scale_h),
                int(roi[2] * scale_w),
                int(roi[3] * scale_h)
            )
            gray_level = extract_gray_level(gloss_removed_image, orig_roi)
        else:
            gray_level = extract_gray_level(gloss_removed_image)
        
        swc = estimate_soil_moisture(gray_level)
        
        # Draw ROI on display image
        x, y, w, h = roi
        cv2.rectangle(display_image, (x, y), (x+w, y+h), (0, 255, 0), 2)
        
        # Add prediction label
        label = f"SWC: {swc:.1f}%"
        cv2.putText(display_image, label, (10, 30), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        
        # Show image and wait for key
        cv2.imshow('Soil Moisture Analysis', display_image)
        key = cv2.waitKey(0) & 0xFF
        cv2.destroyAllWindows()
        
        if key == 27 or key == ord('q'):  # ESC or 'q' key
            return None, None, None
            
        return swc, display_image, roi
        
    except Exception as e:
        print(f"Error processing image: {str(e)}")
        cv2.destroyAllWindows()
        return None, None, None
    finally:
        # Ensure all windows are closed
        cv2.destroyAllWindows()
        for i in range(1):  # Sometimes needed to close all windows
            cv2.waitKey(1)

# Example usage with improved error handling
if __name__ == "__main__":
    image_path = "humid.jpg"  # Replace with actual image path
    try:
        result = process_soil_image(image_path)
        if result[0] is not None:
            swc, annotated_image, roi = result
            print(f"Estimated Soil Water Content: {swc:.2f}%")
            print(f"Selected ROI: {roi}")
        else:
            print("Processing cancelled by user")
    except Exception as e:
        print(f"Error: {str(e)}")
    finally:
        cv2.destroyAllWindows()
        for i in range(1):  # Extra cleanup
            cv2.waitKey(1)
