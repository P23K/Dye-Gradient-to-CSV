% Open file dialog for CSV selection
[filename, filepath] = uigetfile('*.csv', 'Select the CSV file');
if filename == 0
    error('No file selected. Script terminated.');
end
fullpath = fullfile(filepath, filename);

% Read in data from selected CSV
data = readtable(fullpath);

% Create figure for mass difference
figure('Position', [100 100 600 500]);
hold on;

% Set font properties
set(0, 'DefaultAxesFontName', 'Calibri');
set(0, 'DefaultAxesFontWeight', 'bold');
set(0, 'DefaultTextFontName', 'Calibri');
set(0, 'DefaultTextFontWeight', 'bold');

% Get unique solvents from data
solvents = unique(data.Solvent);
num_solvents = length(solvents);

% Initialize colors cell array
colors = cell(1, num_solvents);

% Let user pick colors for each solvent
for i = 1:num_solvents
    title_str = sprintf('Select color for %s', solvents{i});
    colors{i} = uisetcolor([], title_str);
    if length(colors{i}) == 1  % User pressed cancel
        error('Color selection cancelled. Script terminated.');
    end
end

% Process each solvent type for mass data
for solv_idx = 1:num_solvents
    % Extract data for current solvent
    current_data = data(strcmp(data.Solvent, solvents{solv_idx}), :);
    rpm_values = current_data.RPM;
    m0 = [current_data.M0_R1 current_data.M0_R2 current_data.M0_R3];
    mf = [current_data.MF_R1 current_data.MF_R2 current_data.MF_R3];
    mass_diff = mf - m0;
    avg_mass_diff = mean(mass_diff, 2);
    std_mass_diff = std(mass_diff, 0, 2);

    % Calculate the upper and lower bounds of the confidence interval
    lower_bound = avg_mass_diff - 1.96*std_mass_diff/sqrt(3);
    upper_bound = avg_mass_diff + 1.96*std_mass_diff/sqrt(3);

    % Create the x-coordinates and y-coordinates for the polygon
    x_coords = [rpm_values', fliplr(rpm_values')];
    y_coords = [upper_bound', fliplr(lower_bound')];

    % Plot the shaded confidence interval (without adding to legend)
    fill(x_coords, y_coords, colors{solv_idx}, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    % Plot average mass of remaining solvent (with legend entry)
    plot(rpm_values, avg_mass_diff, 'o-', 'LineWidth', 2, 'MarkerFaceColor', colors{solv_idx}, 'MarkerEdgeColor',colors{solv_idx}, 'Color', colors{solv_idx}, 'DisplayName', solvents{solv_idx});
end

xlabel('RPM', 'FontWeight', 'bold');
ylabel('Residual Solvent Mass (g)', 'FontWeight', 'bold');
legend('Location', 'best', 'FontWeight', 'bold');

% Create figure for temperature difference
figure('Position', [700 100 600 500]);
hold on;

% Process temperature data for each solvent
for solv_idx = 1:num_solvents
    % Extract temperature data for current solvent
    current_data = data(strcmp(data.Solvent, solvents{solv_idx}), :);
    rpm_values = current_data.RPM;
    t_initial = [current_data.TInitial_R1 current_data.TInitial_R2 current_data.TInitial_R3];
    t_final = [current_data.TFinal_R1 current_data.TFinal_R2 current_data.TFinal_R3];
    temp_diff = t_final - t_initial;
    avg_temp_diff = mean(temp_diff, 2);
    std_temp_diff = std(temp_diff, 0, 2);

    % Calculate bounds and create coordinates for temperature plot
    lower_bound = avg_temp_diff - 1.96*std_temp_diff/sqrt(3);
    upper_bound = avg_temp_diff + 1.96*std_temp_diff/sqrt(3);
    x_coords = [rpm_values', fliplr(rpm_values')];
    y_coords = [upper_bound', fliplr(lower_bound')];

    % Plot the shaded confidence interval (without adding to legend)
    fill(x_coords, y_coords, colors{solv_idx}, 'FaceAlpha', 0.3, 'EdgeColor', 'none', 'HandleVisibility', 'off');

    % Plot average temperature difference line (with legend entry)
    plot(rpm_values, avg_temp_diff, 'o-', 'LineWidth', 2, 'MarkerFaceColor', colors{solv_idx}, 'MarkerEdgeColor', colors{solv_idx}, 'Color', colors{solv_idx}, 'DisplayName', solvents{solv_idx});
end

xlabel('RPM', 'FontWeight', 'bold');
ylabel('Average Temperature Difference (°C)', 'FontWeight', 'bold');
legend('Location', 'best', 'FontWeight', 'bold');

% Reset default font properties to prevent affecting other plots
set(0, 'DefaultAxesFontName', 'Helvetica');
set(0, 'DefaultAxesFontWeight', 'normal');
set(0, 'DefaultTextFontName', 'Helvetica');
set(0, 'DefaultTextFontWeight', 'normal');