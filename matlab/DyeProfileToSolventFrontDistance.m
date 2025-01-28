% Multi-Dataset Solvent Front Analysis Script

% Initialize storage for results across datasets
all_results = struct();

% Ask user for number of datasets
num_datasets = inputdlg('Enter the number of datasets to analyze:', 'Dataset Count', [1 50]);
num_datasets = str2double(num_datasets{1});

% Create figure for solvent front vs RPM
solvent_front_fig = figure('Position', [100 100 1000 600]);
hold on;

% Initialize colors cell array (replacing the hsv color map)
dataset_colors = cell(1, num_datasets);

% Iterate through datasets
for dataset_idx = 1:num_datasets
    % Prompt user to select folder for current dataset
    dataset_name = inputdlg(sprintf('Enter name for Dataset %d:', dataset_idx), 'Dataset Name', [1 50]);
    dataset_name = dataset_name{1};
    
    % Let user pick color for this dataset
    title_str = sprintf('Select color for dataset: %s', dataset_name);
    selected_color = uisetcolor([], title_str);
    if length(selected_color) == 1  % User pressed cancel
        error('Color selection cancelled. Script terminated.');
    end
    dataset_colors{dataset_idx} = selected_color;
    
    % Get folder path
    folder_path = uigetdir('', sprintf('Select folder for %s', dataset_name));
    if folder_path == 0
        error('No folder selected. Please run the script again and select a folder.');
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

    % Ask for maximum RPM to analyze
    max_rpm_input = inputdlg('Enter maximum RPM to analyze (or leave blank for all):', 'Max RPM', [1 50]);
    if ~isempty(max_rpm_input{1})
        max_rpm = str2double(max_rpm_input{1});
        % Filter out RPMs above max_rpm
        rpm_mask = cell2mat(file_info(:,2)) <= max_rpm;
        file_info = file_info(rpm_mask,:);
    end

    % Create cell arrays to store data for each RPM
    solvent_front_distance = zeros(length(file_info), 3);
    solvent_front_avg = zeros(length(file_info), 1);
    solvent_front_std = zeros(length(file_info), 1);

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
        
        % Calculate reference intensity for each replicate (average of last 10 mm)
        last_10mm_mask = distance >= (max(distance) - 10);
        reference_intensity_r1 = mean(intensity_r1(last_10mm_mask));
        reference_intensity_r2 = mean(intensity_r2(last_10mm_mask));
        reference_intensity_r3 = mean(intensity_r3(last_10mm_mask));
        
        % Find the solvent front distance for each replicate
        for replicate = 1:3
            intensity = data(:, replicate + 1);
            reference_intensity = mean(intensity(last_10mm_mask));
            
            for i = length(distance):-1:1
                if intensity(i) <= (reference_intensity + 0.05)
                    solvent_front_distance(file_idx, replicate) = distance(i);
                    break;
                end
            end
        end
        
        % Calculate average and standard deviation of solvent front distances for the current RPM
        solvent_front_avg(file_idx) = mean(solvent_front_distance(file_idx, :));
        solvent_front_std(file_idx) = std(solvent_front_distance(file_idx, :));
    end

    % Define RPM values (now taken from sorted file_info)
    rpm_values = cell2mat(file_info(:,2))';

    % Prepare for plotting solvent front
    figure(solvent_front_fig);
    
    % Calculate the upper and lower bounds of the confidence interval
    lower_bound = solvent_front_avg - 1.96*solvent_front_std/sqrt(3);
    upper_bound = solvent_front_avg + 1.96*solvent_front_std/sqrt(3);
    
    % Create the x-coordinates and y-coordinates for the polygon
    x_coords = [rpm_values, fliplr(rpm_values)];
    y_coords = [upper_bound', fliplr(lower_bound')];
    
    % Plot the shaded confidence interval (not shown in legend)
    h = fill(x_coords, y_coords, dataset_colors{dataset_idx}, 'FaceAlpha', 0.3, 'EdgeColor', 'none');
    set(h, 'HandleVisibility', 'off');  % This prevents the fill from appearing in the legend
    
    % Plot solvent front line
    plot(rpm_values, solvent_front_avg, 'o-', ...
        'LineWidth', 2, ...
        'MarkerFaceColor', dataset_colors{dataset_idx}, ...
        'MarkerEdgeColor', 'black', ...
        'Color', dataset_colors{dataset_idx}, ...
        'DisplayName', dataset_name);
    
    % Store results for this dataset
    all_results.(genvarname(dataset_name)) = struct(...
        'rpm_values', rpm_values, ...
        'solvent_front_avg', solvent_front_avg, ...
        'solvent_front_std', solvent_front_std ...
    );
end

% Finalize solvent front plot
figure(solvent_front_fig);
xlabel('RPM', 'FontWeight', 'bold');
ylabel('Solvent Front Distance (mm)', 'FontWeight', 'bold');
legend('show', 'Location', 'best');

% Print out the solvent front distances for reference
disp('Solvent Front Distances:');
dataset_names = fieldnames(all_results);
for i = 1:length(dataset_names)
    dataset = all_results.(dataset_names{i});
    fprintf('\nDataset: %s\n', dataset_names{i});
    for j = 1:length(dataset.rpm_values)
        fprintf('RPM %d: %.2f mm (Std: %.4f)\n', ...
            dataset.rpm_values(j), ...
            dataset.solvent_front_avg(j), ...
            dataset.solvent_front_std(j));
    end
end