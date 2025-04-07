"""
Classification utilities for soil moisture prediction using image data.
The main functions exported are 
    - `load_data`
    - `prepare_features`
    - `perform_evaluation`
    - `save_model`
    - `perform_inference`
Usage can be found in `knn_classifier.py` and `svm_classifier.py`.
Please avoid from using these when you are doing regression tasks, there will
almost definitely be minor incompatibilities that result in errors.
"""

import cv2
import numpy as np
import pandas as pd
import os
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, classification_report
import joblib
from typing import Tuple, List, Dict, Any

# Constants
ROI_SIZE: Tuple[int, int] = (256, 256)
AUGMENTATION_PARAMS: Dict[str, List[int]] = {
    'brightness': [-10, 10],
    'rotation': [-5, 5],
}
FEATURE_NAMES = [
    'mean_R', 'mean_G', 'mean_B',
    'std_R', 'std_G', 'std_B',
    'var_R', 'var_G', 'var_B',
    'mean_H', 'mean_S', 'mean_V',
    'std_H', 'std_S', 'std_V',
    'mean_L', 'mean_A', 'mean_B',
    'entropy'
]

def load_data(csv_path: str, image_dir: str) -> Tuple[pd.DataFrame, str]:
    """Load dataset from CSV and image directory."""
    df = pd.read_csv(csv_path)
    return df, image_dir

def normalize_lighting(img: np.ndarray) -> np.ndarray:
    """Normalize lighting in the image using LAB color space."""
    img_lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    img_lab[:, :, 0] = 128  # Fix brightness
    return cv2.cvtColor(img_lab, cv2.COLOR_LAB2BGR)

