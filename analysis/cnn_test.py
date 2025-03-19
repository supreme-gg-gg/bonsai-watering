# public dataset: https://github.com/akabircs/Soil-Moisture-Imaging-Datao
import cv2
import numpy as np
from skimage import feature
from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
from scipy import stats
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.feature_selection import mutual_info_classif

# 1. Feature Extraction
def extract_color_features(image):
    # Convert the image to different color spaces
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image_hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
    image_lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
    
    # RGB mean & standard deviation
    r_mean, g_mean, b_mean = np.mean(image_rgb, axis=(0, 1))
    r_std, g_std, b_std = np.std(image_rgb, axis=(0, 1))
    
    # HSV mean
    h_mean, s_mean, v_mean = np.mean(image_hsv, axis=(0, 1))
    
    # LAB mean
    l_mean, a_mean, b_mean = np.mean(image_lab, axis=(0, 1))
    
    # Grayscale histogram
    grayscale = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    hist = cv2.calcHist([grayscale], [0], None, [256], [0, 256])
    
    # Texture features (e.g., entropy, contrast)
    texture = feature.graycomatrix(grayscale, distances=[1], angles=[0], symmetric=True, normed=True)
    entropy = -np.sum(texture * np.log2(texture + 1e-6))  # avoid log(0)
    
    return [r_mean, g_mean, b_mean, r_std, g_std, b_std, h_mean, s_mean, v_mean,
            l_mean, a_mean, b_mean, entropy]

# 2. Perform Statistical Comparisons
def t_test(features_1, features_2):
    t_stat, p_value = stats.ttest_ind(features_1, features_2)
    return t_stat, p_value

def ks_test(features_1, features_2):
    ks_stat, p_value = stats.ks_2samp(features_1, features_2)
    return ks_stat, p_value

# 3. Principal Component Analysis (PCA)
def perform_pca(features_bonsai, features_dataset):
    pca = PCA(n_components=2)
    pca_features = np.concatenate([features_bonsai, features_dataset], axis=0)
    
    pca_result = pca.fit_transform(pca_features)
    
    # Plotting PCA
    plt.figure(figsize=(8,6))
    sns.scatterplot(x=pca_result[:, 0], y=pca_result[:, 1], hue=["bonsai"] * len(features_bonsai) + ["dataset"] * len(features_dataset))
    plt.title("PCA Analysis")
    plt.show()

# 4. Clustering (K-Means or DBSCAN)
def perform_clustering(features_bonsai, features_dataset):
    kmeans = KMeans(n_clusters=2)
    all_features = np.concatenate([features_bonsai, features_dataset], axis=0)
    kmeans.fit(all_features)
    
    # Plot clusters
    plt.scatter(all_features[:, 0], all_features[:, 1], c=kmeans.labels_)
    plt.title("K-Means Clustering")
    plt.show()

# 5. Feature Importance (Mutual Information)
def feature_importance(features_bonsai, features_dataset):
    all_features = np.concatenate([features_bonsai, features_dataset], axis=0)
    labels = [1] * len(features_bonsai) + [0] * len(features_dataset)
    
    mi_scores = mutual_info_classif(all_features, labels)
    return mi_scores

# Main analysis
def main():
    # Assuming images are loaded from the bonsai soil dataset and external dataset
    bonsai_image = cv2.imread('bonsai_soil_image.jpg')  # Replace with actual image path
    dataset_image = cv2.imread('dataset_soil_image.jpg')  # Replace with actual image path
    
    # Extract features
    bonsai_features = extract_color_features(bonsai_image)
    dataset_features = extract_color_features(dataset_image)
    
    # Step 1: Statistical Test (t-test, K-S test)
    t_stat, p_value_ttest = t_test(bonsai_features, dataset_features)
    ks_stat, p_value_ks = ks_test(bonsai_features, dataset_features)

    print(f"t-test: t-stat = {t_stat}, p-value = {p_value_ttest}")
    if p_value_ttest < 0.05:
        print("The features differ significantly (t-test)")
    else:
        print("No significant difference (t-test)")
    
    print(f"K-S test: KS-stat = {ks_stat}, p-value = {p_value_ks}")
    if p_value_ks < 0.05:
        print("The distributions differ significantly (K-S test)")
    else:
        print("The distributions are similar (K-S test)")
    
    # Step 2: PCA (Principal Component Analysis)
    perform_pca([bonsai_features], [dataset_features])

    # Step 3: Clustering (K-Means)
    perform_clustering([bonsai_features], [dataset_features])

    # Step 4: Feature Importance (Mutual Information)
    mi_scores = feature_importance([bonsai_features], [dataset_features])
    print("Mutual Information Scores:", mi_scores)

if __name__ == "__main__":
    main()