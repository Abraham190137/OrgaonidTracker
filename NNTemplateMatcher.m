classdef NNTemplateMatcher
    properties
        network;
        img_size;
    end
    methods
        function obj = NNTemplateMatcher(template, img_size)
            in_layer = imageInputLayer([img_size(1), img_size(2), 1], "Normalization", "none");
            reshaped_template = reshape(template, [size(template, 1), size(template, 2), 1, size(template, 3)]);
            gpu_template = single(gpuArray(reshaped_template));
            layer = convolution2dLayer([size(template, 1), size(template, 2)], size(template, 3), 'Weights', gpu_template, "Bias", gpuArray.zeros(1, 1, size(template, 3)));
            obj.network = dlnetwork([in_layer, layer]);
            obj.img_size = img_size;
        end
        function correlation_matrix = eval(obj, img)
            gpu_img = single(gpuArray(img));
            net_output = forward(obj.network, dlarray(gpu_img, "SSCB"));
            correlation_matrix = extractdata(net_output);
        end
    end
end