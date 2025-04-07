import numpy as np
import matplotlib.pyplot as plt
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.preprocessing import StandardScaler
import pandas as pd
import seaborn as sns
from model.classification_utils import prepare_features, load_data

def visualize_with_lda(X, y, class_names=['Dry', 'Moist', 'Wet']):
    """
    Visualize soil moisture data using LDA to demonstrate class separability.
    LDA focuses on maximizing class separation, ideal for classification tasks.
    """
    # Scale features before applying LDA
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    print("Applying LDA dimensionality reduction...")
    # Apply LDA to reduce to 2 components (n_components must be <= n_classes - 1)
    lda = LinearDiscriminantAnalysis(n_components=2)
    X_lda = lda.fit_transform(X_scaled, y)
    
    # Get explained variance ratio
    explained_variance = lda.explained_variance_ratio_
    cumulative_variance = np.sum(explained_variance)
    
    # Create visualization with better styling
    plt.figure(figsize=(12, 8))
    
    # Use seaborn for better styling
    sns.scatterplot(x=X_lda[:, 0], y=X_lda[:, 1],
                   hue=y, style=y,
                   markers=['o', 's', '^'],
                   palette='deep',
                   s=100)
    
    plt.title('LDA Visualization of Soil Moisture Classes', 
             fontsize=16, pad=20)
    plt.xlabel(f'LD1 ({explained_variance[0]:.1%} discrimination)', 
             fontsize=14)
    plt.ylabel(f'LD2 ({explained_variance[1]:.1%} discrimination)', 
             fontsize=14)
    
    # Enhance legend
    plt.legend(title='Moisture Level', title_fontsize=12, fontsize=10)
    plt.grid(True, alpha=0.3)
    
    # # Add annotation about class separation
    # plt.figtext(0.5, 0.02,
    #            f"LDA captures {cumulative_variance:.1%} of class discrimination power",
    #            ha="center", fontsize=12,
    #            bbox={"facecolor":"lightgreen", "alpha":0.2, "pad":5})
    
    plt.tight_layout()
    plt.savefig('soil_moisture_lda_visualization.png', dpi=300, bbox_inches='tight')
    plt.show()
    
    # Plot feature importance
    plot_feature_importance(lda, X.shape[1])
    
    return X_lda, lda

def plot_feature_importance(lda, n_features, top_n=10):
    """Plot the most discriminative features identified by LDA"""
    # Get feature coefficients
    coefficients = lda.coef_
    
    # Calculate overall feature importance
    importance = np.sum(coefficients**2, axis=0)
    
    # Get indices of top features
    top_indices = np.argsort(importance)[-top_n:]
    
    # Create visualization
    plt.figure(figsize=(12, 6))
    
    # Plot importance scores
    bars = plt.barh(np.arange(top_n), 
                   importance[top_indices], 
                   color='#2ecc71',
                   alpha=0.8)
    
    plt.yticks(np.arange(top_n), 
               [f'Feature {i}' for i in top_indices])
    plt.xlabel('Discriminative Power', fontsize=12)
    plt.title('Top Discriminative Features for Soil Moisture Classification', 
             fontsize=14, pad=20)
    
    # Add value labels on bars
    for bar in bars:
        width = bar.get_width()
        plt.text(width, bar.get_y() + bar.get_height()/2,
                f'{width:.2f}',
                ha='left', va='center', fontsize=10)
    
    plt.tight_layout()
    plt.savefig('lda_feature_importance.png', dpi=300, bbox_inches='tight')
    plt.show()

def calculate_class_metrics(X_lda, y):
    """Calculate and return class separation metrics"""
    classes = np.unique(y)
    centroids = []
    spreads = []
    
    # Calculate centroids and spreads for each class
    for class_val in classes:
        mask = y == class_val
        class_points = X_lda[mask]
        centroid = np.mean(class_points, axis=0)
        spread = np.mean(np.linalg.norm(class_points - centroid, axis=1))
        centroids.append(centroid)
        spreads.append(spread)
    
    # Calculate inter-class distances
    distances = []
    for i in range(len(centroids)):
        for j in range(i + 1, len(centroids)):
            dist = np.linalg.norm(centroids[i] - centroids[j])
            distances.append((classes[i], classes[j], dist))
    
    return centroids, spreads, distances

def main():
    print("Loading soil moisture image dataset...")
    df, image_dir = load_data("../new_samples/samples.csv", "../new_samples")
    
    print("Extracting features from images...")
    X, y = prepare_features(df, image_dir, normalize=True, augment=False)
    
    print(f"Dataset: {len(X)} samples with {X.shape[1]} features")
    print(f"Class distribution: {pd.Series(y).value_counts().sort_index().to_dict()}")
    
    # Perform LDA analysis
    X_lda, lda_model = visualize_with_lda(X, y)
    
    # Calculate and print separation metrics
    centroids, spreads, distances = calculate_class_metrics(X_lda, y)
    
    print("\nClass Separation Analysis:")
    print("-------------------------")
    for i, (c1, c2, dist) in enumerate(distances):
        print(f"Distance between {c1} and {c2}: {dist:.2f}")
    
    print("\nClass Compactness:")
    for i, (spread, class_val) in enumerate(zip(spreads, np.unique(y))):
        print(f"{class_val}: {spread:.2f} (average distance to centroid)")
    
    # Print explained variance
    explained_variance = lda_model.explained_variance_ratio_
    print("\nDiscriminant ratio by components:")
    print(f"LD1: {explained_variance[0]:.2%}")
    print(f"LD2: {explained_variance[1]:.2%}")
    print(f"Total: {np.sum(explained_variance):.2%}")

if __name__ == "__main__":
    main()