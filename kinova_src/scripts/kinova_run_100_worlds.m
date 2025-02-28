%% description
% This script iterates through a list of presaved random worlds and runs
% the ARMOUR planner on them. It then saves information on how well each the
% planner performed in each trial.
%
% Authors: Bohao Zhang (adapted from Patrick Holmes code)
% Created 25 November 2019
% Edited 16 January 2020
% Edited: 02 June 2022 to work with updated UARMTD code
% Edited: 25 September 2022 to work with updated UARMTD code for kinova
% Edited: 10 November 2022 clean up
% Edited: 20 January 2023 clean up

initialize_script_path = matlab.desktop.editor.getActiveFilename;
cd(initialize_script_path(1:end-23));

close all; clear; clc;

%% user parameters

use_robust_input = true;

goal_type = 'configuration'; % pick 'end_effector_location' or 'configuration'
goal_radius = pi/30;
dimension = 3 ;
verbosity = 10;

%%% for planner
traj_type = 'bernstein'; % pick 'orig' or 'bernstein'
allow_replan_errors = true ;
first_iter_pause_flag = false;
use_q_plan_for_cost = false; % otherwise use q_stop (q at final time)
input_constraints_flag = true;

%%% for agent
agent_urdf = 'kinova_without_gripper.urdf';

add_uncertainty_to = 'all'; % choose 'all', 'link', or 'none'
links_with_uncertainty = {}; % if add_uncertainty_to = 'link', specify links here.
uncertain_mass_range = [0.97, 1.03];

agent_move_mode = 'integrator' ; % pick 'direct' or 'integrator'
use_CAD_flag = false;
add_measurement_noise_ = false;
measurement_noise_size_ = 0;

%%% for LLC
LLC_V_max = 1e-2;
use_true_params_for_robust = false;
if_use_mex_controller = true;

%%% for HLP
if_use_RRT = false;
HLP_grow_tree_mode = 'new' ;
plot_waypoint_flag = true ;
plot_waypoint_arm_flag  = true ;
lookahead_distance = 0.1 ;

% plotting
plot_while_running = false ;

% simulation
max_sim_time = 172800 ; % 48 hours
max_sim_iter = 300 ;
stop_threshold = 4 ; % number of failed iterations before exiting

% file handling
save_file_header = 'trial_' ;
% file_location = '../results/random_24pi/' ;
% file_location = '../results/random_turnoffinputconstraints/' ;
file_location = '../results/random_armtd/' ;
if ~exist(file_location, 'dir')
    mkdir(file_location);
end

% world file
world_file_header = 'scene';
world_file_folder = '../saved_worlds/random/';
world_file_location = sprintf('%s*%s*', world_file_folder, world_file_header);
world_file_list = dir(world_file_location);

%% robot params:
robot = importrobot(agent_urdf);
robot.DataFormat = 'col';
robot.Gravity = [0 0 -9.81];
params = load_robot_params(robot, ...
                           'add_uncertainty_to', add_uncertainty_to, ...
                           'links_with_uncertainty', links_with_uncertainty,...
                           'uncertain_mass_range', uncertain_mass_range);
joint_speed_limits = [-1.3963, -1.3963, -1.3963, -1.3963, -1.2218, -1.2218, -1.2218;
                       1.3963,  1.3963,  1.3963,  1.3963,  1.2218,  1.2218,  1.2218]; % matlab doesn't import these from urdf so hard code into class
joint_input_limits = [-56.7, -56.7, -56.7, -56.7, -29.4, -29.4, -29.4;
                       56.7,  56.7,  56.7,  56.7,  29.4,  29.4,  29.4]; % matlab doesn't import these from urdf so hard code into class
transmision_inertia = [8.02999999999999936 11.99620246153036440 9.00254278617515169 11.58064393167063599 8.46650409179141228 8.85370693737424297 8.85873036646853151]; % matlab doesn't import these from urdf so hard code into class
M_min_eigenvalue = 5.095620491878957; % matlab doesn't import these from urdf so hard code into class

