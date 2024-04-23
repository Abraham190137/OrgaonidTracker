% This script allows you to re-run the optimize rotations function on a
% saved data.json file, with different speed and acceleration parameters.

input_file = "data/test.json";
output_file = "data/out_test.json";
max_speed = 10;
max_acc = 1;

% load organoid data
fid = fopen(input_file);
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
tracker_data = jsondecode(str);

% run rotation optimizer
for i = 1:length(tracker_data.organoids)
    tic;
    tracker_correlations = {};
    % The correlations expected to be a cell list of arrays, so we need to
    % reformat them as such.
    for t = 1:size(tracker_data.organoids(i).all_correlations, 1);
        tracker_correlations{t} = tracker_data.organoids(i).all_correlations(t, :);
    end
    tracker_data.organoids(i).Rotations = process_rot_data_speed(tracker_correlations, max_speed, max_acc)';
    toc
end

% save results
f_json = fopen(output_file, 'w');
fprintf(f_json, '%s', jsonencode(tracker_data));
fclose(f_json);