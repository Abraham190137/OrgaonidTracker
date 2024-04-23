% loads in a json data file and export the position and rotation data to a csv file"

json_file = "data/test.json";
out_csv = "data/out.csv";

% read the tracker data from the cvs file.
fid = fopen(json_file);
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
tracker_data = jsondecode(str);

% We're gonna create the csv manually, because its a bit weird. 
% First, determine the maximum time.
n_organoids = length(tracker_data.organoids);
max_t = 1;
for i = 1:n_organoids
    max_t = max(tracker_data.organoids(i).FrameNums(end), max_t);
end

header = "T, ,";
% Create the header:
for i = 1:n_organoids
    header = strcat(header, "X,Y,Rotation");
    if i ~= n_organoids
        header = strcat(header, ", ,");
    end
end
file_lines = [header]; % end line

% Each timestep is a new line:
for t=1:max_t
    file_line = sprintf('%d, ,', t);
    for i = 1:n_organoids
        if ismember(t, tracker_data.organoids(i).FrameNums)
            idx = find(tracker_data.organoids(i).FrameNums == t);
            file_line = strcat(file_line, sprintf('%d, %d, %.2f', [tracker_data.organoids(i).Xs(idx), tracker_data.organoids(i).Ys(idx), tracker_data.organoids(i).Rotations(idx)]));
        else
            file_line = strcat(file_line, " , , ");
        end
        file_line = strcat(file_line, ", ,");
    end
    file_lines(end + 1) = file_line; % end line
end

% Finally, save text to csv file.
writelines(file_lines, out_csv)


        



