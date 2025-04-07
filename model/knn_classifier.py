import numpy as np
from sklearn.neighbors import KNeighborsClassifier
from sklearn.model_selection import LeaveOneOut
from sklearn.preprocessing import MinMaxScaler
from classification_utils import prepare_features, load_data, perform_evaluation, save_model

def perform_loocv(X, y, n_neighbors=3, weights='distance'):
    loo = LeaveOneOut()
    predictions = []
    true_values = []
    
    for train_idx, test_idx in loo.split(X):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        
        scaler = MinMaxScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        model = KNeighborsClassifier(n_neighbors=n_neighbors, weights=weights)
        model.fit(X_train_scaled, y_train)
        pred = model.predict(X_test_scaled)
        
        predictions.append(pred[0])
        true_values.append(y_test[0])

    # Save the model
    save_model(model, scaler,
               feature_names=None, model_file="soil_knn_classifier.joblib", 
               model_type='KNN', class_names=['Dry', 'Moist', 'Wet'])
    
    return np.array(predictions), np.array(true_values)

def main():
    df, image_dir = load_data("../new_samples/samples.csv", "../new_samples/")
    X, y = prepare_features(df, image_dir, normalize=True, augment=True)
    
    # Perform LOOCV
    predictions, true_values = perform_loocv(X, y, n_neighbors=3, weights='distance')
    
    perform_evaluation(true_values, predictions)

if __name__ == "__main__":
    main()
