import os
import numpy as np
import pandas as pd
import cv2
from sklearn.decomposition import PCA
# from sklearn.manifold import TSNE
from sklearn.cluster import KMeans, DBSCAN
from scipy.stats import f_oneway
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler

# Example function to extract features from an image
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
    
    # Example texture feature: entropy (can be more elaborate)
    entropy = -np.sum(gray_hist / np.sum(gray_hist) * np.log2(gray_hist / np.sum(gray_hist) + 1e-10))
    
    # Return all extracted features as a vector
    return np.concatenate([rgb_mean, rgb_std, hsv_mean, lab_mean, gray_hist, [entropy]])

def load_images(dir_path):
    images = []
    labels = []
    prefixes = ['dry', 'humid', 'wet']
    numbers = range(1, 5)  # 0-4

    for prefix in prefixes:
        for num in numbers:
            img_path = os.path.join(dir_path, f"{prefix}{num}.jpg")
            if os.path.exists(img_path):
                img = cv2.imread(img_path)
                if img is not None:
                    images.append(img)
                    labels.append(prefix)
    return images, labels

# Load the images from your dataset directory
images, labels = load_images("data")

if len(images) == 0:
    raise ValueError("No images were loaded. Check the image directory path and file names.")

# Feature extraction: extract features for all images
features = [extract_features(img) for img in images]
features = np.array(features)

# Standardize the feature matrix
scaler = StandardScaler()
features_scaled = scaler.fit_transform(features)

# 1. Statistical Comparison (ANOVA)
df = pd.DataFrame(features_scaled)
df['label'] = labels

# Split data by label
dry_features = df[df['label'] == 'dry'].iloc[:, :-1]  # exclude label column
wet_features = df[df['label'] == 'wet'].iloc[:, :-1]
humid_features = df[df['label'] == 'humid'].iloc[:, :-1]

# Perform ANOVA for each feature
num_features = dry_features.shape[1]
p_values = []
f_values = []

for i in range(num_features):
    f_stat, p_val = f_oneway(dry_features.iloc[:, i], 
                            wet_features.iloc[:, i], 
                            humid_features.iloc[:, i])
    f_values.append(f_stat)
    p_values.append(p_val)

# Print results for each feature
significant_features = []
for i, (f_stat, p_val) in enumerate(zip(f_values, p_values)):
    print(f'Feature {i}: F-statistic = {f_stat:.4f}, p-value = {p_val:.4f}')
    if p_val < 0.05:
        significant_features.append(i)
print(f'Significant features: {significant_features}')

# After performing ANOVA, create visualizations
def visualize_anova_results(f_values, p_values, significance_level=0.1):
    """
    Create visualizations for ANOVA results
    """
    f_values = np.array(f_values)
    p_values = np.array(p_values)
    
    # Create feature names for better labeling
    feature_names = [
        'R_mean', 'G_mean', 'B_mean',  # RGB means
        'R_std', 'G_std', 'B_std',     # RGB std devs
        'H_mean', 'S_mean', 'V_mean',  # HSV means
        'L_mean', 'a_mean', 'b_mean',  # LAB means
    ] + [f'hist_{i}' for i in range(32)] + ['entropy']  # Histogram bins + entropy

    # Create a DataFrame with the results
    results_df = pd.DataFrame({
        'Feature': feature_names,
        'F_statistic': f_values,
        'p_value': p_values,
        'Significant': p_values < significance_level
    })

    # 1. Create a heatmap of -log10(p-values)
    plt.figure(figsize=(15, 6))
    
    # Plot 1: Heatmap
    plt.subplot(1, 2, 1)
    sig_scores = -np.log10(results_df['p_value'].values)
    sig_scores = sig_scores.reshape(-1, 1)  # Reshape for heatmap
    
    sns.heatmap(sig_scores, 
                yticklabels=feature_names,
                xticklabels=['Significance'],
                cmap='RdYlBu_r',
                center=0)
    plt.title('Feature Significance\n(-log10 p-value)')

    # Plot 2: Top significant features bar plot
    plt.subplot(1, 2, 2)
    significant_df = results_df[results_df['Significant']].sort_values('F_statistic', ascending=True)
    
    if len(significant_df) > 0:
        plt.barh(range(len(significant_df)), significant_df['F_statistic'])
        plt.yticks(range(len(significant_df)), significant_df['Feature'])
        plt.xlabel('F-statistic')
        plt.title(f'Significant Features (p < {significance_level})')
    else:
        plt.text(0.5, 0.5, 'No significant features found', 
                horizontalalignment='center',
                verticalalignment='center')

    plt.tight_layout()
    plt.show()

# Call the visualization function
visualize_anova_results(f_values, p_values)

# 2. PCA or t-SNE for dimensionality reduction and visualization
# PCA for dimensionality reduction to 2D
# pca = PCA(n_components=2)
# features_pca = pca.fit_transform(features_scaled)

# # Visualize PCA result
# plt.figure(figsize=(8, 6))
# sns.scatterplot(x=features_pca[:, 0], y=features_pca[:, 1], hue=labels, palette='Set1')
# plt.title('PCA of Soil Images')
# plt.xlabel('Principal Component 1')
# plt.ylabel('Principal Component 2')
# plt.show()

# # 3. Clustering (K-Means)
# kmeans = KMeans(n_clusters=3)
# labels_kmeans = kmeans.fit_predict(features_scaled)

# # Visualize KMeans result
# plt.figure(figsize=(8, 6))
# sns.scatterplot(x=features_pca[:, 0], y=features_pca[:, 1], hue=labels_kmeans, palette='Set1')
# plt.title('K-Means Clustering of Soil Images')
# plt.xlabel('Principal Component 1')
# plt.ylabel('Principal Component 2')
# plt.show()

# # 3. Clustering (DBSCAN)
# dbscan = DBSCAN(eps=0.5, min_samples=5)
# labels_dbscan = dbscan.fit_predict(features_scaled)

# # Visualize DBSCAN result
# plt.figure(figsize=(8, 6))
# sns.scatterplot(x=features_pca[:, 0], y=features_pca[:, 1], hue=labels_dbscan, palette='Set1')
# plt.title('DBSCAN Clustering of Soil Images')
# plt.xlabel('Principal Component 1')
# plt.ylabel('Principal Component 2')
# plt.show()