def get_center_roi(img: np.ndarray, roi_size: Tuple[int, int]) -> np.ndarray:
    """Extract a centered ROI from the image."""
    h, w = img.shape[:2]
    roi_h, roi_w = roi_size
    
    # Calculate center coordinates
    center_y = h // 2
    center_x = w // 2
    
    # Calculate ROI boundaries
    start_y = center_y - (roi_h // 2)
    start_x = center_x - (roi_w // 2)
    
    # Ensure ROI doesn't exceed image boundaries
    start_y = max(0, start_y)
    start_x = max(0, start_x)
    end_y = min(h, start_y + roi_h)
    end_x = min(w, start_x + roi_w)
    
    return img[start_y:end_y, start_x:end_x]

def augment_image(img: np.ndarray) -> List[np.ndarray]:
    """Apply random augmentation to image."""
    augmented = []
    h, w = img.shape[:2]
    
    # Original image
    augmented.append(img.copy())
    
    # Brightness adjustment
    bright = img.copy()
    bright = cv2.add(bright, np.random.randint(*AUGMENTATION_PARAMS['brightness']))
    augmented.append(bright)
    
    # Rotation
    angle = np.random.uniform(*AUGMENTATION_PARAMS['rotation'])
    matrix = cv2.getRotationMatrix2D((w/2, h/2), angle, 1.0)
    rotated = cv2.warpAffine(img, matrix, (w, h))
    augmented.append(rotated)
    
    return augmented

def entropy(img: np.ndarray) -> float:
    """Calculate image entropy for feature extraction."""
    hist = cv2.calcHist([img], [0], None, [256], [0, 256])
    hist = hist.ravel() / hist.sum()
    return -np.sum(hist * np.log2(hist + 1e-7))

def extract_features(image_path: str, normalize: bool = True, 
                     augment: bool = False) -> List[List[float]]:
    """Extract features from a single image.
    
    Returns:
        List of feature vectors, where each vector contains the following features in order:
        - RGB means (3)
        - RGB standard deviations (3)
        - RGB variances (3)
        - HSV means (3)
        - HSV standard deviations (3)
        - LAB means (3)
        - Entropy (1)
        Total: 19 features
    """
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    
    img = get_center_roi(img, ROI_SIZE)
    if normalize:
        img = normalize_lighting(img)
    
    features_list = []
    images_to_process = augment_image(img) if augment else [img]
    
    for processed_img in images_to_process:
        img_rgb = cv2.cvtColor(processed_img, cv2.COLOR_BGR2RGB)
        img_hsv = cv2.cvtColor(processed_img, cv2.COLOR_BGR2HSV)
        img_lab = cv2.cvtColor(processed_img, cv2.COLOR_BGR2LAB)
        
        # Initialize feature vector with fixed order
        features = []
        
        # RGB features
        for i in range(3):
            features.append(np.mean(img_rgb[:,:,i]))  # RGB means
        for i in range(3):
            features.append(np.std(img_rgb[:,:,i]))   # RGB std devs
        for i in range(3):
            features.append(np.var(img_rgb[:,:,i]))   # RGB variances
            
        # HSV features
        for i in range(3):
            features.append(np.mean(img_hsv[:,:,i]))  # HSV means
        for i in range(3):
            features.append(np.std(img_hsv[:,:,i]))   # HSV std devs
            
        # LAB features
        for i in range(3):
            features.append(np.mean(img_lab[:,:,i]))  # LAB means
            
        # Texture features
        gray = cv2.cvtColor(processed_img, cv2.COLOR_BGR2GRAY)
        features.append(entropy(gray))
        
        features_list.append(features)
    
    return features_list

def prepare_features(df: pd.DataFrame, image_dir: str,
                     normalize: bool = True, augment: bool = False) -> Tuple[np.ndarray, np.ndarray]:
    """Prepare features and labels from the dataset."""
    X, y = [], []
    for _, row in df.iterrows():
        img_path = os.path.join(image_dir, row["Image"])
        features_list = extract_features(img_path, normalize, augment)
        X.extend(features_list)
        y.extend([row["Class"]] * len(features_list))
    return np.array(X), np.array(y)

def plot_confusion_matrix(true_values: np.ndarray, predictions: np.ndarray) -> None:
    """Plot confusion matrix."""
    plt.figure(figsize=(8, 6))
    cm = confusion_matrix(true_values, predictions)
    classes = ['Dry', 'Moist', 'Wet']
    
    plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    plt.title('Confusion Matrix')
    plt.colorbar()
    
    # Add labels
    tick_marks = np.arange(len(classes))
    plt.xticks(tick_marks, classes)
    plt.yticks(tick_marks, classes)
    
    # Add text annotations
    thresh = cm.max() / 2.
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, format(cm[i, j], 'd'),
                    ha="center", va="center",
                    color="white" if cm[i, j] > thresh else "black")
    
    plt.xlabel('Predicted')
    plt.ylabel('True')
    plt.tight_layout()
    plt.show()

def create_classification_report(true_values: np.ndarray, predictions: np.ndarray) -> Dict[str, Any]:
    """Create a classification report."""
    report = classification_report(true_values, predictions)
    return report

def perform_evaluation(true_values: np.ndarray, predictions: np.ndarray) -> None:
    """Evaluate model performance."""
    report = create_classification_report(true_values, predictions)
    print("\nClassification Report:")
    print(report)
    
    # Plot confusion matrix
    print("\nGenerating confusion matrix...")
    plot_confusion_matrix(true_values, predictions)

def save_model(model: Any, scaler: Any, feature_names: List[str], class_names: List[str], model_file: str, model_type: str = 'KNN') -> str:
    """Save the trained model and scaler."""
    model_data = {
        'model': model,
        'scaler': scaler,
        'feature_names': feature_names,
        'class_names': class_names,
        'model_type': model_type,
        'created_date': pd.Timestamp.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    joblib.dump(model_data, model_file)
    print(f"Model saved to {model_file}")
    return model_file

def perform_inference(image_path: str, model_file: str ="soil_svm_classifier.joblib") -> Dict[str, Any]:
    """
    Load model and predict soil moisture from a new image
    """
    # Load the saved model
    saved = joblib.load(model_file)
    model, scaler = saved['model'], saved['scaler']
    class_names = saved['class_names']
    
    # Extract features from new image (no augmentation for inference)
    features = extract_features(image_path, normalize=True, augment=False)[0]
    
    # Scale and predict
    features_scaled = scaler.transform([features])
    prediction = model.predict(features_scaled)[0]
    probabilities = model.predict_proba(features_scaled)[0]
    
    result = {
        'class': prediction,
        'class_name': class_names[prediction],
        'probabilities': {class_names[i]: float(prob) for i, prob in enumerate(probabilities)}
    }
    
    return result
