#include <opencv2/opencv.hpp>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <regex>
#include <algorithm>
#include <limits>
#include <cassert>
#include <ctime>
#include <iomanip>

namespace fs = std::filesystem;

// Function to extract unique RPMs from filenames
std::vector<int> extractUniqueRPMs(const std::vector<std::string>& filenames, const std::string& identifier) {
    std::set<int> uniqueRPMs;
    std::regex pattern(identifier + "_(\\d+)_R\\d+");
    std::smatch match;

    for (const auto& filename : filenames) {
        if (std::regex_search(filename, match, pattern)) {
            uniqueRPMs.insert(std::stoi(match[1].str()));
        }
    }
    return std::vector<int>(uniqueRPMs.begin(), uniqueRPMs.end());
}

// Function to validate that each RPM has three replicates
bool validateReplicates(const std::vector<std::string>& filenames, const std::vector<int>& uniqueRPMs, const std::string& identifier) {
    for (const auto& rpm : uniqueRPMs) {
        int count = 0;
        for (const auto& filename : filenames) {
            if (filename.find(identifier + "_" + std::to_string(rpm) + "_R") != std::string::npos) {
                ++count;
            }
        }
        if (count != 3) {
            std::cerr << "Error: RPM " << rpm << " does not have exactly 3 replicates.\n";
            return false;
        }
    }
    return true;
}

// Function to get filenames in a folder
std::vector<std::string> getFilenames(const std::string& folderPath) {
    std::vector<std::string> filenames;
    for (const auto& entry : fs::directory_iterator(folderPath)) {
        if (entry.is_regular_file()) {
            filenames.push_back(entry.path().filename().string());
        }
    }
    return filenames;
}

// Function to trim image widths to match the smallest width in a group
void alignImageWidths(std::vector<cv::Mat>& images) {
    int minCols = std::numeric_limits<int>::max();
    for (const auto& image : images) {
        if (image.cols < minCols) {
            minCols = image.cols;
        }
    }

    for (auto& image : images) {
        if (image.cols > minCols) {
            image = image(cv::Rect(0, 0, minCols, image.rows)); // Crop to minimum width
        }
    }
}

// Function to trim image heights to match the smallest height in a group
void alignImageHeights(std::vector<cv::Mat>& images) {
    int minRows = std::numeric_limits<int>::max();
    for (const auto& image : images) {
        if (image.rows < minRows) {
            minRows = image.rows;
        }
    }

    for (auto& image : images) {
        if (image.rows > minRows) {
            image = image(cv::Rect(0, 0, image.cols, minRows)); // Crop to minimum height
        }
    }
}

