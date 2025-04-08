import numpy as np
from scipy.optimize import curve_fit
import matplotlib.pyplot as plt

# Data points
sensor_values = {
    20: [650, 648, 646, 652],
    15: [480, 506, 510, 482],
    10: [280, 305, 295, 264],
    5: [80, 91, 88, 77]
}

# Calculate means and variances
x_data = np.array(list(sensor_values.keys()))
y_means = np.array([np.mean(sensor_values[x]) for x in x_data])
y_stds = np.array([np.std(sensor_values[x]) for x in x_data])

# Define a quadratic function
def quadratic(x, a, b, c):
    return a * x**2 + b * x + c

# Define a linear function
def linear(x, m, c):
    return m * x + c

# Fit the data with a quadratic function
quad_params, _ = curve_fit(quadratic, y_means, x_data)

# Fit the data with a linear function
lin_params, _ = curve_fit(linear, y_means, x_data)

# Generate points for the fitted curves
x_fit = np.linspace(min(y_means), max(y_means), 500)
y_quad_fit = quadratic(x_fit, *quad_params)
y_lin_fit = linear(x_fit, *lin_params)

# Plot the data points and the fitted curves
plt.scatter(y_means, x_data, color='red', label='Data Points (Mean)')
plt.errorbar(y_means, x_data, xerr=y_stds, fmt='o', color='red', capsize=5, label='Variance')
plt.plot(x_fit, y_quad_fit, color='blue', label='Fitted Curve (Quadratic)')
plt.plot(x_fit, y_lin_fit, color='green', label='Fitted Curve (Linear)')
plt.xlabel('Sensor Measurement')
plt.ylabel('Ground Truth (%)')
plt.legend()
plt.title('Calibration: Ground Truth vs. Sensor Measurement')
plt.show()

# Print the fitted parameters
print("Fitted parameters for quadratic (a, b, c):", quad_params)
print("Fitted parameters for linear (m, c):", lin_params)