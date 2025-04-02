# bonsai-watering

Praxis II -- Bonsai soil moisture monitoring and watering system

## Development Notes

`firmware` contains code for Raspberry Pi. Require: `RPi.GPIO, PiCamera2, bleak`

`analysis` contains preliminary data analysis (e.g. feature selection) and preprocessing code. Require: `pandas, numpy, scipy, matplotlib, seaborn, scikit-learn, opencv-python`

`mobile-ios/Bonsense` is the official iOS Swift/SwiftUI application. Dependencies: `CoreBluetooth, AVFoundation`

## TODO

- [ ] Train model on https://github.com/akabircs/Soil-Moisture-Imaging-Data

- [ ] Fix BLE connection and characteristic read/write with Raspberry Pi Bleak client

- [ ] Switch roles of central and peripheral for more robust BLE connection

- [ ] Setup picamera, perform testing of the photo approach and spectorsocpy approach

- [ ] Finalize data interface, implement SwiftData persistant storage and AnalyticsView

- [ ] Use ML and stat methods to calibrate the moisture sensor (once we have ADC)

- [ ] Smartphone photo model training + deployment with CoreML and to Raspberry Pi with the PiCam

- [ ] Continued investigation of gray level vs direct CNN vs smartphone spectroscopy methods

## Optional

1. Test NIR spectroscopy (need NIR source and diffraction spectroscope)

2. Enhance the overall UI/UX of the app, enhance dark mode color scheme and style

3. Fix the camera view so that the camera is displayed in the box, not a popup where you take a photo

4. Implement AR feature to direclty recognize and display a moisture level / alert tag on top of the bonsai for maximum convenience (UX!!)

5. Build Android client -- either in Java or Kotlin or Flutter or React Native
