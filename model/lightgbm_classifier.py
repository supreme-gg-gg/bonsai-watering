import os
import cv2
import numpy as np
import pandas as pd
import random
import matplotlib.pyplot as plt
import joblib
from typing import Tuple, List, Dict, Any

import lightgbm as lgb
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix

# Constants
ROI_SIZE = (256, 256)
CLASS_NAMES = ['Dry', 'Moist', 'Wet']


# --- IMAGE PROCESSING AND FEATURE EXTRACTION FUNCTIONS ---

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

def normalize_lighting(img: np.ndarray) -> np.ndarray:
    """Normalize lighting in the image using LAB color space."""
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    l_channel, a, b = cv2.split(lab)
    
    # Apply CLAHE to L-channel
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    cl = clahe.apply(l_channel)
    
    # Merge the CLAHE enhanced L-channel with the A and B channels
    merged = cv2.merge((cl, a, b))
    
    # Convert back to BGR color space
    return cv2.cvtColor(merged, cv2.COLOR_LAB2BGR)

def entropy(img: np.ndarray) -> float:
    """Calculate image entropy for texture analysis."""
    hist = cv2.calcHist([img], [0], None, [256], [0, 256])
    hist = hist / hist.sum()
    non_zero = hist > 0
    return -np.sum(hist[non_zero] * np.log2(hist[non_zero]))

def extract_features(img: np.ndarray) -> np.ndarray:
    """Extract comprehensive features from the image."""
    features = []
    
    # Convert to different color spaces
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # RGB statistics (mean, std, var for each channel)
    for i in range(3):
        features.append(np.mean(rgb[:,:,i]))
        features.append(np.std(rgb[:,:,i]))
        features.append(np.var(rgb[:,:,i]))
    
    # HSV statistics
    for i in range(3):
        features.append(np.mean(hsv[:,:,i]))
        features.append(np.std(hsv[:,:,i]))
    
    # LAB statistics
    for i in range(3):
        features.append(np.mean(lab[:,:,i]))
    
    # Texture features from grayscale
    features.append(entropy(gray))
    
    # Add histogram features (8 bins per channel)
    hist_bins = 8
    for i in range(3):
        hist = cv2.calcHist([rgb], [i], None, [hist_bins], [0, 256])
        features.extend(hist.flatten())
    
    # Add Haralick texture features (simplified)
    glcm = cv2.GaussianBlur(gray, (5, 5), 0)
    features.append(np.mean(glcm))
    features.append(np.std(glcm))
    
    return np.array(features)


# --- DATA LOADING AND PREPARATION FUNCTIONS ---

def load_image_data(csv_path: str, image_dir: str) -> Tuple[List[np.ndarray], List[int]]:
    """Load images and labels from CSV file."""
    print(f"Loading data from {csv_path}")
    
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV file not found at: {csv_path}")
    
    df = pd.read_csv(csv_path)
    images = []
    labels = []
    
    print(f"Found {len(df)} entries in the dataset")
    
    for _, row in df.iterrows():
        img_path = os.path.join(image_dir, row["Image"])
        
        if not os.path.exists(img_path):
            print(f"Warning: Image not found at {img_path}")
            continue
        
        img = cv2.imread(img_path)
        
        if img is None:
            print(f"Warning: Could not read image at {img_path}")
            continue
        
        # Apply ROI and normalization
        img = get_center_roi(img, ROI_SIZE)
        img = normalize_lighting(img)
        
        images.append(img)
        labels.append(row["Class"])
    
    print(f"Successfully loaded {len(images)} images")
    return images, labels

def prepare_feature_dataset(images: List[np.ndarray], labels: List[int]) -> Tuple[np.ndarray, np.ndarray]:
    """Extract features from all images into a feature matrix."""
    print("Extracting features from images...")
    X = []
    y = np.array(labels)
    
    for img in images:
        features = extract_features(img)
        X.append(features)
    
    X = np.array(X)
    print(f"Extracted {X.shape[1]} features from each image")
    
    # Check for and handle problematic values
    if np.isnan(X).any():
        print("Warning: NaN values found in features. Replacing with zeros.")
        X = np.nan_to_num(X)
    
    if np.isinf(X).any():
        print("Warning: Infinite values found in features. Replacing with large values.")
        X = np.where(np.isinf(X), np.sign(X) * 1e10, X)
    
    return X, y


