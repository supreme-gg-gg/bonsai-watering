import numpy as np
from sklearn.svm import SVC
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import LeaveOneOut
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.pipeline import Pipeline
from classification_utils import load_data, prepare_features, perform_evaluation, save_model

WITH_LDA = True
AUGMENT = True

def train_model(X, y, n_components=2, kernel='rbf', C=10, gamma='scale', with_lda=True):
    """
    Train an LDA-enhanced SVM model on the full dataset and return it.
    Parameters:
    - X: Feature matrix
    - y: Labels
    - n_components: Number of components for LDA
    - kernel: SVM kernel type
    - C: Regularization parameter for SVM
    - gamma: Kernel coefficient for SVM
    - with_lda: Whether to use LDA or not
    """
    # Create LDA and SVM pipelines
    if with_lda:
        lda = LinearDiscriminantAnalysis(n_components=n_components)
    svm = SVC(kernel=kernel, C=C, gamma=gamma, probability=True)
    
    # Create a pipeline
    if with_lda:
        model = Pipeline([('scaler', StandardScaler()), ('lda', lda), ('svm', svm)])
    else:
        model = Pipeline([('scaler', StandardScaler()), ('svm', svm)])

    print(f"Training LDA-SVM with LDA(n_components={n_components}), SVM(kernel={kernel}, C={C})...")
    model.fit(X, y)
    
    return model

def perform_loocv(X, y, n_components=2, kernel='rbf', C=10, gamma='scale', with_lda=True):
    """
    Evaluate LDA-enhanced SVM model using leave-one-out cross-validation.
    Parameters:
    - X: Feature matrix
    - y: Labels
    - n_components: Number of components for LDA
    - kernel: SVM kernel type
    - C: Regularization parameter for SVM
    - gamma: Kernel coefficient for SVM
    - with_lda: Whether to use LDA or not
    
    NOTE: We use Leave-One-Out Cross-Validation (LOOCV) for evaluation because
    it is suitable for small datasets and provides a more accurate estimate of model performance.
    The model is trained on all but one sample and tested on that sample.
    This process is repeated for each sample in the dataset.
    The final predictions, true values, and probabilities are returned.
    """
    loo = LeaveOneOut()
    predictions = []
    true_values = []
    probabilities = []
    
    print(f"Performing LOOCV with LDA-SVM (LDA(n_components={n_components}), SVM(kernel={kernel}, C={C}))...")
    for i, (train_idx, test_idx) in enumerate(loo.split(X)):
        X_train, X_test = X[train_idx], X[test_idx]
        y_train, y_test = y[train_idx], y[test_idx]
        
        # Create LDA and SVM pipelines
        if with_lda:
            lda = LinearDiscriminantAnalysis(n_components=n_components)
        svm = SVC(kernel=kernel, C=C, gamma=gamma, probability=True)
        
        # Create a pipeline
        if with_lda:
            model = Pipeline([('scaler', StandardScaler()), ('lda', lda), ('svm', svm)])
        else:
            model = Pipeline([('scaler', StandardScaler()), ('svm', svm)])

        model.fit(X_train, y_train)
        
        pred = model.predict(X_test)
        prob = model.predict_proba(X_test)
        
        predictions.append(pred[0])
        true_values.append(y_test[0])
        probabilities.append(prob[0])
        
        if (i+1) % 5 == 0:
            print(f"Processed {i+1}/{len(X)} cross-validation folds")
    
    return np.array(predictions), np.array(true_values), np.array(probabilities)

def main():

    df, image_dir = load_data("../new_samples/samples.csv", "../new_samples/")
    print(f"Loaded {len(df)} samples from dataset")
    
    # Extract features (without augmentation for clearer evaluation)
    X, y = prepare_features(df, image_dir, normalize=True, augment=AUGMENT)
    print(f"Extracted {X.shape[1]} features from each sample")
    
    # Perform cross-validation to evaluate model
    predictions, true_values, probabilities = perform_loocv(X, y, n_components=2, kernel='rbf', C=10, with_lda=WITH_LDA)
    
    perform_evaluation(true_values, predictions)
    
    # Train final model on all data
    model = train_model(X, y, n_components=2, kernel='rbf', C=10, with_lda=WITH_LDA)

    filename = "models/soil_lda_svm_classifier.joblib" if WITH_LDA else "models/soil_svm_classifier.joblib"
    
    # Save the model
    save_model(model, scaler=None, feature_names=None, model_file=filename,
               model_type='SVM', class_names=['Dry', 'Moist', 'Wet'])
    
    print("\nExample of model usage:")
    print("model = joblib.load('soil_lda_svm_classifier.joblib')")
    print("result = predict_soil_moisture('new_image.jpg')")
    print("print(f\"Predicted soil moisture: {result['class_name']}\")")

if __name__ == "__main__":
    main()
