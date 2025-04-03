# bonsai-watering

Praxis II -- Bonsai soil moisture monitoring and watering system

## Development Notes

- `firmware` contains code for Raspberry Pi. Require: `RPi.GPIO, PiCamera2, bleak`

- `analysis` contains preliminary data analysis (e.g. feature selection) and preprocessing code. Require: `pandas, numpy, scipy, matplotlib, seaborn, scikit-learn, opencv-python`

- `mobile-ios/Bonsense` is the official iOS Swift/SwiftUI application. Dependencies: `CoreBluetooth, AVFoundation`

- `model` contains the machine learning model training code. Require: `pandas, numpy, matplotlib, scikit-learn, scikit-image, torch, torchvision`

## TODO

- [ ] Switch roles of central and peripheral for more robust BLE connection

- [ ] Setup picamera, perform testing of the photo approach and spectorsocpy approach

- [ ] Smartphone photo model training + deployment with CoreML and to Raspberry Pi with the PiCam

- [ ] Continued investigation of gray level vs direct CNN vs smartphone spectroscopy methods

## References

1. [Machine Learning Techniques for Estimating Soil Moisture from Smartphone Captured Images](https://doi.org/10.3390/agriculture13030574)

2. [Estimating soil water content from surface digital image gray level measurements under visible spectrum](https://cdnsciencepub.com/doi/10.4141/cjss10054)

3. [Near-infrared spectroscopy for soil water determination in small soil volumes](https://cdnsciencepub.com/doi/10.4141/S03-090)
