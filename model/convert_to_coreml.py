import joblib
import coremltools as ct
import numpy as np
from classification_utils import load_data, prepare_features

JOB_LIB_MODEL_PATH = "models/soil_svm_classifier.joblib"
OUTPUT_MLMODEL_PATH = "models/SoilClassifierSVC.mlmodel"
CSV_DATA_PATH = "../new_samples/samples.csv"
IMAGE_DIR_PATH = "../new_samples/"

# Load model
model_data = joblib.load(JOB_LIB_MODEL_PATH)
pipeline_model = model_data['model']
class_names = model_data['class_names']

# Get sample data for input shape
df, _ = load_data(CSV_DATA_PATH, IMAGE_DIR_PATH)
X_sample, _ = prepare_features(df.iloc[0:1], IMAGE_DIR_PATH, normalize=True, augment=False)
num_features = X_sample.shape[1]
print(f"Number of features: {num_features}")

# Define Core ML input
input_features = [("image_features", ct.models.datatypes.Array(num_features))]
output_features = [("classLabel", ct.models.datatypes.String())]

# Convert model
mlmodel = ct.converters.sklearn.convert(
    pipeline_model,
    input_features,
    output_features
)

# Add metadata
mlmodel.author = "Jet Chiang"
mlmodel.license = "MIT"
mlmodel.short_description = "Soil moisture classifier predicting Dry, Moist, or Wet."

# Save model
mlmodel.save(OUTPUT_MLMODEL_PATH)

# Verify conversion
coreml_model = ct.models.MLModel(OUTPUT_MLMODEL_PATH)

# Create input dictionary with individual features
sample_input = {
    "image_features": X_sample[0].tolist()
}

original_pred = pipeline_model.predict(X_sample)[0]
coreml_pred = coreml_model.predict(sample_input)

print(f"Original prediction: {original_pred}")
print(f"CoreML prediction: {coreml_pred["classLabel"]}")
