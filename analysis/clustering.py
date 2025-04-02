import os
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib.pyplot as plt
import cv2
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA

# Load and preprocess the dataset
def load_and_preprocess_data(csv_path, image_dir):
    df = pd.read_csv(csv_path)
    df = df[df['Image_Path'].apply(lambda x: os.path.exists(f"{image_dir}/{x.split('/')[-1]}"))]
    df = df.reset_index(drop=True)
    return df

# Extract features from an image
def extract_features(image):
    # Convert to different color spaces
    rgb_mean = np.mean(image, axis=(0, 1))  # RGB mean
    rgb_std = np.std(image, axis=(0, 1))    # RGB std
    
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    hsv_mean = np.mean(hsv, axis=(0, 1))  # HSV mean
    
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    lab_mean = np.mean(lab, axis=(0, 1))  # LAB mean
    
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray_hist = np.histogram(gray, bins=32, range=(0, 256))[0]  # Grayscale histogram
    
    # Example texture feature: entropy
    entropy = -np.sum(gray_hist / np.sum(gray_hist) * np.log2(gray_hist / np.sum(gray_hist) + 1e-10))
    
    # Return all extracted features as a vector
    return np.concatenate([rgb_mean, rgb_std, hsv_mean, lab_mean, gray_hist, [entropy]])

# Extract features for all images in the dataset
def extract_features_from_dataset(df, image_dir):
    features = []
    for idx, row in df.iterrows():
        img_path = f"{image_dir}/{row['Image_Path'].split('/')[-1]}"
        image = cv2.imread(img_path)  # Load image using OpenCV
        if image is not None:
            features.append(extract_features(image))
    return np.array(features)

# Perform clustering on the extracted features
def perform_clustering(features, n_clusters=3):
    scaler = StandardScaler()
    features_scaled = scaler.fit_transform(features)
    
    # Optional: Reduce dimensionality for better clustering
    pca = PCA(n_components=10)
    features_reduced = pca.fit_transform(features_scaled)
    
    kmeans = KMeans(n_clusters=n_clusters, random_state=42)
    clusters = kmeans.fit_predict(features_reduced)
    return clusters

# Visualize clustering results
def visualize_clusters(df, clusters, image_dir, num_samples=5):
    df['Cluster'] = clusters
    df['Moisture_Class'] = pd.qcut(df['Moisture'], q=3, labels=['Low', 'Medium', 'High'])  # Add moisture class
    
    # Evaluate clustering performance
    print("Clustering performance:")
    for cluster in range(len(np.unique(clusters))):
        cluster_data = df[df['Cluster'] == cluster]
        class_distribution = cluster_data['Moisture_Class'].value_counts(normalize=True)
        print(f"Cluster {cluster}:")
        print(class_distribution)
        print()
    
    # 2D scatter plot of clustering results
    # print("Plotting 2D scatter of clustering results...")
    # numeric_columns = df.select_dtypes(include=[np.number]).columns  # Select only numeric columns
    # features_2d = PCA(n_components=2).fit_transform(StandardScaler().fit_transform(df[numeric_columns]))
    # plt.figure(figsize=(10, 7))
    # scatter = plt.scatter(features_2d[:, 0], features_2d[:, 1], c=clusters, cmap='viridis', alpha=0.7)
    # plt.colorbar(scatter, label='Cluster')
    # plt.title("2D Scatter Plot of Clustering Results")
    # plt.xlabel("PCA Component 1")
    # plt.ylabel("PCA Component 2")
    # plt.show()

# Main function
def main():
    csv_path = "../Soil-Moisture-Imaging-Data/Data-i11-ds/dataset_i11_ds.csv"
    image_dir = "../Soil-Moisture-Imaging-Data/Data-i11-ds/images"
    df = load_and_preprocess_data(csv_path, image_dir)
    
    # Extract features
    print("Extracting features from images...")
    features = extract_features_from_dataset(df, image_dir)
    
    # Perform clustering
    print("Performing clustering...")
    clusters = perform_clustering(features, n_clusters=3)
    
    # Visualize clustering results
    print("Visualizing clusters...")
    visualize_clusters(df, clusters, image_dir)

if __name__ == "__main__":
    main()