// Function to process images for a specific RPM
void processRPMImages(const std::vector<std::string>& filenames, const std::string& folderPath, 
                     int rpm, const std::string& outputFolder, const std::string& identifier,
                     double distanceUpper, double distanceLower, char channelChoice, int blurRadius) {
    std::vector<cv::Mat> images;
    std::vector<std::string> replicateNames;

    std::cout << "Processing RPM: " << rpm << std::endl;

    // Load images and apply Gaussian Blur if requested
    for (const auto& filename : filenames) {
        if (filename.find(identifier + "_" + std::to_string(rpm) + "_R") != std::string::npos) {
            std::cout << "Loading image: " << filename << std::endl;
            cv::Mat image = cv::imread(folderPath + "/" + filename, cv::IMREAD_UNCHANGED);
            if (image.empty()) {
                std::cerr << "Error: Could not load image: " << filename << std::endl;
                continue;
            }
            std::cout << "Original image dimensions: " << image.rows << "x" << image.cols << std::endl;

            // Apply Gaussian Blur only if radius > 0
            if (blurRadius > 0) {
                cv::GaussianBlur(image, image, cv::Size(2 * blurRadius + 1, 2 * blurRadius + 1), 0);
            }
            images.push_back(image);
            replicateNames.push_back(filename);
        }
    }

    // Check if we have the expected number of replicates
    if (images.size() != 3) {
        std::cerr << "Error: Unexpected number of images for RPM " << rpm << ". Expected 3, but found " << images.size() << "." << std::endl;
        return;
    }

    // Align image widths and heights
    alignImageWidths(images);
    alignImageHeights(images);
    // Save aligned and blurred images for verification
    std::string alignedImagesPath = outputFolder + "/aligned_images";
    std::filesystem::create_directories(alignedImagesPath);
    
    for (size_t i = 0; i < images.size(); ++i) {
        cv::Mat saveImage;
        
        // Debug original image info
        std::cout << "Original image type: " << images[i].type() 
                  << ", channels: " << images[i].channels() 
                  << ", min/max values: ";
        double minVal, maxVal;
        cv::minMaxLoc(images[i], &minVal, &maxVal);
        std::cout << minVal << "/" << maxVal << std::endl;

        // Preserve floating point data by saving directly
        images[i].convertTo(saveImage, CV_32F);  // Keep as float

        // Ensure proper path separators and file extension
        std::string outputFilename = alignedImagesPath + "/" + 
            identifier + "_" + std::to_string(rpm) + "_R" + std::to_string(i + 1) + 
            "_" + std::to_string(images[i].cols) + "x" + std::to_string(images[i].rows) + 
            "_aligned.tif";  // Changed to .tif
            
        // Replace any potential Windows backslashes with forward slashes
        std::replace(outputFilename.begin(), outputFilename.end(), '\\', '/');
        
        std::cout << "Saving aligned image to: " << outputFilename << std::endl;
        std::cout << "Image type before saving: " << saveImage.type() 
                  << ", channels: " << saveImage.channels() << std::endl;
        
        // Use TIFF-specific parameters to preserve float data
        std::vector<int> compression_params;
        compression_params.push_back(cv::IMWRITE_TIFF_COMPRESSION);
        compression_params.push_back(1);  // No compression
        
        bool success = cv::imwrite(outputFilename, saveImage, compression_params);
        if (!success) {
            std::cerr << "Failed to save image: " << outputFilename << std::endl;
        }
    }

    // Debug aligned image dimensions
    for (size_t i = 0; i < images.size(); ++i) {
        std::cout << "Aligned image " << (i + 1) << " dimensions: "
                  << images[i].rows << "x" << images[i].cols << std::endl;
    }

    // Prepare CSV output
    std::string csvFilePath = outputFolder + "/" + identifier + "_" + std::to_string(rpm) + "_" + std::string(1, channelChoice) + "ness.csv";
    std::ofstream csvFile(csvFilePath);
    if (!csvFile.is_open()) {
        std::cerr << "Error: Could not create CSV file: " << csvFilePath << std::endl;
        return;
    }

    std::cout << "Writing CSV to: " << csvFilePath << std::endl;

    // Update CSV headers based on channel
    std::string channelName;
    switch (channelChoice) {
        case 'R': channelName = "Redness"; break;
        case 'G': channelName = "Greenness"; break;
        case 'B': channelName = "Blueness"; break;
    }
    
    csvFile << "Distance (cm)," << channelName << " R1," << channelName << " R2," 
            << channelName << " R3,Average " << channelName << "\n";

    int cols = images[0].cols;
    int rows = images[0].rows;
    double pixelWidth = (distanceUpper - distanceLower) / cols;

    for (int x = 0; x < cols; ++x) {
        csvFile << distanceUpper - x * pixelWidth;  // Write distance
        double averageColorGroup = 0.0; // Track average color intensity for the group
        for (const auto& image : images) {
            double totalColor = 0.0;

            // Iterate through all rows in the column and calculate average color intensity
            for (int y = 0; y < rows; ++y) {
                assert(y < image.rows && x < image.cols && "Out-of-bounds access detected!");

                cv::Vec3f pixel = image.at<cv::Vec3f>(y, x);
                float blue = pixel[0];
                float green = pixel[1];
                float red = pixel[2];
                float luminance = red + green + blue;
                
                // Select color based on user choice
                float selectedColor;
                switch (channelChoice) {
                    case 'R': selectedColor = red; break;
                    case 'G': selectedColor = green; break;
                    case 'B': selectedColor = blue; break;
                }
                
                totalColor += (luminance > 0) ? selectedColor / luminance : 0.0f;
            }

            double averageColor = totalColor / rows;
            averageColorGroup += averageColor;
            csvFile << "," << averageColor;
        }

        // Write average color across replicates
        csvFile << "," << (averageColorGroup / images.size()) << "\n";
    }

    csvFile.close();
    std::cout << "Processed RPM " << rpm << " and saved " << channelName 
              << " data to: " << csvFilePath << std::endl;
}

