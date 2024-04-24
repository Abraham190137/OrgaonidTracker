clear
clc
close all

%% Specify Parameters:
% video_file_name = 'AY07HH.mp4';
video_file_name = "data/D21D28 0ugmL Swarm.avi"; % Video to track
json_file_name = "data/test.json"; % file to save the tracking data to.
search_size = 5; % number of pixels around the organoid to search. This is the maximum number of pixels the tracker thinks the organoid can move in one frame (rec 10)
rotation_resolution_degree = 0.5; % resolution the tracker measures rotation, in degrees. All rotation values with be a multiple of this value. (rec 0.5)
print_freq = 10; % frequency with which to print out the current frame number.

% rotation post processing parameters (see post-processing section for more details)
max_acceleration = 1; % deg/frame/frame
max_speed = 5; % deg/frame

%% Run tracker

% Create a video reader object to pull images from
videoReader = VideoReader(video_file_name);
num_frames = videoReader.NumFrames
% videoReader = VideoReader('D21D28 200ugmL Swarm.avi');

% Pull the first image and convert it to a grayscale image, storead as 
% matrix of decimal numbers from 0.0 to 1.0.
videoFrame = readFrame(videoReader);
videoFrame_adjust = double(rgb2gray(videoFrame))/255;

% Have the user draw bounding boxes around the organoids. 
drawer = BoundingBoxDrawer(videoFrame);

% Wait for the user to finish drawing the bounding box and close the figure when Enter is pressed
waitfor(drawer.figureHandle);
bboxes = drawer.boundingBoxes;

% If you wish, you can specify the bounding boxes by hand. I did this for
% testing.
% bboxes = [370.0000  110.0000  123.0000  132.0000;
%   442.0000  231.0000  120.0000  121.0000;
%   702.0000  332.0000  110.0000  111.0000;
%   840.0000  466.0000  118.0000  110.0000;
%   951.0000  533.0000  103.0000  106.0000;
%   840.0000  729.0000  113.0000  110.0000;
%   629.0000  575.0000  130.0000  116.0000;
%   485.0000  642.0000  115.0000  114.0000;
%   379.0000  566.0000  106.0000  110.0000;
%   165.0000  627.0000  116.0000  113.0000]
[nbbox, ~] = size(bboxes)

frame_num = 1;

% for each bbox, create a tracker:
for i = 1:nbbox
    elipse_h = bboxes(i, 3);
    elipse_w = bboxes(i, 4);
    center = [bboxes(i, 1) + 0.5*bboxes(i, 3), bboxes(i, 2) + 0.5*bboxes(i, 4)];
    mask = zeros(size(videoFrame_adjust, 1:2));
    for h=bboxes(i, 1):bboxes(i, 1)+elipse_h
        for w=bboxes(i, 2):bboxes(i, 2)+elipse_w
            radius = ((h - center(1))/(0.5*elipse_h))^2 + ((w - center(2))/(0.5*elipse_w))^2;
            if radius < 1
                mask(round(w), round(h)) = 1;
            end
        end
    end
    trackers(i) = gridSearchTracker(bboxes(i, :), videoFrame_adjust, mask, frame_num, search_size, rotation_resolution_degree);
end

%% Initialize a Video Player to Display the Results
% videoPlayer  = vision.VideoPlayer('Position', [10 -100 1200 1200]);

