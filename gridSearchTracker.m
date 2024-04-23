classdef gridSearchTracker
    properties(Access = public)
        bboxPoints;
    end
    properties(Access = public) % private
        center_point;
        first_bbox;
        center_points;
        all_correlations = {};
        rotations = [0];
        rotation = 0;
        bbox_vectors;
        template_matcher;
        blank_template_matcher;
        template_radius;
        search_radius;
        mask;
        frame_numbers;
        search_size;
        deg_step; % Step size of the rotation tracker.
        organoid_in_image = true; 
        bboxH;
        bboxW;
        template_norm;
    end
    methods(Access = public)
        % Initalizer
        function obj = gridSearchTracker(bbox, inital_img, mask, frame_number, search_size, deg_step)

            % Save initial inputs
            obj.frame_numbers = [frame_number];
            obj.first_bbox = bbox;
            obj.mask = mask;
            obj.search_size = search_size;
            obj.deg_step = deg_step;

            % Create the boudning box.
            obj.bboxPoints = bbox2points(bbox);
            obj.bboxH = bbox(4);
            obj.bboxW = bbox(3);
            obj.center_point = round([bbox(1) + 0.5*bbox(3), bbox(2) + 0.5*bbox(4)]); % center point of the organoid
            obj.center_points = obj.center_point; % list of center point over time
            obj.bbox_vectors = obj.bboxPoints - obj.center_point; % vector from center point to bbox points (transformed with rotation to rotate bbox)
            obj.template_radius = ceil(max(bbox(3:4))/2); % half of the diameter fo the bbox (largest direction).

            % Create a search bbox big enough that the template can be
            % rotated inside of it (template is an oval)
            search_bbox = [obj.center_point(1) - obj.template_radius, ...
                        obj.center_point(2) - obj.template_radius, ...
                        2*obj.template_radius, 2*obj.template_radius];

            % Create templates to search for the organiods throughout the
            % image. Need both a template (organoid) and a blank template
            % for comparison
            blank_template = imcrop(mask, search_bbox);
            template = imcrop(mask.*inital_img, search_bbox);

            obj.search_radius = obj.template_radius + obj.search_size;
            search_img_size = [2*obj.search_radius + 1, 2*obj.search_radius + 1];
            obj.template_norm = sqrt(sum(template.^2, 'all')); % norm of the template
            
            % Create the template matchers, objects that determine how
            % similar an input image is to the recorded template. To deal
            % with rotation, initialize a collection of matchers with
            % rotated templates. 
            do_rotation = true;
            if do_rotation
                for i=1:round(360/obj.deg_step) % create a template for each degree step
                    rot_templates(:, :, i) = imrotate(template, obj.deg_step*(i-1), 'crop');
                    rot_blank_templates(:, :, i) = imrotate(blank_template, obj.deg_step*(i-1), 'crop');
                    
                end 
                obj.template_matcher = NNTemplateMatcher(rot_templates, search_img_size);
                obj.blank_template_matcher = NNTemplateMatcher(rot_blank_templates, search_img_size);
            else
                obj.template_matcher = NNTemplateMatcher(template, search_img_size);
                obj.blank_template_matcher = NNTemplateMatcher(blank_template, search_img_size);
            end
        end

        

        function obj = step_tracker(obj, in_img, frame_number)
            % Take one step of the tracker, idenifying where the oraniod
            % is and its rotation.

            % If the organoid is no longer in the image, do nothing.
            if ~obj.organoid_in_image
                return;
            end

            obj.frame_numbers(end + 1, 1) = frame_number;
            
            % make a copy of the in_image (to avoid pass by reference??)
            img = in_img(:, :);

            % Define the search region - this is the area we will search
            % for the organoid in
            search_region = [obj.center_point(2)-obj.search_radius, ...
                              obj.center_point(2)+obj.search_radius;
                              obj.center_point(1)-obj.search_radius,...
                              obj.center_point(1)+obj.search_radius];
            
            % The search region may go off the screen. If it does, then add
            % some padding to the image so that the tracker can run.
            % However, if the pad size is too big (ie, the organoid is too
            % far off the screen) set in_img to false (stops tracking).
            padsize = max(1-min(search_region(:, 1)), max(search_region(:, 2) - [size(img, 1); size(img, 2)]));
            if padsize > 0
                img = padarray(img, [padsize, padsize], mean(img, 'all'));
                search_region = search_region + padsize;
                if padsize > min(obj.first_bbox(3:4))/4
                    obj.organoid_in_image = false;
                    disp("organoid out of image, skipping");
                end
            end

            search_img = img(search_region(1, 1):search_region(1, 2), ...
                             search_region(2, 1):search_region(2, 2));

            % Use the template matrix to determine the similarity of the
            % the search image to the template (image of the oranoid).
            % Devide by the blank correction to normalize for brightness.
            template_correlation = obj.template_matcher.eval(search_img);
            image_norm = sqrt(obj.blank_template_matcher.eval(search_img.^2));
            correlation_matrix = template_correlation./(image_norm*obj.template_norm); % cosine similarity = a*b/(||a||*||b||)

            % The resultin correlation matrix of of shape 
            % [search_size*2+1, search_size*2+1, nrot]. Each entry measures
            % how close the area, centered on the specified pixel is to the
            % organiod template. Actually, we compare it to nrot templates,
            % one for each organoid, to measure how close it is to all
            % possible rotation of the organoid.

            % The position and rotation that has the highest similarity is
            % where the organoid is!         
            [~, argmax] = max(correlation_matrix, [], 'all');
            [x_max, y_max, ~] = ind2sub(size(correlation_matrix), gather(argmax));

            % For the rotation, we record the maximum correlation for each
            % rotation and save it. We will use this later to refind the
            % rotation.
            obj.all_correlations{end+1} = gather(max(correlation_matrix, [], [1,2]));

            % do again for rotation:
            [~, r_max] = max(max(correlation_matrix, [], [1,2]));
            r_max = gather(r_max);

            % Update ths saved rotaion, positin, and bbox Points values
            obj.rotation = -(r_max - 1)*obj.deg_step;
            delta = [y_max, x_max] - (obj.search_size + 1);
            obj.center_point = obj.center_point + delta;
            obj.bboxPoints = obj.transform_points_2d(obj.bbox_vectors, obj.rotation, obj.center_point);
            
            % record the center point and rotation
            obj.center_points(end+1, :) = obj.center_point;
            obj.rotations(end+1, 1) = obj.rotation;
        end

        function obj = post_process(obj, max_speed_deg, max_acc_deg)
            % Uses the process_rot_data function to optimize the rotation
            % data. See process_rot_data.m for more information. This takes
            % sometime, and should be run after tracking is finished. 
            obj.rotations = process_rot_data_speed(obj.all_correlations, max_speed_deg, max_acc_deg)';
        end
        

        function data_object = get_data_object(obj)
            data_object.bboxHeight = obj.bboxH;
            data_object.bboxWidth = obj.bboxW;
            data_object.FrameNums = obj.frame_numbers;
            data_object.Xs = obj.center_points(:, 1);
            data_object.Ys = obj.center_points(:, 2);
            data_object.Rotations = obj.rotations;
            data_object.bbox_vectors = obj.bbox_vectors;
            data_object.all_correlations = obj.all_correlations;
        end

        function bbox_points = get_bbox_points(obj, t)
            bbox_points = obj.transform_points_2d(obj.bbox_vectors, obj.rotations(t), obj.center_points(t, :));
        end
    end

    methods(Static)
        function transformed_points = transform_points_2d(points, rotation, translation)
            % Applys the specified rotation and translation to the input
            % points. Points are a (Nx2) matrix in the form of [x, y]
            tranformation_matrix = [cosd(rotation), -sind(rotation), translation(1);
                                    sind(rotation), cosd(rotation),  translation(2);
                                    0,             0,              1];
            homogenous_points = [points.'; ones(1, size(points, 1))];
            homo_transformed_points = tranformation_matrix*homogenous_points; % transformed points in homogenous coordinates
            transformed_points = homo_transformed_points(1:2, :).'; % return non-homogenous coordinages
        end
    end
end