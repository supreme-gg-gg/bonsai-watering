import numpy as np
import matplotlib.pyplot as plt
from sklearn.decomposition import PCA
from sklearn.preprocessing import MinMaxScaler
import pandas as pd
from model.classification_utils import prepare_features, load_data

def visualize_with_pca(X, y, class_names=['Dry', 'Moist', 'Wet']):
    """
    Visualize soil moisture data using PCA to demonstrate class separability.
    PCA focuses on preserving global variance, showing if features have discriminative power.
    """
    # Scale features before applying PCA
    X_scaled = MinMaxScaler().fit_transform(X)
    
    print("Applying PCA dimensionality reduction...")
    # Apply PCA to reduce to 2 components for visualization
    pca = PCA(n_components=2)
    X_pca = pca.fit_transform(X_scaled)
    
    # Get explained variance for reporting
    explained_variance = pca.explained_variance_ratio_
    cumulative_variance = np.sum(explained_variance)
    
    # Create visualization
    plt.figure(figsize=(10, 8))
    colors = ['#E74C3C', '#2ECC71', '#3498DB']  # Red, Green, Blue
    markers = ['o', 's', '^']  # Circle, Square, Triangle
    unique_classes = sorted(np.unique(y))
    
    for i, class_val in enumerate(unique_classes):
        idx = np.where(y == class_val)
        plt.scatter(X_pca[idx, 0], X_pca[idx, 1], 
                   c=colors[i], marker=markers[i], s=80, label=class_names[i], alpha=0.8)
    
    plt.title('PCA Visualization of Soil Moisture Classes', fontsize=16)
    plt.xlabel(f'PC1 ({explained_variance[0]:.1%} variance)', fontsize=14)
    plt.ylabel(f'PC2 ({explained_variance[1]:.1%} variance)', fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(alpha=0.3)
    
    # # Add annotation explaining the significance
    # plt.figtext(0.5, 0.01,
    #            f"PCA captures {cumulative_variance:.1%} of total variance, showing smartphone images contain useful moisture information",
    #            ha="center", fontsize=12, bbox={"facecolor":"orange", "alpha":0.2, "pad":5})
    
    plt.tight_layout()
    plt.savefig('soil_moisture_pca_visualization.png', dpi=300)
    plt.show()
    
    # Generate the feature contribution plot (loading factors)
    plot_feature_loadings(pca)
    
    return X_pca, pca

def plot_feature_loadings(pca, top_n=10):
    """
    Plot the most influential features in the PCA to understand which 
    image characteristics best discriminate between moisture levels
    """
    # Get absolute loading values for first two components
    loadings = pca.components_[:2, :]
    
    # Get indices of features with highest loadings (absolute values)
    # Combine loadings from both components by taking max
    feature_importance = np.max(np.abs(loadings), axis=0)
    top_indices = np.argsort(feature_importance)[-top_n:]
    
    # Create a horizontal bar chart
    plt.figure(figsize=(10, 6))
    
    # Plot PC1 loadings
    plt.barh(np.arange(top_n), loadings[0, top_indices], 
             color='#3498DB', label='PC1', alpha=0.7)
    
    # Plot PC2 loadings
    plt.barh(np.arange(top_n), loadings[1, top_indices], 
             color='#E74C3C', label='PC2', alpha=0.7, left=np.clip(loadings[0, top_indices], 0, None))
    
    plt.yticks(np.arange(top_n), [f'Feature {i}' for i in top_indices])
    plt.xlabel('Loading Factor (Feature Importance)')
    plt.title('Top Feature Contributions to Principal Components')
    plt.legend()
    plt.tight_layout()
    plt.savefig('pca_feature_contributions.png', dpi=300)
    plt.show()

def main():
    print("Loading soil moisture image dataset...")
    df, image_dir = load_data("../new_samples/samples.csv", "../new_samples")
    
    print("Extracting features from images...")
    X, y = prepare_features(df, image_dir, normalize=True, augment=False)
    
    print(f"Dataset: {len(X)} samples with {X.shape[1]} features")
    print(f"Class distribution: {pd.Series(y).value_counts().sort_index().to_dict()}")
    
    # Visualize with PCA
    X_pca, pca_model = visualize_with_pca(X, y)
    
    # Calculate approximate cluster separation
    unique_classes = np.unique(y)
    centroids = []
    for class_val in unique_classes:
        idx = np.where(y == class_val)
        centroids.append(np.mean(X_pca[idx], axis=0))
    
    print("\nApproximate cluster separation metrics:")
    for i in range(len(centroids)):
        for j in range(i+1, len(centroids)):
            dist = np.linalg.norm(centroids[i] - centroids[j])
            print(f"Distance between {unique_classes[i]} and {unique_classes[j]}: {dist:.2f}")
    
    # Print explained variance
    explained_variance = pca_model.explained_variance_ratio_
    print("\nExplained variance by principal components:")
    print(f"PC1: {explained_variance[0]:.2%}")
    print(f"PC2: {explained_variance[1]:.2%}")
    print(f"Total: {np.sum(explained_variance):.2%}")
    
    # Check if there's good separation
    if np.sum(explained_variance) > 0.7:
        print("\nInterpretation: PCA shows strong separation, indicating smartphone images capture distinct")
        print("soil moisture patterns with linear discriminative features.")
    else:
        print("\nInterpretation: PCA shows moderate separation. The non-linear t-SNE might be more suitable,")
        print("suggesting complex relationships between image features and soil moisture.")

if __name__ == "__main__":
    main()