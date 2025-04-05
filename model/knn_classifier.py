import pandas as pd
import numpy as np
import cv2
import os
import matplotlib.pyplot as plt
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import LeaveOneOut
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import confusion_matrix, classification_report

# Configuration constants
APPLY_LIGHTING_NORMALIZATION = True
ROI_SIZE = (256, 256)
AUGMENTATION_PARAMS = {
    'brightness': [-10, 10],
    'rotation': [-5, 5],
}

def load_data(csv_path, image_dir):
    df = pd.read_csv(csv_path)
    return df, image_dir

def normalize_lighting(img):
    img_lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
    img_lab[:, :, 0] = 128  # Fix brightness
    return cv2.cvtColor(img_lab, cv2.COLOR_LAB2BGR)

def get_center_roi(img, roi_size):
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

def augment_image(img):
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

def extract_features(image_path, normalize=True, augment=True):
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
        
        # Extract features from multiple color spaces
        features = {}
        
        # RGB features
        for i, channel in enumerate(['R', 'G', 'B']):
            features[f'mean_{channel}'] = np.mean(img_rgb[:,:,i])
            features[f'std_{channel}'] = np.std(img_rgb[:,:,i])
            features[f'var_{channel}'] = np.var(img_rgb[:,:,i])
        
        # HSV features
        for i, channel in enumerate(['H', 'S', 'V']):
            features[f'mean_{channel}'] = np.mean(img_hsv[:,:,i])
            features[f'std_{channel}'] = np.std(img_hsv[:,:,i])
        
        # LAB features
        for i, channel in enumerate(['L', 'A', 'B']):
            features[f'mean_{channel}'] = np.mean(img_lab[:,:,i])
        
        # Texture features (using grayscale)
        gray = cv2.cvtColor(processed_img, cv2.COLOR_BGR2GRAY)
        features['entropy'] = entropy(gray)
        
        features_list.append(list(features.values()))
    
    return features_list

def entropy(img):
    """Calculate image entropy."""
    hist = cv2.calcHist([img], [0], None, [256], [0, 256])
    hist = hist.ravel() / hist.sum()
    return -np.sum(hist * np.log2(hist + 1e-7))

def prepare_features(df, image_dir, normalize=True, augment=True):
    X, y = [], []
    for _, row in df.iterrows():
        img_path = os.path.join(image_dir, row["Image"])
        features_list = extract_features(img_path, normalize, augment)
        X.extend(features_list)
        y.extend([row["Class"]] * len(features_list))
    return np.array(X), np.array(y)

def perform_loocv(X, y, n_neighbors=3, weights='distance'):
    loo = LeaveOneOut()
    predictions = []
    true_values = []
    
    for train_idx, test_idx in loo.split(X):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        
        scaler = MinMaxScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        model = KNeighborsClassifier(n_neighbors=n_neighbors, weights=weights)
        model.fit(X_train_scaled, y_train)
        pred = model.predict(X_test_scaled)
        
        predictions.append(pred[0])
        true_values.append(y_test[0])
    
    return np.array(predictions), np.array(true_values)

def plot_confusion_matrix(true_values, predictions):
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

def main():
    df, image_dir = load_data("new_samples/samples.csv", "new_samples/")
    X, y = prepare_features(df, image_dir, normalize=APPLY_LIGHTING_NORMALIZATION, augment=True)
    
    # Perform LOOCV
    predictions, true_values = perform_loocv(X, y, n_neighbors=3, weights='distance')
    
    # Print classification report
    print("\nClassification Report:")
    print(classification_report(true_values, predictions))
    
    # Plot confusion matrix
    plot_confusion_matrix(true_values, predictions)

if __name__ == "__main__":
    main()