% Insert a bounding box around the object being tracked
for i =1:nbbox
    bboxPolygon = reshape(trackers(i).bboxPoints', 1, []);
    videoFrame = insertShape(videoFrame, 'Polygon', bboxPolygon, ...
        'LineWidth', 2);
end 

% Display the annotated video frame using the video player object
% step(videoPlayer, videoFrame);
% imshow(videoFrame)
% pause(0.25)

global vid_state

vid_state = "play";

hplay = uicontrol('unit','pixel','style','pushbutton','string','PLAY',...
            'position',[10 10 50 25],'callback', @play_callback, 'value', 0);
hpause = uicontrol('unit','pixel','style','pushbutton','string','PAUSE',...
            'position',[60 10 50 25],'callback',@pause_callback);
hexit = uicontrol('unit','pixel','style','pushbutton','string','EXIT',...
            'position',[110 10 50 25],'callback',@exit_callback, 'value', 0);
haddbbox = uicontrol('unit','pixel','style','pushbutton','string','ADD BBOX',...
            'position',[160 10 50 25],'callback',@add_bbox);

while hasFrame(videoReader)
    % Print out the frame number as a progress tracker:
    
    if rem(frame_num, print_freq) == 0
        fprintf("Frame %d/%d\n", [frame_num, num_frames])
    end

    if vid_state == "exit"
        break;
    end

    if vid_state == "pause"
        pause(0.1);
        continue;
    end

    if vid_state == "add_bbox"
        drawer = BoundingBoxDrawer(videoFrame);
        waitfor(drawer.figureHandle);
        new_bboxes = drawer.boundingBoxes;
        [new_nbbox, ~] = size(new_bboxes);
        for i = 1:new_nbbox
            elipse_h = new_bboxes(i, 3);
            elipse_w = new_bboxes(i, 4);
            center = [new_bboxes(i, 1) + 0.5*new_bboxes(i, 3), new_bboxes(i, 2) + 0.5*new_bboxes(i, 4)];
            mask = zeros(size(videoFrame_adjust, 1:2));
            for h=new_bboxes(i, 1):new_bboxes(i, 1)+elipse_h
                for w=new_bboxes(i, 2):new_bboxes(i, 2)+elipse_w
                    radius = ((h - center(1))/(0.5*elipse_h))^2 + ((w - center(2))/(0.5*elipse_w))^2;
                    if radius < 1
                        mask(round(w), round(h)) = 1;
                    end
                end
            end
            trackers(end+1) = gridSearchTracker(new_bboxes(i, :), videoFrame_adjust, mask, frame_num, search_size, rotation_resolution_degree);
            bboxPolygon = reshape(trackers(end).bboxPoints', 1, []);
            videoFrame = insertShape(videoFrame, 'Polygon', bboxPolygon, 'LineWidth', 2);
        end
        nbbox = nbbox + new_nbbox;
        vid_state = "pause";
        imshow(videoFrame);
        drawnow;
        continue;
    end

    % get the next frame
    videoFrame = readFrame(videoReader);
    videoFrame_adjust = double(rgb2gray(videoFrame))/255;

    frame_num = frame_num + 1;

    % Track the points.
    for i = 1:nbbox
        trackers(i) = trackers(i).step_tracker(videoFrame_adjust, frame_num);
    end

    % Insert a bounding box around the object being tracked
    for i =1:nbbox
        bboxPolygon = reshape(trackers(i).bboxPoints', 1, []);
        % If the organoid is still in the image, display a bounding box
        % around it. 
    
        if trackers(i).organoid_in_image
            videoFrame = insertShape(videoFrame, 'Polygon', bboxPolygon, 'LineWidth', 2);
        end
    end 

    % Display the annotated video frame using the video player object
    imshow(videoFrame);
    drawnow;
%     step(videoPlayer, videoFrame);
%     pause(0.25)

end
% Clean up
close all
disp('Running Post Processing')

% Run postprocessing. This re-evalutes the rotations of the bboxes using
% process_rot_data_speed.m function. Basically, it enforces two constraints
% on the rotation of the organoids.
    % 1) the rotational speed of the organoid (measured in deg/frame) has
    % to be less than max_speed
    % 2) The maximum change of the rotational speed of the organoid, from
    % one frame to another, must be less than max_acc (deg/frame/frame).

% save("test_tracker.mat", "trackers")
for i = 1:nbbox
    tic;
    trackers(i) = trackers(i).post_process(max_speed, max_acceleration);
    toc % Print out time to save.
end

% save the trackers (for testing)
disp('Saving the trackers!')

json_data.file_name = video_file_name;
json_data.organoids = {};

for i = 1:nbbox
    json_data.organoids{end + 1} = trackers(i).get_data_object();
end

json_txt = jsonencode(json_data);

f_json = fopen(json_file_name, 'w');
fprintf(f_json, '%s', json_txt);
fclose(f_json);


disp('Finished!')

% buttons for controlling the interface.
function play_callback(hObject,eventdata)
    global vid_state;
    vid_state = "play"; 
end

function pause_callback(hObject,eventdata)
    global vid_state;
    vid_state = "pause";
end

function exit_callback(hObject,eventdata)
    global vid_state;
    vid_state = "exit";
end

function add_bbox(hObject, eventdata)
    global vid_state;
    vid_state = "add_bbox";
end


