# DyeGradienttoCSV

A tool for analyzing dye gradients in images (with replicates), combining OpenCV image processing with MATLAB analysis and visualization in the form of a waterfall plot (average intensity vs. distance, colored by standard deviation). Version 1.0.0 is intended for analyzing dye profiles that arise at different VFD RPMs.

## Overview

This project consists of two main components:
1. A C++ executable for processing images showing a dye gradient and generating CSV data with the intensity of each replicate vs. distance.
2. MATLAB scripts for analyzing and visualizing the results.

## Installation

### C++ Executable
1. Download the latest release from the [Releases page](https://github.com/P23K/Dye-Gradient-to-CSV/releases)
2. Run the installer (DyeGradienttoCSV_Setup.exe)
3. The program will be installed in your Documents folder (you can specify another directory if necessary). Note this directory down so you know where to find the program.

### MATLAB Scripts
1. Clone this repository or download the MATLAB files from the `matlab` folder.
2. Add the MATLAB files to your MATLAB path. They can then be used to analyse the data and visualize it.

## Usage

### Step 1: Image Processing
1. Launch DyeGradienttoCSV.exe.
2. Copy-paste the path to the folder containing the images to be analyzed. See the S.I. for directions on file naming. Files MUST be named correctly for the program to work as intended.
3. Adjust parameters if needed.
4. The program will generate CSV files for each RPM group (for each replicate, dye intensity vs. distance).

### Step 2: Data Analysis
1. Open MATLAB
2. Run `DyeProfileToSolventFrontDistance.m` and specify the path to the folder containing the dye profile CSV files. This program finds the solvent front distance for each RPM.
3. Additional analysis can be performed using:
   - `dMdT.m`. Specify a path to a CSV file containing the mass and temperature data (you MUST use the template provided in 'templates' for the script to work correctly.
   - `DyeProfileToWaterfall.m` and specify the path to the folder containing the dye profile CSV files. This script visualizes the dye profiles at each RPM.

## Project Structure
repository-root/
├── cpp/ # C++ image processing executable
├── matlab/ # MATLAB analysis scripts
└── README.md # This file

## Requirements

- Windows 10 or later
- MATLAB R2019b or later (for analysis scripts)

## Contributing

Feel free to open issues or submit pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
