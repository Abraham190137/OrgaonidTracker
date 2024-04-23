function rotations = process_rot_data_speed(all_correlations, max_speed_deg, max_acc_deg)
    t_max = length(all_correlations); % number of timesteps used.
    num_rot = length(all_correlations{1}); % number of rotations tested in organoid tracking.

    % Cost arrays are indexed based on speed and rotation values 
    % (ie. cost = costs(time, rotation, speed)). However, rotation and
    % speed values are angles (deg) not integer values. To address this, we
    % represent these values as integer steps from 0, where the step is the
    % same used durring the organoid tracker. 

    % Given a rotation or speed (in degrees) the corresponding index is:
    % index = rotation/step_size + offset. 
    step_size = 360/num_rot;
    offset = round(max_speed_deg/step_size) + 1; % + 1 because matlab indexs at 1

    % covert max speed and max accerlartion into the index space:
    max_speed = round(max_speed_deg/step_size);
    max_acc = round(max_acc_deg/step_size);

    % Define the costs matrix. Cost is measured in terms of negative 
    % correlation (minimizing cost => maximizing correlation). The cost
    % matrix defines the total cost of a given state (timestep, rotation,
    % and speed). Total cost is defined as the cost of occuping that state
    % (ie. the negative correlation value) plus the minimum possible summed
    % future cost (ie. what is the minimum cost for all future timesteps if
    % the oganoid is occupying that state).

    % Because rotation wraps (ie. 0 degrees is next to 359 degrees), we
    % extend the cost matrix to include these "neighboring" values. That
    % way, if we say what is the minimum value for angles within 10deg of
    % 5deg, we can automatically include all angles from 355deg to 15 deg,
    % without having to do complex indexing. 
   
    costs = zeros(t_max, num_rot + 2*max_speed, 2*max_speed+1); % initize cost matrix

    % Set costs for the last timestep equal to their correlation values.
    % Since this is the last timestep, there is no future cost.
    costs(end, max_speed+1:num_rot+max_speed, :) = repmat(-all_correlations{end}(1,:), [1, 1, 2*max_speed+1]);
   
    % Copy over the values for the padding on either side of the cost
    % matrix. (ie. put the values for 359 deg before the value for 0
    % degrees, and put the values for 0 degrees after the value for 359.)
    costs(end, 1:max_speed, :) = repmat(-all_correlations{end}(1, end-max_speed+1:end), [1, 1, 2*max_speed+1]);
    costs(end, end-max_speed+1:end, :) = repmat(-all_correlations{end}(1, 1:max_speed), [1, 1, 2*max_speed+1]);

    % Now, we are going to propegate the costs, starting at the second to
    % last timestep. At timestep t, the cost equals -correlation +
    % min(sum(all_future_costs)). We can also write this as cost =
    % -correlatioon + min(possible_costs_for_time_step_t+1), since the cost
    % for the next timestep will include all of those future costs. 

    % Therefore, we must find the minimum possible future cost. At a given
    % rotation and speed, the organoids next rotation will be defined as
    % current_rotation + current_speed. (definition of speed). The next
    % speed for the organoid will be in the range [current_speed -
    % max_acceleration, current_speed + max_accleration]. Therefore, the
    % minum future cost for an organoid at time step t, with rotation r and
    % speed s, will be min(costs(t, r+s, [s-max_acc, s+max_acc])). 
    for t = t_max-1:-1:1
        costs_t = zeros(num_rot, max_speed*2+1); % costs for the current timestep.
        for s = -max_speed:max_speed % loop through all possible speeds
            min_s = max(s-max_acc, -max_speed); % min possible speed for next timestep
            max_s = min(s+max_acc, max_speed); % max possible speed for next timestep
            min_s_idx = min_s + offset; % conver to index form.
            max_s_idx =  max_s + offset;
%             for r = 1:num_rot Old, non-vectorized code
%                 next_r_idx = r + max_speed + s;
%                 min_cost = min(costs(t+1, next_r_idx, min_s_idx:max_s_idx));
%                 costs_t(r, s+max_speed+1) = min_cost - all_correlations{t}(r);
%             end
            rs = 0:(num_rot-1); % all possible rotations
            next_r_idxs = rs + offset + s; % next possible rotations

            % perform minimum operation, doing it vectorized for
            % performance
            min_costs = min(costs(t+1, next_r_idxs, min_s_idx:max_s_idx), [], 3);
            costs_t(rs+1, s+offset) = min_costs - all_correlations{t}(1, rs+1);
        end
        
        % update the matrix of all costs with the current timestep costs,
        % adding the wrapped value to the beginning and end of the costs.
        costs(t, max_speed+1:num_rot+max_speed, :) = costs_t;
        costs(t, 1:max_speed, :) = costs_t(end-max_speed+1:end, :);
        costs(t, end-max_speed+1:end, :) = costs_t(1:max_speed, :);
    end


    % use the costs to plan the rotations.
    % r_{t+1} = r_t + s_t
    % s_{t+1} = [s_t - a, s_t + a]
    rot_idxs = [offset]; % Assume intial rotation is 0
    rot_counts = [0];
    rot_count = 0;

    % We don't have a current speed for the first timestep, so we need to
    %
    [min_cost, argmin] = min(costs(1, offset, :));
    speed = argmin-offset;

    
    for t=1:t_max

        rot_idx = rot_idxs(end) + speed; % r_{t+1}
        
        % set min/max speed to be current speed +- max_acc
        min_s = max(speed-max_acc, -max_speed);
        max_s = min(speed+max_acc, max_speed);

        min_s_idx = min_s + offset; % put into indecies
        max_s_idx = max_s + offset; % put into indecies

        % For next rotation and next speeds, find the minimum cost. 
        [min_cost, speed_idx] = min(costs(t, rot_idx, min_s_idx:max_s_idx), [], 'all');
        speed_idx = speed_idx + min_s_idx - 1; % Adjust for slice indexing
        speed = speed_idx - offset;
        if rot_idx < offset
            rot_idx = rot_idx + num_rot; % if the angle is "negative" shift it.
            rot_count = rot_count + 1;
        end
        if rot_idx >= offset + num_rot
            rot_idx = rot_idx - num_rot;
            rot_count = rot_count - 1;
        end
        rot_idxs(end + 1) = rot_idx;
        rot_counts(end + 1) = rot_count;
    end
    rotations = -(rot_idxs - offset)*(360/num_rot) + 360*rot_counts;
end