# --- MODEL TRAINING AND EVALUATION FUNCTIONS ---

def train_lgbm_model(X: np.ndarray, y: np.ndarray) -> Tuple[Any, Any]:
    """Train a LightGBM model on the dataset."""
    print("Training LightGBM model...")
    
    # Scale features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Configure LightGBM with parameters suitable for small datasets
    params = {
        'objective': 'multiclass',
        'num_class': len(np.unique(y)),
        'boosting_type': 'gbdt',
        'num_leaves': 10,  # Lower to avoid overfitting
        'learning_rate': 0.05,
        'feature_fraction': 0.8,
        'bagging_fraction': 0.8,
        'bagging_freq': 1,
        'verbose': 0,
        'min_data_in_leaf': 1,  # Lower for small dataset
        'n_estimators': 100
    }
    
    model = lgb.LGBMClassifier(**params)
    
    # Try/except to catch any LightGBM errors
    try:
        model.fit(X_scaled, y)
        print("Model training completed successfully")
    except Exception as e:
        print(f"Error during model training: {e}")
        return None, scaler
    
    return model, scaler

def perform_loocv(X: np.ndarray, y: np.ndarray) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Perform leave-one-out cross-validation."""
    print("Performing leave-one-out cross-validation...")
    
    loo = LeaveOneOut()
    predictions = []
    true_values = []
    probabilities = []
    
    # Parameters suitable for small datasets
    params = {
        'objective': 'multiclass',
        'num_class': len(np.unique(y)),
        'boosting_type': 'gbdt',
        'num_leaves': 10,
        'learning_rate': 0.05,
        'feature_fraction': 0.8,
        'bagging_fraction': 0.8,
        'bagging_freq': 1,
        'verbose': -1,
        'min_data_in_leaf': 1,
        'n_estimators': 100
    }
    
    for i, (train_idx, test_idx) in enumerate(loo.split(X)):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        
        # Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        # Train model
        model = lgb.LGBMClassifier(**params)
        
        try:
            model.fit(X_train_scaled, y_train)
            
            # Make predictions
            pred = model.predict(X_test_scaled)
            prob = model.predict_proba(X_test_scaled)
            
            predictions.append(pred[0])
            true_values.append(y_test[0])
            probabilities.append(prob[0])
            
            if (i+1) % 5 == 0 or i == len(X) - 1:
                print(f"Processed {i+1}/{len(X)} cross-validation folds")
                
        except Exception as e:
            print(f"Error in fold {i+1}: {e}")
            predictions.append(-1)  # Mark as error
            true_values.append(y_test[0])
            probabilities.append(np.zeros(len(np.unique(y))))
    
    return np.array(predictions), np.array(true_values), np.array(probabilities)


# --- VISUALIZATION AND EVALUATION FUNCTIONS ---

def plot_confusion_matrix(true_values: np.ndarray, predictions: np.ndarray) -> None:
    """Plot confusion matrix."""
    # Filter out any error predictions (-1)
    mask = predictions != -1
    true_values = true_values[mask]
    predictions = predictions[mask]
    
    plt.figure(figsize=(8, 6))
    cm = confusion_matrix(true_values, predictions)
    
    plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
    plt.title('Confusion Matrix')
    plt.colorbar()
    
    # Add labels
    tick_marks = np.arange(len(CLASS_NAMES))
    plt.xticks(tick_marks, CLASS_NAMES)
    plt.yticks(tick_marks, CLASS_NAMES)
    
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
    plt.savefig('lgbm_confusion_matrix.png')
    plt.show()

def plot_feature_importance(model: lgb.LGBMClassifier) -> None:
    """Plot feature importance."""
    if model is None:
        print("Error: Model is None, cannot plot feature importance")
        return
    
    plt.figure(figsize=(10, 8))
    lgb.plot_importance(model, max_num_features=20)
    plt.title('Feature Importance')
    plt.tight_layout()
    plt.savefig('lgbm_feature_importance.png')
    plt.show()


# --- MODEL SAVING AND PREDICTION FUNCTIONS ---

def save_model(model: Any, scaler: Any, model_file: str = "soil_lgbm_classifier.joblib") -> None:
    """Save the trained model and scaler."""
    if model is None:
        print("Error: Cannot save None model")
        return
    
    model_data = {
        'model': model,
        'scaler': scaler,
        'class_names': CLASS_NAMES,
        'timestamp': pd.Timestamp.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    
    joblib.dump(model_data, model_file)
    print(f"Model saved to {model_file}")

def load_model(model_file: str = "soil_lgbm_classifier.joblib") -> Tuple[Any, Any]:
    """Load a trained model from file."""
    try:
        model_data = joblib.load(model_file)
        model = model_data['model']
        scaler = model_data['scaler']
        return model, scaler
    except Exception as e:
        print(f"Error loading model: {e}")
        return None, None

def predict_moisture(image_path: str, model_file: str = "soil_lgbm_classifier.joblib") -> Dict:
    """Predict soil moisture from a new image."""
    try:
        # Load the model
        model, scaler = load_model(model_file)
        if model is None:
            return {"error": "Failed to load model"}
        
        # Read and preprocess the image
        img = cv2.imread(image_path)
        if img is None:
            return {"error": f"Failed to read image: {image_path}"}
        
        img = get_center_roi(img, ROI_SIZE)
        img = normalize_lighting(img)
        
        # Extract features
        features = extract_features(img)
        
        # Scale features
        features_scaled = scaler.transform([features])
        
        # Predict
        prediction = model.predict(features_scaled)[0]
        probabilities = model.predict_proba(features_scaled)[0]
        
        # Create result dict
        result = {
            'class_index': int(prediction),
            'class_name': CLASS_NAMES[prediction],
            'probabilities': {CLASS_NAMES[i]: float(prob) for i, prob in enumerate(probabilities)}
        }
        
        return result
    except Exception as e:
        return {"error": str(e)}


# --- MAIN FUNCTION ---

def main():
    # Set paths
    csv_path = "../new_samples/samples.csv"
    image_dir = "../new_samples/"
    
    # Load data
    images, labels = load_image_data(csv_path, image_dir)
    if len(images) == 0:
        print("Error: No valid images found. Exiting.")
        return
    
    # Extract features
    X, y = prepare_feature_dataset(images, labels)
    print(f"Dataset shape: {X.shape}")
    
    # Print class distribution
    unique, counts = np.unique(y, return_counts=True)
    class_dist = dict(zip(unique, counts))
    print(f"Class distribution: {class_dist}")
    
    # Perform leave-one-out cross-validation
    predictions, true_values, probabilities = perform_loocv(X, y)
    
    # Evaluate model
    valid_mask = predictions != -1
    valid_preds = predictions[valid_mask]
    valid_truth = true_values[valid_mask]
    
    if len(valid_preds) > 0:
        print("\nClassification Report:")
        print(classification_report(valid_truth, valid_preds, target_names=CLASS_NAMES))
        print(f"Accuracy: {accuracy_score(valid_truth, valid_preds):.4f}")
        
        # Plot confusion matrix
        plot_confusion_matrix(true_values, predictions)
    else:
        print("Error: No valid predictions to evaluate")
    
    # Train final model on all data
    model, scaler = train_lgbm_model(X, y)
    
    if model is not None:
        # Plot feature importance
        plot_feature_importance(model)
        
        # Save the model
        save_model(model, scaler)
        
        print("\nExample of model usage:")
        print("from standalone_lgbm import predict_moisture")
        print("result = predict_moisture('new_image.jpg')")
        print("print(f\"Predicted soil moisture: {result['class_name']}\")")

if __name__ == "__main__":
    main()