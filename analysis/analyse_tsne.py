import numpy as np
import matplotlib.pyplot as plt
from sklearn.manifold import TSNE
from sklearn.preprocessing import MinMaxScaler
import pandas as pd
from model.classification_utils import prepare_features, load_data

def visualize_with_tsne(X, y, class_names=['Dry', 'Moist', 'Wet']):
    """
    Visualize soil moisture data using t-SNE to demonstrate class separability.
    This supports the methodology of using smartphone camera images for soil moisture estimation.
    """
    # Scale features before applying t-SNE
    X_scaled = MinMaxScaler().fit_transform(X)
    
    print("Applying t-SNE dimensionality reduction...")
    # Apply t-SNE with perplexity tuned for small datasets
    tsne = TSNE(n_components=2, random_state=42, perplexity=min(30, len(X)//5), 
               learning_rate='auto', init='pca')
    X_tsne = tsne.fit_transform(X_scaled)
    
    # Create visualization
    plt.figure(figsize=(10, 8))
    colors = ['#E74C3C', '#2ECC71', '#3498DB']  # Red, Green, Blue
    markers = ['o', 's', '^']  # Circle, Square, Triangle
    unique_classes = sorted(np.unique(y))
    
    for i, class_val in enumerate(unique_classes):
        idx = np.where(y == class_val)
        plt.scatter(X_tsne[idx, 0], X_tsne[idx, 1], 
                   c=colors[i], marker=markers[i], s=80, label=class_names[i], alpha=0.8)
    
    plt.title('t-SNE Visualization of Soil Moisture Classes', fontsize=16)
    plt.xlabel('t-SNE Component 1', fontsize=14)
    plt.ylabel('t-SNE Component 2', fontsize=14)
    plt.legend(fontsize=12)
    plt.grid(alpha=0.3)
    
    # Add annotation explaining the significance
    plt.figtext(0.5, 0.01,
               "Distinct clusters indicate that smartphone images can effectively differentiate soil moisture levels",
               ha="center", fontsize=12, bbox={"facecolor":"orange", "alpha":0.2, "pad":5})
    
    plt.tight_layout()
    plt.savefig('soil_moisture_tsne_visualization.png', dpi=300)
    plt.show()
    
    return X_tsne

def main():
    print("Loading soil moisture image dataset...")
    # df, image_dir = load_data("new_samples/samples.csv", "new_samples/")
    df, image_dir = load_data("../data/data.csv", "../data")
    
    print("Extracting features from images...")
    X, y = prepare_features(df, image_dir, normalize=True, augment=False)
    
    print(f"Dataset: {len(X)} samples with {X.shape[1]} features")
    print(f"Class distribution: {pd.Series(y).value_counts().sort_index().to_dict()}")
    
    # Visualize with t-SNE
    X_tsne = visualize_with_tsne(X, y)
    
    # Calculate approximate cluster separation
    unique_classes = np.unique(y)
    centroids = []
    for class_val in unique_classes:
        idx = np.where(y == class_val)
        centroids.append(np.mean(X_tsne[idx], axis=0))
    
    print("\nApproximate cluster separation metrics:")
    for i in range(len(centroids)):
        for j in range(i+1, len(centroids)):
            dist = np.linalg.norm(centroids[i] - centroids[j])
            print(f"Distance between {unique_classes[i]} and {unique_classes[j]}: {dist:.2f}")

if __name__ == "__main__":
    main()