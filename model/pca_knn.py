import pandas as pd
import numpy as np
import cv2
import os
from sklearn.decomposition import PCA
from sklearn.neighbors import KNeighborsRegressor
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import matplotlib.pyplot as plt

def load_data(csv_path, image_dir):
    df = pd.read_csv(csv_path)
    return df, image_dir

def extract_features(image_path):
    img = cv2.imread(image_path)
    if img is None:
        raise FileNotFoundError(f"Image not found: {image_path}")
    
    img = cv2.resize(img, (256, 256))  # resize to standard size
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    R, G, B = cv2.split(img)
    features = {
        'mean_R': np.mean(R),
        'mean_G': np.mean(G),
        'mean_B': np.mean(B),
        'var_R': np.var(R),
        'var_G': np.var(G),
        'var_B': np.var(B),
        'R_over_G': np.mean(R) / (np.mean(G) + 1e-5),
        'G_over_B': np.mean(G) / (np.mean(B) + 1e-5),
        'R_over_B': np.mean(R) / (np.mean(B) + 1e-5),
    }
    return list(features.values())

def prepare_features(df, image_dir):
    X = []
    y = []
    for i, row in df.iterrows():
        img_path = os.path.join(image_dir, row["Image"])
        features = extract_features(img_path)
        X.append(features)
        y.append(row["Moisture"])
    return np.array(X), np.array(y)

def preprocess_data(X):
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    pca = PCA(n_components=2)
    X_pca = pca.fit_transform(X_scaled)
    return X_pca, scaler, pca

def train_model(X_train, y_train, n_neighbors=2):
    knn = KNeighborsRegressor(n_neighbors=n_neighbors)
    knn.fit(X_train, y_train)
    return knn

def evaluate_model(model, X_test, y_test):
    y_pred = model.predict(X_test)
    mse = np.mean((y_test - y_pred) ** 2)
    rmse = np.sqrt(mse)
    return y_pred, rmse

def visualize_results(X_pca, y, title):
    plt.figure(figsize=(8,6))
    scatter = plt.scatter(X_pca[:, 0], X_pca[:, 1], c=y, cmap='coolwarm', s=100)
    plt.colorbar(scatter, label='Moisture Level (%)')
    plt.title(title)
    plt.xlabel('PC1')
    plt.ylabel('PC2')
    plt.grid(True)
    plt.show()

def main():
    # Load and prepare data
    df, image_dir = load_data("new_samples/samples.csv", "new_samples/")
    X, y = prepare_features(df, image_dir)
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)
    
    # Preprocess training data
    X_train_pca, scaler, pca = preprocess_data(X_train)
    
    # Transform test data using the same preprocessing
    X_test_scaled = scaler.transform(X_test)
    X_test_pca = pca.transform(X_test_scaled)
    
    # Train and evaluate model
    model = train_model(X_train_pca, y_train)
    y_pred, rmse = evaluate_model(model, X_test_pca, y_test)
    
    # Visualize results
    visualize_results(X_train_pca, y_train, 'Training Data: PCA of RGB features with Moisture Levels')
    visualize_results(X_test_pca, y_test, 'Test Data: PCA of RGB features with Moisture Levels')
    
    # Print results
    print(f"Model RMSE: {rmse:.2f}")
    print("\nTest Set Predictions:")
    for true, pred in zip(y_test, y_pred):
        print(f"True moisture: {true:.2f}, Predicted: {pred:.2f}")

if __name__ == "__main__":
    main()
