% Enable hardware acceleration
set(groot, 'DefaultFigureRenderer', 'opengl');

% Prompt user to select the folder containing the datasets
folder_path = uigetdir('', 'Select the folder containing the datasets');
if folder_path == 0
    error('No folder selected. Please run the script again and select a folder.');
end

% Create input dialog for distance range parameters
prompt = {'Distance Lowerbound:', 'Distance Upperbound:', '# of Divisions:'};
dlgtitle = 'Set Distance Range Parameters';
dims = [1 35];
definput = {'24', '144', '7'}; % Default values
answer = inputdlg(prompt, dlgtitle, dims, definput);

% Check if user cancelled the dialog
if isempty(answer)
    error('Distance range parameters not provided. Please run the script again.');
end

% Convert inputs to numbers
distance_lower = str2double(answer{1});
distance_upper = str2double(answer{2});
num_divisions = str2double(answer{3});

% Validate inputs
if isnan(distance_lower) || isnan(distance_upper) || isnan(num_divisions)
    error('Invalid input. Please enter numeric values.');
end
if distance_lower >= distance_upper
    error('Lower bound must be less than upper bound.');
end
if num_divisions < 2
    error('Number of divisions must be at least 2.');
end

% Get a list of all CSV files in the selected folder
csv_files = dir(fullfile(folder_path, '*.csv'));

% Create a cell array to store file information
file_info = cell(length(csv_files), 2);
for i = 1:length(csv_files)
    file_info{i,1} = csv_files(i).name;
    % Extract RPM from filename
    rpm = str2double(regexp(csv_files(i).name, '(?<=_)\d+(?=_)', 'match', 'once'));
    file_info{i,2} = rpm;
end

% Sort files by RPM
[~, sort_idx] = sort(cell2mat(file_info(:,2)));
file_info = file_info(sort_idx,:);

% Create a figure for the waterfall plot with white background
figure('Position', [100 100 800 600]);
set(gcf, 'Color', 'white');  % Makes figure background white

% Set font properties
set(0, 'DefaultAxesFontName', 'Calibri');
set(0, 'DefaultAxesFontWeight', 'bold');
set(0, 'DefaultTextFontName', 'Calibri');
set(0, 'DefaultTextFontWeight', 'bold');

% Define color map for standard deviation (turbo colormap)
color_map = turbo(256);

% Create cell arrays to store data for each RPM
intensity_data = cell(length(file_info), 1);
std_data = cell(length(file_info), 1);
distance_data = cell(length(file_info), 1);

% Read and process all files
for file_idx = 1:length(file_info)
    % Get the current file name and RPM
    file_name = file_info{file_idx,1};
    rpm = file_info{file_idx,2};
    rpm_str = num2str(rpm);
    
    % Read data from the current CSV file
    data = readmatrix(fullfile(folder_path, file_name));
    
    % Extract distance and intensity values for each replicate
    distance = data(:, 1);
    intensity_r1 = data(:, 2);
    intensity_r2 = data(:, 3);
    intensity_r3 = data(:, 4);
    
    % Downsample the data for better performance
    downsample_factor = 5;
    distance = distance(1:downsample_factor:end);
    intensity_r1 = intensity_r1(1:downsample_factor:end);
    intensity_r2 = intensity_r2(1:downsample_factor:end);
    intensity_r3 = intensity_r3(1:downsample_factor:end);
    
    % Add debug print
    fprintf('File %s distance range: %.2f to %.2f (downsampled from %d to %d points)\n', ...
        file_name, min(distance), max(distance), size(data,1), length(distance));
    
    % Calculate average intensity and standard deviation
    avg_intensity = mean([intensity_r1, intensity_r2, intensity_r3], 2);
    std_intensity = std([intensity_r1, intensity_r2, intensity_r3], 0, 2);
    
    % Store the full data in cell arrays
    distance_data{file_idx} = distance;
    intensity_data{file_idx} = avg_intensity;
    std_data{file_idx} = std_intensity;
end

% Define RPM values (now taken from sorted file_info)
rpm_values = cell2mat(file_info(:,2))';

% Clear the current figure
clf;

% Create the axis and set its background transparent
ax = gca;
set(ax, 'Color', 'none');  % Makes axis background transparent
set(ax, 'YDir', 'reverse');  % Reverse the y-axis direction

% Find global min and max standard deviation values across all series
min_std = inf;
max_std = -inf;
for i = 1:length(std_data)
    min_std = min(min_std, min(std_data{i}));
    max_std = max(max_std, max(std_data{i}));
end

% Calculate min and max values for z-axis
min_intensity = inf;
max_intensity = -inf;
for i = 1:length(intensity_data)
    min_intensity = min(min_intensity, min(intensity_data{i}));
    max_intensity = max(max_intensity, max(intensity_data{i}));
end

% Set up the plot
hold on;

% Define fill color
fill_color = [0.9 0.9 0.9];  % Light gray

% Plot each series with its full data
for i = 1:length(intensity_data)
    % Get the current series data
    curr_distance = distance_data{i};
    curr_intensity = intensity_data{i};
    curr_std = std_data{i};
    
    % Create single fill
    x_fill = [rpm_values(i) * ones(1, length(curr_distance)), rpm_values(i), rpm_values(i)];
    y_fill = [curr_distance', curr_distance(end), curr_distance(1)];
    z_fill = [curr_intensity', min_intensity, min_intensity];
    
    % Fill area under the curve with rectangular base
    fill3(x_fill, y_fill, z_fill, fill_color, 'EdgeColor', 'none');
    
    % Calculate colors for each point based on standard deviation
    normalized_std = (curr_std - min_std) / (max_std - min_std);
    color_indices = max(1, min(size(color_map,1), round(normalized_std * (size(color_map,1)-1)) + 1));
    
    % Create line with point-by-point colors
    for j = 1:length(curr_distance)-1
        plot3([rpm_values(i) rpm_values(i)], ...
              [curr_distance(j) curr_distance(j+1)], ...
              [curr_intensity(j) curr_intensity(j+1)], ...
              'Color', color_map(color_indices(j), :), ...
              'LineWidth', 2);
    end
end
hold off;

% Add color bar with correct limits
colormap(color_map);
c = colorbar;
clim([min_std, max_std]);
c.Label.String = 'SDV Dye Intensity';
c.Label.FontWeight = 'bold';
c.Label.FontName = 'Calibri';

% Set axis labels and title
xlabel('RPM', 'FontWeight', 'bold');
ylabel('Distance From Bottom of Tube (mm)', 'FontWeight', 'bold');
zlabel('Dye Intensity', 'FontWeight', 'bold');

% Set up grid spacing with user-defined parameters
grid on;
ax.XTick = rpm_values;  % RPM values
ax.YTick = linspace(distance_lower, distance_upper, num_divisions);
ax.YTickLabel = cellstr(num2str(ax.YTick', '%.1f'));  % Convert to cell array of strings with 1 decimal place

% Adjust axis limits
xlim([min(rpm_values), max(rpm_values)]);
ylim([distance_lower, distance_upper]);
zlim([min_intensity, ceil(max_intensity*10)/10]);  % Autoscale z-axis based on data range

% Set view angle for better visualization
view(60, 30);

% Reset default font properties to prevent affecting other plots
set(0, 'DefaultAxesFontName', 'Helvetica');
set(0, 'DefaultAxesFontWeight', 'normal');
set(0, 'DefaultTextFontName', 'Helvetica');
set(0, 'DefaultTextFontWeight', 'normal');