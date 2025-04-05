import cv2
import numpy as np
import argparse

THETA_S = 17 # Saturated moisture content (%)
GL_0 = 120 # Gray level at dry soil (0% SWC)
GL_S = 95 # Gray level at saturation (100% SWC)

def estimate_swc(G, G0=GL_0, Gs=GL_S, theta_s=THETA_S):
    """
    Predict soil moisture from gray level using Eq. 14
    G0: gray level of dry soil
    Gs: gray level of saturated soil
    thetas: saturated moisture content (%)
    """
    if G > G0 or G < Gs:
        print("Invalid gray level:", G)
        return 0

    ratio = (G - Gs) / (G0 - Gs)
    if ratio < 0 or ratio > 1:
        print("Invalid ratio:", ratio)
        return 0  # physically invalid

    theta = theta_s * (1 - np.sqrt(ratio))
    return theta

def normalize(gray):
    """
    Percentile normalization of the grayscale image.
    Maps the pixel values to the range [0, 255] based on the 1st and 99th percentiles.
    """
    p1, p99 = np.percentile(gray, (1, 99))
    normalized = np.clip((gray - p1) * 255.0 / (p99 - p1), 0, 255).astype(np.uint8)
    return normalized

def preprocess_image(image, gloss_threshold=230):
    # Convert to grayscale and normalize
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = normalize(gray)

    # Remove glossy pixels
    no_gloss = gray.copy()
    no_gloss[no_gloss > gloss_threshold] = 0

    return gray, no_gloss

def analyze_soil(gray_img):
    valid_pixels = gray_img[gray_img > 0]
    avg_gray = np.mean(valid_pixels) if valid_pixels.size > 0 else 0
    swc = estimate_swc(avg_gray)
    return avg_gray, swc

def select_roi(image):
    """
    Allow the user to draw an ROI on the image.
    Returns the cropped ROI and the roi coordinates.
    """
    cv2.namedWindow("Select ROI", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("Select ROI", 700, 500)  # Larger window for better visibility
    roi = cv2.selectROI("Select ROI", image, fromCenter=False, showCrosshair=True, )
    cv2.destroyWindow("Select ROI")  # Ensure the ROI window is closed
    if roi == (0, 0, 0, 0):
        raise Exception("No ROI selected")
    x, y, w, h = roi
    return image[y:y+h, x:x+w], (x, y, w, h)

if __name__ == "__main__":
    try:
        parser = argparse.ArgumentParser(description="Analyze soil moisture from an image.")
        parser.add_argument(
            "-i", "--image", type=str, required=True, help="Path to the input image."
        )
        args = parser.parse_args()

        # Use provided image path
        img_path = args.image
        img = cv2.imread(img_path)
        if img is None:
            raise Exception(f"Could not read image from path: {img_path}")

        # Allow user to select ROI
        selected_roi, roi_coords = select_roi(img)
        x, y, w, h = roi_coords

        # Convert ROI to grayscale and preprocess
        gray, gray_no_gloss = preprocess_image(selected_roi)
        avg, swc = analyze_soil(gray)

        # Draw bounding box around the selected ROI
        cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 3)

        # Overlay text with larger font size and thickness
        cv2.putText(img, f"Gray Value: {avg:.2f}", (10, 100), cv2.FONT_HERSHEY_SIMPLEX, 
                    5, (255, 0, 0), thickness=5)
        cv2.putText(img, f"Soil Moisture: {swc:.2f}%", (10, 200), cv2.FONT_HERSHEY_SIMPLEX, 
                    5, (255, 0, 0), thickness=5)

        print(f"Gray Value (avg, gloss removed): {avg:.2f}")
        print(f"Estimated Soil Moisture: {swc:.2f}%")

        # Visual debug
        cv2.namedWindow("Analyzed Image", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("Analyzed Image", 700, 500)  # Larger window for better visibility
        cv2.imshow("Analyzed Image", img)
        
        print("Press any key or close the window to exit...")
        while cv2.getWindowProperty('Analyzed Image', cv2.WND_PROP_VISIBLE) > 0:
            keyCode = cv2.waitKey(100)
            if keyCode != -1:
                break
    finally:
        # Ensure all windows are properly closed
        cv2.destroyAllWindows()
        print("All windows closed, exiting program")
