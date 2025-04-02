import os
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.transforms as transforms
import torchvision.models as models
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split

# Load and preprocess the dataset
def load_and_preprocess_data(csv_path, image_dir):
    df = pd.read_csv(csv_path)
    df = df[df['Image_Path'].apply(lambda x: os.path.exists(f"{image_dir}/{x.split('/')[-1]}"))]
    df = df.reset_index(drop=True)
    df['Moisture_Class'] = pd.qcut(df['Moisture'], q=3, labels=['Low', 'Medium', 'High'])
    return df

# Visualize sample images
def visualize_samples(df, image_dir, num_samples=3):
    fig, ax = plt.subplots(1, num_samples, figsize=(15, 5))
    for i in range(num_samples):
        path = f"{image_dir}/{df['Image_Path'].iloc[i].split('/')[-1]}"
        image = Image.open(path)
        label = df['Moisture'].iloc[i]
        ax[i].imshow(image)
        ax[i].set_title(f"Label: {label}")
    plt.show()

# Define the custom dataset
class SoilMoistureDataset(Dataset):
    def __init__(self, dataframe, image_dir, transform=None):
        self.dataframe = dataframe
        self.image_dir = image_dir
        self.transform = transform

    def __len__(self):
        return len(self.dataframe)

    def __getitem__(self, idx):
        img_path = f"{self.image_dir}/{self.dataframe['Image_Path'].iloc[idx].split('/')[-1]}"
        label = self.dataframe.iloc[idx]['Moisture_Class']
        image = Image.open(img_path).convert("RGB")
        if self.transform:
            image = self.transform(image)
        label = torch.tensor(['Low', 'Medium', 'High'].index(label), dtype=torch.long)
        return image, label

# Define transformations
def get_transforms():
    return transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])

# Visualize preprocessed images
def visualize_preprocessed_images(loader, num_images=5):
    sample_images, sample_labels = next(iter(loader))
    fig, axes = plt.subplots(1, num_images, figsize=(15, 5))
    for i in range(num_images):
        img = sample_images[i].permute(1, 2, 0).numpy()
        img = img * [0.229, 0.224, 0.225] + [0.485, 0.456, 0.406]
        img = np.clip(img, 0, 1)
        axes[i].imshow(img)
        axes[i].set_title(f"Label: {['Low', 'Medium', 'High'][sample_labels[i].item()]}")
        axes[i].axis("off")
    plt.show()

# Define the model
def get_model():
    model = models.resnet18(pretrained=True)
    num_features = model.fc.in_features
    model.fc = nn.Linear(num_features, 3)
    return model

# Train the model
def train_model(model, train_loader, val_loader, criterion, optimizer, device, num_epochs=10):
    for epoch in range(num_epochs):
        model.train()
        running_loss, correct_predictions, total_samples = 0.0, 0, 0
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)
            _, preds = torch.max(outputs, 1)
            correct_predictions += (preds == labels).sum().item()
            total_samples += labels.size(0)
        epoch_loss = running_loss / total_samples
        epoch_acc = correct_predictions / total_samples
        print(f"Epoch {epoch+1}/{num_epochs}, Train Loss: {epoch_loss:.4f}, Train Accuracy: {epoch_acc:.4f}")

        model.eval()
        val_loss, val_correct_predictions, val_total_samples = 0.0, 0, 0
        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(device), labels.to(device)
                outputs = model(images)
                loss = criterion(outputs, labels)
                val_loss += loss.item() * images.size(0)
                _, preds = torch.max(outputs, 1)
                val_correct_predictions += (preds == labels).sum().item()
                val_total_samples += labels.size(0)
        val_epoch_loss = val_loss / val_total_samples
        val_epoch_acc = val_correct_predictions / val_total_samples
        print(f"Epoch {epoch+1}/{num_epochs}, Val Loss: {val_epoch_loss:.4f}, Val Accuracy: {val_epoch_acc:.4f}")
    return model

# Evaluate the model
def evaluate_model(model, val_loader, device):
    model.eval()
    predictions, true_labels, images_list = [], [], []
    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            _, preds = torch.max(outputs, 1)
            predictions.extend(preds.cpu().numpy())
            true_labels.extend(labels.cpu().numpy())
            images_list.extend(images.cpu())
    return images_list, predictions, true_labels

# Visualize predictions
def visualize_predictions(images_list, predictions, true_labels, num_samples=10):
    random_indices = np.random.choice(len(images_list), num_samples, replace=False)
    fig, axes = plt.subplots(2, 5, figsize=(20, 8))
    axes = axes.flatten()
    for i, idx in enumerate(random_indices):
        img = images_list[idx].permute(1, 2, 0).numpy()
        img = img * [0.229, 0.224, 0.225] + [0.485, 0.456, 0.406]
        img = np.clip(img, 0, 1)
        axes[i].imshow(img)
        axes[i].set_title(f"Pred: {['Low', 'Medium', 'High'][predictions[idx]]}\nTrue: {['Low', 'Medium', 'High'][true_labels[idx]]}")
        axes[i].axis("off")
    plt.tight_layout()
    plt.show()

# Main function
def main():
    csv_path = "../Soil-Moisture-Imaging-Data/Data-i11-ds/dataset_i11_ds.csv"
    image_dir = "../Soil-Moisture-Imaging-Data/Data-i11-ds/images"
    df = load_and_preprocess_data(csv_path, image_dir)
    visualize_samples(df, image_dir)

    transform = get_transforms()
    train_df, val_df = train_test_split(df, test_size=0.2, stratify=df['Moisture_Class'], random_state=42)
    train_dataset = SoilMoistureDataset(train_df, image_dir, transform=transform)
    val_dataset = SoilMoistureDataset(val_df, image_dir, transform=transform)
    train_loader = DataLoader(train_dataset, batch_size=16, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=16, shuffle=False)

    visualize_preprocessed_images(train_loader)

    model = get_model()
    device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    trained_model = train_model(model, train_loader, val_loader, criterion, optimizer, device, num_epochs=10)
    torch.save(trained_model.state_dict(), "soil_moisture_model.pth")

    images_list, predictions, true_labels = evaluate_model(trained_model, val_loader, device)
    visualize_predictions(images_list, predictions, true_labels)

if __name__ == "__main__":
    main()