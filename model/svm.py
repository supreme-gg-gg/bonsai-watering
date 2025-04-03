import os
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split, KFold, cross_val_score
from sklearn.svm import SVC, SVR
from sklearn.metrics import classification_report, r2_score, mean_absolute_error, root_mean_squared_error
from skimage.io import imread
from sklearn.preprocessing import StandardScaler

# Load and preprocess the dataset
def load_and_preprocess_data(csv_path, image_dir):
    df = pd.read_csv(csv_path)
    df = df[df['Image_Path'].apply(lambda x: os.path.exists(f"{image_dir}/{x.split('/')[-1]}"))]
    df = df.reset_index(drop=True)
    df['Moisture_Class'] = pd.qcut(df['Moisture'], q=3, labels=['Low', 'Medium', 'High'])
    return df

# Updated load_and_preprocess_data to handle multiple datasets
def load_and_preprocess_data_multiple(csv_paths, image_dirs):
    """
    Load and preprocess datasets from multiple CSV files and image directories.
    Args:
        csv_paths (list): List of paths to CSV files.
        image_dirs (list): List of directories containing images.
    Returns:
        pd.DataFrame: Combined and preprocessed DataFrame.
    """
    dataframes = []
    for csv_path, image_dir in zip(csv_paths, image_dirs):
        df = pd.read_csv(csv_path)
        df = df[df['Image_Path'].apply(lambda x: os.path.exists(f"{image_dir}/{x.split('/')[-1]}"))]
        df = df.reset_index(drop=True)
        dataframes.append(df)
    combined_df = pd.concat(dataframes, ignore_index=True)
    combined_df['Moisture_Class'] = pd.qcut(combined_df['Moisture'], q=3, labels=['Low', 'Medium', 'High'])
    return combined_df

# Extract RGB features from images
def extract_rgb_features(image_dirs, image_paths):
    """
    Extract RGB features from images in multiple directories.
    Args:
        image_dirs (list): List of directories containing images.
        image_paths (pd.Series): Series of image paths.
    Returns:
        np.array: Array of extracted RGB features.
    """
    features = []
    for path in image_paths:
        image_found = False
        for image_dir in image_dirs:
            image_path = f"{image_dir}/{path.split('/')[-1]}"
            if os.path.exists(image_path):
                image = imread(image_path)
                if image.ndim == 3:  # Ensure the image is RGB
                    mean_rgb = image.mean(axis=(0, 1))  # Mean R, G, B values
                    features.append(mean_rgb)
                    image_found = True
                    break
                else:
                    print(f"Image {image_path} is not RGB, skipping.")
        if not image_found:
            print(f"Image {path} not found in any of the provided directories, skipping.")
    return np.array(features)

# Updated main functions to use multiple datasets
def train_svm_classifier(csv_paths, image_dirs):
    # Load and preprocess data
    df = load_and_preprocess_data_multiple(csv_paths, image_dirs)
    image_paths = df['Image_Path']
    labels = df['Moisture_Class']

    # Extract features
    features = extract_rgb_features(image_dirs, image_paths)

    print(features.shape)

    # Normalize features
    scaler = StandardScaler()
    features = scaler.fit_transform(features)

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(features, labels, test_size=0.2, random_state=42)

    # Train SVM classifier
    svm_model = SVC(kernel='linear', random_state=42)
    svm_model.fit(X_train, y_train)

    # Evaluate the classifier
    y_pred = svm_model.predict(X_test)
    print("Classification Report:")
    print(classification_report(y_test, y_pred))

def train_svr_regressor(csv_paths, image_dirs):
    # Load and preprocess data
    df = load_and_preprocess_data_multiple(csv_paths, image_dirs)
    image_paths = df['Image_Path']
    target = df['Moisture']

    # Extract features
    features = extract_rgb_features(image_dirs, image_paths)

    print(features.shape)

    # Normalize features
    scaler = StandardScaler()
    features = scaler.fit_transform(features)

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(features, target, test_size=0.2, random_state=42)

    # Train SVR model
    svr_model = SVR(kernel='linear')
    svr_model.fit(X_train, y_train)

    # Evaluate the regressor
    y_pred = svr_model.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    rmse = root_mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)
    print("Regression Evaluation:")
    print(f"Mean Absolute Error: {mae}")
    print(f"Root Mean Squared Error: {rmse}")
    print(f"R^2 Score: {r2}")

# Function to train and evaluate the SVM classifier using k-fold cross-validation
def train_svm_classifier_kfold(csv_path, image_dir, k=10):
    # Load and preprocess data
    df = load_and_preprocess_data(csv_path, image_dir)
    image_paths = df['Image_Path']
    labels = df['Moisture_Class']

    # Extract features
    features = extract_rgb_features([image_dir], image_paths)

    # Normalize features
    scaler = StandardScaler()
    features = scaler.fit_transform(features)

    # Perform k-fold cross-validation
    kf = KFold(n_splits=k, shuffle=True, random_state=42)
    svm_model = SVC(kernel='linear', random_state=42)
    scores = cross_val_score(svm_model, features, labels, cv=kf, scoring='f1_weighted')

    print(f"SVM Classifier - K-Fold Cross-Validation (k={k}):")
    print(f"F1 Weighted Scores: {scores}")
    print(f"Mean F1 Weighted Score: {scores.mean()}")

# Function to train and evaluate the SVR model using k-fold cross-validation
def train_svr_regressor_kfold(csv_path, image_dir, k=10):
    # Load and preprocess data
    df = load_and_preprocess_data(csv_path, image_dir)
    image_paths = df['Image_Path']
    target = df['Moisture']

    # Extract features
    features = extract_rgb_features([image_dir], image_paths)

    # Normalize features
    scaler = StandardScaler()
    features = scaler.fit_transform(features)

    # Perform k-fold cross-validation
    kf = KFold(n_splits=k, shuffle=True, random_state=42)
    svr_model = SVR(kernel='linear')
    scores = cross_val_score(svr_model, features, target, cv=kf, scoring='r2')

    print(f"SVR Regressor - K-Fold Cross-Validation (k={k}):")
    print(f"R^2 Scores: {scores}")
    print(f"Mean R^2 Score: {scores.mean()}")

# Example usage
if __name__ == "__main__":
    csv_paths = [
        "../Soil-Moisture-Imaging-Data/Data-i11-ds/dataset_i11_ds.csv",
        "../Soil-Moisture-Imaging-Data/Data-i11-is/dataset_i11_is.csv"
    ]
    image_dirs = [
        "../Soil-Moisture-Imaging-Data/Data-i11-ds/images",
        "../Soil-Moisture-Imaging-Data/Data-i11-is/images"
    ]
    
    print("Training SVM Classifier:")
    train_svm_classifier(csv_paths, image_dirs)
    
    print("\nTraining SVR Regressor:")
    train_svr_regressor(csv_paths, image_dirs)
