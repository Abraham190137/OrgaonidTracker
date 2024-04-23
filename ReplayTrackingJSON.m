clear
clc
close all

% Create a video reader object to pull images from
tracker_data_file = 'out_test.json';
% tracker_data_file = "D21D28 0ugmL Swarm test.json";
fid = fopen(tracker_data_file);
raw = fread(fid, inf);
str = char(raw');
fclose(fid);
tracker_data = jsondecode(str);

% videoReader = VideoReader('D21D28 0ugmL Swarm.avi');
videoReader = VideoReader('AY07HH.mp4');

% Pull the first image and convert it to a grayscale image, storead as 
% matrix of decimal numbers from 0.0 to 1.0.
videoFrame = readFrame(videoReader);
videoFrame_adjust = double(imadjust(rgb2gray(videoFrame)))/255;

nbbox = length(tracker_data.organoids);


%Initialize a Video Player to Display the Results
videoPlayer  = vision.VideoPlayer('Position', [10 -100 1200 1200]);

t = 1;
while hasFrame(videoReader)
    % get the next frame
    videoFrame = readFrame(videoReader);
    videoFrame_adjust = double(imadjust(rgb2gray(videoFrame)))/255;

    % Insert a bounding box around the object being tracked
    for i =1:nbbox
        if ismember(t, tracker_data.organoids(i).FrameNums)
            idx = find(tracker_data.organoids(i).FrameNums == t);
            bboxVectors = tracker_data.organoids(i).bbox_vectors;
            position = [tracker_data.organoids(i).Xs(idx); tracker_data.organoids(i).Ys(idx)];
            rotation = tracker_data.organoids(i).Rotations(idx);
            bboxPoints = gridSearchTracker.transform_points_2d(bboxVectors, rotation, position);
            bboxPolygon = reshape(bboxPoints', 1, []);
            videoFrame = insertShape(videoFrame, 'Polygon', bboxPolygon, 'LineWidth', 2);
        end
    end 
    step(videoPlayer, videoFrame);
    pause(0.033)
    t = t + 1;
end

% cleanup
release(videoPlayer);
disp('finished good');



