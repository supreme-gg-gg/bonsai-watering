# bonsai-watering

Praxis II -- Bonsai soil moisture monitoring and watering system

To be written and polished...

## Development Notes

- `firmware` contains code for Raspberry Pi. Require: `RPi.GPIO, PiCamera2, bleak, bless`

- `analysis` contains preliminary data analysis (e.g. feature selection) and preprocessing code. Require: `pandas, numpy, scipy, matplotlib, seaborn, scikit-learn, opencv-python`

- `mobile-ios/Bonsense` is the official iOS Swift/SwiftUI application. Dependencies: `CoreBluetooth, AVFoundation`

- `model` contains the machine learning model training code. Require: `pandas, numpy, matplotlib, scikit-learn, scikit-image, torch, torchvision`

## Analysis

PCA, TSNE, LDA.

## Model Results

We first did the research paper's testing with regression task, both failed (SVM regressor and CNN). Then we tried regression on our dataset, didn't go well. Then we finalized the following models for classification task:

0. KNN standalone: 64% accuracy, 0.65 F1 on average (with augmentation)

1. SVC standalone: 56% accuracy, 0.55 F1 on average (w/o augmentation)

2. LDA-SVC: 66% accuracy, 0.7 F1 on average (w/o augmentation)

3. LightGBM: 34% accuracy, 0.3 F1 on average (w/o augmentation)

We finally selected teh LDA-SVC model for deployment. I believe with more augmentation and larger dataset we can achieve better results.

## References

1. [Machine Learning Techniques for Estimating Soil Moisture from Smartphone Captured Images](https://doi.org/10.3390/agriculture13030574)

2. [Estimating soil water content from surface digital image gray level measurements under visible spectrum](https://cdnsciencepub.com/doi/10.4141/cjss10054)

3. [Near-infrared spectroscopy for soil water determination in small soil volumes](https://cdnsciencepub.com/doi/10.4141/S03-090)
