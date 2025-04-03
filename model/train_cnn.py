import os
import numpy as np
import pandas as pd
from PIL import Image
import matplotlib.pyplot as plt
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.transforms as transforms
from torch.utils.data import Dataset, DataLoader
from sklearn.model_selection import train_test_split
from sklearn.metrics import root_mean_squared_error, mean_absolute_error, r2_score

# Load and preprocess the dataset
def load_and_preprocess_data(csv_path, image_dir):
    """
    Load and preprocess the dataset from a CSV file and filter images based on their existence in the directory.
    Args:
        csv_path (str): Path to the CSV file containing image paths and labels.
        image_dir (str): Directory containing the images.
    Returns:
        pd.DataFrame: Preprocessed DataFrame with image paths and labels.
    """
    df = pd.read_csv(csv_path)
    df = df[df['Image_Path'].apply(lambda x: os.path.exists(f"{image_dir}/{x.split('/')[-1]}"))]
    df = df.reset_index(drop=True)
    return df

# Define the custom dataset
class SoilMoistureDataset(Dataset):
    """
    Custom dataset for loading soil moisture images and their corresponding labels.
    """
    def __init__(self, dataframe, image_dirs, transform=None):
        self.dataframe = dataframe
        self.image_dirs = image_dirs if isinstance(image_dirs, list) else [image_dirs]
        self.transform = transform

    def __len__(self):
        return len(self.dataframe)

    def __getitem__(self, idx):
        img_path = self.dataframe['Image_Path'].iloc[idx]
        for image_dir in self.image_dirs:
            full_path = f"{image_dir}/{img_path.split('/')[-1]}"
            if os.path.exists(full_path):
                img_path = full_path
                break
        else:
            raise FileNotFoundError(f"Image {img_path} not found in provided directories.")

        label = torch.tensor(self.dataframe.iloc[idx]['Moisture'], dtype=torch.float32)
        image = Image.open(img_path).convert("RGB")
        if self.transform:
            image = self.transform(image)
        return image, label

# Define transformations
def get_transforms():
    return transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])

# Define the CNN model
class CNNModel(nn.Module):
    """
    Convolutional Neural Network model for soil moisture prediction.
    You can train from scratch or load from a checkpoint to continue training.
    Follows architecture from https://doi.org/10.3390/agriculture13030574
    """
    def __init__(self, from_checkponit=None):
        super(CNNModel, self).__init__()
        self.conv1 = nn.Conv2d(3, 32, kernel_size=3, stride=1, padding=1)
        self.relu1 = nn.ReLU()
        self.bn1 = nn.BatchNorm2d(32)
        self.pooling1 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv2 = nn.Conv2d(32, 64, kernel_size=3, stride=1, padding=1)
        self.relu2 = nn.ReLU()
        self.bn2 = nn.BatchNorm2d(64)
        self.pooling2 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.conv3 = nn.Conv2d(64, 128, kernel_size=3, stride=1, padding=1)
        self.pooling3 = nn.MaxPool2d(kernel_size=2, stride=2)
        self.global_average_pooling = nn.AdaptiveAvgPool2d((1, 1))
        self.fc = nn.Linear(128, 1)

        if from_checkponit:
            self.load_state_dict(torch.load(from_checkponit, weights_only=True))

    def forward(self, x):
        x = self.relu1(self.conv1(x))
        x = self.bn1(x)
        x = self.pooling1(x)
        x = self.relu2(self.conv2(x))
        x = self.bn2(x)
        x = self.pooling2(x)
        x = self.conv3(x)
        x = self.pooling3(x)
        x = self.global_average_pooling(x)
        x = x.view(x.size(0), -1)
        x = self.fc(x)
        return x

# Train the model
def train_model(model, train_loader, val_loader, criterion, optimizer, device, num_epochs=10):
    for epoch in range(num_epochs):
        model.train()
        running_loss = 0.0
        for images, labels in train_loader:
            images, labels = images.to(device), labels.to(device).view(-1, 1)
            outputs = model(images)
            loss = criterion(outputs, labels)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * images.size(0)
        epoch_loss = running_loss / len(train_loader.dataset)
        print(f"Epoch {epoch+1}/{num_epochs}, Train Loss: {epoch_loss:.4f}")

        model.eval()
        val_loss = 0.0
        with torch.no_grad():
            for images, labels in val_loader:
                images, labels = images.to(device), labels.to(device).view(-1, 1)
                outputs = model(images)
                loss = criterion(outputs, labels)
                val_loss += loss.item() * images.size(0)
        val_epoch_loss = val_loss / len(val_loader.dataset)
        print(f"Epoch {epoch+1}/{num_epochs}, Val Loss: {val_epoch_loss:.4f}")
    return model

# Evaluate the model with statistical metrics
def evaluate_model(model, val_loader, device):
    model.eval()
    predictions, true_labels = [], []
    with torch.no_grad():
        for images, labels in val_loader:
            images, labels = images.to(device), labels.to(device).view(-1, 1)
            outputs = model(images)
            predictions.extend(outputs.cpu().numpy().flatten())
            true_labels.extend(labels.cpu().numpy().flatten())

    # Compute statistical metrics
    r2 = r2_score(true_labels, predictions)
    rmse = root_mean_squared_error(true_labels, predictions)
    mae = mean_absolute_error(true_labels, predictions)
    print("Evaluation Metrics:")
    print(f"R²: {r2:.4f}, RMSE: {rmse:.4f}, MAE: {mae:.4f}")
    return predictions, true_labels

# Visualize predictions vs true labels
def visualize_predictions(predictions, true_labels):
    predictions = np.array(predictions)
    true_labels = np.array(true_labels)
    plt.figure(figsize=(10, 5))
    plt.scatter(true_labels, predictions, alpha=0.5)
    plt.plot([true_labels.min(), true_labels.max()], [true_labels.min(), true_labels.max()], 'r--')
    plt.xlabel("True Labels")
    plt.ylabel("Predictions")
    plt.title("Predictions vs True Labels")
    plt.show()

# Main function
def main():
    csv_path1 = "../Soil-Moisture-Imaging-Data/Data-i11-ds/dataset_i11_ds.csv"
    image_dir1 = "../Soil-Moisture-Imaging-Data/Data-i11-ds/images"
    csv_path2 = "../Soil-Moisture-Imaging-Data/Data-i11-is/dataset_i11_is.csv"
    image_dir2 = "../Soil-Moisture-Imaging-Data/Data-i11-is/images"

    df1 = load_and_preprocess_data(csv_path1, image_dir1)
    df2 = load_and_preprocess_data(csv_path2, image_dir2)
    df = pd.concat([df1, df2], ignore_index=True)

    transform = get_transforms()
    train_df, val_df = train_test_split(df, test_size=0.2, random_state=42)
    train_dataset = SoilMoistureDataset(train_df, [image_dir1, image_dir2], transform=transform)
    val_dataset = SoilMoistureDataset(val_df, [image_dir1, image_dir2], transform=transform)
    train_loader = DataLoader(train_dataset, batch_size=16, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=16, shuffle=False)

    model = CNNModel(from_checkponit="soil_moisture_model.pth")
    device = torch.device("mps" if torch.backends.mps.is_available() else "cuda" if torch.cuda.is_available() else "cpu")
    model = model.to(device)
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=0.001)

    trained_model = train_model(model, train_loader, val_loader, criterion, optimizer, device, num_epochs=10)
    torch.save(trained_model.state_dict(), "soil_moisture_model.pth")

    predictions, true_labels = evaluate_model(trained_model, val_loader, device)
    visualize_predictions(predictions, true_labels)

if __name__ == "__main__":
    main()