use_cuda_flag = true;

%% automated from here
% run loop
for idx = 1:length(world_file_list)
    clc; 
    fprintf("THIS IS WORLD %d\n\n", idx);

    % read world CSV to get start and goal, populate obstacles:
    world_filename = world_file_list(idx).name;
    [start, goal, obstacles] = load_saved_world([world_file_folder world_filename]);
    
    W = kinova_world_static('create_random_obstacles_flag', false, 'goal_radius', goal_radius, 'N_obstacles',length(obstacles),'dimension',dimension,'workspace_goal_check', 0,...
                            'verbose',verbosity, 'start', start, 'goal', goal, 'obstacles', obstacles, 'goal_type', goal_type) ;
    
    % create arm agent
    A = uarmtd_agent(robot, params,...
                     'verbose', verbosity,...
                     'animation_set_axes_flag', 0,... 
                     'animation_set_view_flag', 0,...
                     'move_mode', agent_move_mode,...
                     'use_CAD_flag', use_CAD_flag,...
                     'joint_speed_limits', joint_speed_limits, ...
                     'joint_input_limits', joint_input_limits, ...
                     'add_measurement_noise_', add_measurement_noise_, ...
                     'measurement_noise_size_', measurement_noise_size_,...
                     'M_min_eigenvalue', M_min_eigenvalue, ...
                     'transmision_inertia', transmision_inertia);

    % LLC
    if use_robust_input
        A.LLC = uarmtd_robust_CBF_LLC('verbose', verbosity, ...
                                      'use_true_params_for_robust', use_true_params_for_robust, ...
                                      'V_max', LLC_V_max, ...
                                      'if_use_mex_controller', if_use_mex_controller);
    else
        A.LLC = uarmtd_nominal_passivity_LLC('verbose', verbosity);
    end

    A.LLC.setup(A);
    
    P = uarmtd_planner('verbose', verbosity, ...
                       'first_iter_pause_flag', first_iter_pause_flag, ...
                       'use_q_plan_for_cost', use_q_plan_for_cost, ...
                       'input_constraints_flag', input_constraints_flag, ...
                       'use_robust_input', use_robust_input, ...
                       'traj_type', traj_type, ...
                       'use_cuda', use_cuda_flag) ;

    if if_use_RRT
        P.HLP = arm_end_effector_RRT_star_HLP('plot_waypoint_flag',plot_waypoint_flag,...
                                              'plot_waypoint_arm_flag',plot_waypoint_arm_flag,...
                                              'grow_tree_mode',HLP_grow_tree_mode,...
                                              'buffer',0.1) ;
    end
    
    % set up world using arm
    I = A.get_agent_info ;
    W.setup(I) ;
    W.bounds = [-1 1 -1 1 0 2];
    
    % place arm at starting configuration
    A.state(A.joint_state_indices) = W.start ;
    
    % create simulator
    S = simulator_armtd(A,W,P, ...
                        'verbose', verbosity, ...
                        'stop_threshold', stop_threshold, ...
                        'plot_while_running', plot_while_running,...
                        'allow_replan_errors',allow_replan_errors,...
                        'max_sim_time',max_sim_time,...
                        'max_sim_iterations',max_sim_iter,...
                        'stop_sim_when_ultimate_bound_exceeded', use_robust_input) ; 
    
    % %% plotting
    if plot_while_running
        figure(1) ; clf ; axis equal ; xlim([-1 1]); ylim([-1 1]); zlim([0 2]); grid on; hold on ;

        if dimension == 3
            view(3);
        end
        
        plot(A);
        plot(W);
    end
    
    % run simulation
    summary = S.run() ;
    
    % save summary
    filename = [file_location,'/',save_file_header,world_filename(1:end-4),'.mat'] ;
%     save(filename, 'world_filename', 'summary') ;

    % save all info
    save(filename,'world_filename', 'summary', 'A', 'P', 'W');
end