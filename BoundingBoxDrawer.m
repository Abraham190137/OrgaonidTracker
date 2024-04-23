classdef BoundingBoxDrawer < handle

    properties
        img
        figureHandle
        axesHandle
        isDrawing = false
        currentBoundingBox = []
        boundingBoxes = []
        rectangleHandles = []
    end

    methods
        function obj = BoundingBoxDrawer(img)
            obj.img = img;
            obj.figureHandle = figure;
            obj.axesHandle = axes('Parent', obj.figureHandle);
            imshow(obj.img, 'Parent', obj.axesHandle);
            title(obj.axesHandle, 'Click and Drag to Draw Bounding Boxes. Press Enter when you are finished. To undo a selection, press backspace.');

            % Callback function for mouse button down event
            set(obj.figureHandle, 'WindowButtonDownFcn', @obj.startDrawing);

            % Callback function for mouse button up event
            set(obj.figureHandle, 'WindowButtonUpFcn', @obj.stopDrawing);

            % Callback function for key press event
            set(obj.figureHandle, 'KeyPressFcn', @obj.keyPressed);
        end

        function startDrawing(obj, ~, ~)
            obj.isDrawing = true;
            initialPoint = get(obj.axesHandle, 'CurrentPoint');
            x1 = initialPoint(1, 1);
            y1 = initialPoint(1, 2);
            obj.currentBoundingBox = [x1, y1, 0, 0];
            obj.boundingBoxes = [obj.boundingBoxes; obj.currentBoundingBox];
            obj.rectangleHandles(end + 1) = rectangle('Position', [x1, y1, 0, 0], 'EdgeColor', 'r', 'LineWidth', 2, 'Parent', obj.axesHandle);
            set(obj.figureHandle, 'WindowButtonMotionFcn', @obj.drawRectangle);
        end

        function drawRectangle(obj, ~, ~)
            if obj.isDrawing
                currentPoint = get(obj.axesHandle, 'CurrentPoint');
                x2 = currentPoint(1, 1);
                y2 = currentPoint(1, 2);
                width = abs(x2 - obj.currentBoundingBox(1));
                height = abs(y2 - obj.currentBoundingBox(2));
                x = min(obj.currentBoundingBox(1), x2);
                y = min(obj.currentBoundingBox(2), y2);
                obj.currentBoundingBox = [x, y, width, height];
                obj.boundingBoxes(end, :) = obj.currentBoundingBox;
                set(obj.rectangleHandles(end), 'Position', [x, y, width, height]);
            end
        end

        function stopDrawing(obj, ~, ~)
            obj.isDrawing = false;
            set(obj.figureHandle, 'WindowButtonMotionFcn', '');
        end

        function keyPressed(obj, ~, event)
            if strcmp(event.Key, 'return')
                close(obj.figureHandle);
            elseif strcmp(event.Key, 'backspace') && ~isempty(obj.boundingBoxes)
                % Remove the last bounding box and its associated rectangle handle
                obj.boundingBoxes(end, :) = [];
                delete(obj.rectangleHandles(end));
                obj.rectangleHandles(end) = [];
            end
        end
    end
end