// Add this class definition before initializeLogging function
class DualStreamBuffer : public std::streambuf {
    std::streambuf *console, *file;
    static DualStreamBuffer* instance;
    
    DualStreamBuffer() : console(nullptr), file(nullptr) {}
    
public:
    static DualStreamBuffer* getInstance() {
        if (!instance) {
            instance = new DualStreamBuffer();
        }
        return instance;
    }
    
    void init(std::streambuf* c, std::streambuf* f) {
        console = c;
        file = f;
    }
    
protected:
    int overflow(int c) override {
        if (c != EOF) {
            console->sputc(c);
            file->sputc(c);
        }
        return c;
    }
};

DualStreamBuffer* DualStreamBuffer::instance = nullptr;
static std::ofstream g_logFile;

void initializeLogging(const std::string& identifier) {
    fs::create_directory("logs");
    
    std::string filename = "logs/" + identifier + "_log_";
    time_t now = time(nullptr);
    char timestamp[20];
    strftime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S", localtime(&now));
    filename += timestamp;
    filename += ".txt";
    
    g_logFile.open(filename);
    auto buffer = DualStreamBuffer::getInstance();
    buffer->init(std::cout.rdbuf(), g_logFile.rdbuf());
    std::cout.rdbuf(buffer);
}

int main() {
    // Ask user for the identifier
    std::string identifier;
    std::cout << "Enter the identifier for the dataset (e.g., W, SF, etc.): ";
    std::cin >> identifier;
    
    // Initialize logging after getting the identifier
    initializeLogging(identifier);
    
    // Get and validate distance bounds
    double distanceUpper, distanceLower;
    bool validInput = false;
    
    // Get Upper bound
    do {
        std::cout << "Please specify Distance Upperbound (Distance at left side of all images): ";
        if (std::cin >> distanceUpper) {
            validInput = true;
        } else {
            std::cout << "Error: Please enter a valid number.\n";
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        }
    } while (!validInput);
    
    // Reset for lower bound input
    validInput = false;
    
    // Get Lower bound
    do {
        std::cout << "Please specify Distance Lowerbound (Distance at right side of all images): ";
        if (std::cin >> distanceLower) {
            if (distanceLower >= distanceUpper) {
                std::cout << "Error: Lower bound must be less than upper bound (" << distanceUpper << ").\n";
                continue;
            }
            validInput = true;
        } else {
            std::cout << "Error: Please enter a valid number.\n";
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        }
    } while (!validInput);
    
    // Get color channel choice
    char channelChoice;
    bool validChannel = false;
    do {
        std::cout << "Specify channel to analyze (R/G/B): ";
        std::cin >> channelChoice;
        channelChoice = std::toupper(channelChoice);  // Convert to uppercase
        if (channelChoice == 'R' || channelChoice == 'G' || channelChoice == 'B') {
            validChannel = true;
        } else {
            std::cout << "Error: Please enter R, G, or B.\n";
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        }
    } while (!validChannel);

    // Get blur radius
    int blurRadius;
    bool validRadius = false;
    do {
        std::cout << "Please specify the Gaussian blur radius (integers only; default = 10, for no blur, enter 0): ";
        if (std::cin >> blurRadius) {
            if (blurRadius >= 0) {  // Check for non-negative value
                validRadius = true;
            } else {
                std::cout << "Error: Please enter a non-negative number.\n";
            }
        } else {
            std::cout << "Error: Please enter a valid integer.\n";
            std::cin.clear();
            std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
        }
    } while (!validRadius);
    
    // Ask user for input and output folder paths
    std::string folderPath, outputFolder;
    std::cout << "Enter the path to the input folder: ";
    std::cin >> folderPath;
    std::cout << "Enter the path to the output folder: ";
    std::cin >> outputFolder;

    // Get filenames in the folder
    std::vector<std::string> filenames = getFilenames(folderPath);

    // Extract unique RPMs
    std::vector<int> uniqueRPMs = extractUniqueRPMs(filenames, identifier);

    // Validate replicates
    if (!validateReplicates(filenames, uniqueRPMs, identifier)) {
        return -1;
    }

    // Process each RPM
    for (const auto& rpm : uniqueRPMs) {
        processRPMImages(filenames, folderPath, rpm, outputFolder, identifier, 
                        distanceUpper, distanceLower, channelChoice, blurRadius);
    }

    return 0;
}
