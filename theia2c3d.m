function data = theia2c3d(fname, fileout, TRCoutput, filter_freq, crop, show_animation)

% function data = theia2trc_crop(fname, fileout, TRCoutput, crop, show_animation)
%
% Function to load data from a Theia generated C3D file and extract the
% data to virtual markers for use in Opensim, writing the the XYZ positions
% of markers back to C3D file and TRC files, whilst also ensuring data is
% cropped so that any periods where there are no markers before or after
% the period when all markers become visible is cropped out.
%
% INPUT -   fname = string equivalent to [pathname filename];
%           fileout = name of file to be output (defaults to the same name with '_Theia' at end)
%           TRCoutput = boolean (true/false or 0/1) to write TRC and force
%                       files using same names as fileout
%           crop = boolean (true/false) whether the crop analysis time to
%                 the time when the participant is fully in view (default FALSE)
%           show_animation = boolean (true/false) to show animation or not (default FALSE)
%
% OUTPUT -  data = data structure containing all of the extracted data from
%                   the c3d file
%
% AUTHORS 
% Glen Lichtwark
% Queensland University of Technology
% 
% Logan Wade
% Univeristy of New South Wales
% 
% Last Updated: June 2026

if nargin < 6
    show_animation = false;
end

if nargin < 5
    crop = false;
end

if nargin < 4
    filter_freq = [];
end

if nargin < 3
    TRCoutput = false;
end

if nargin < 2
    fileout = [];
end

if nargin < 1
    %% load the c3d file into structure
    [filename, pathname, ~] = uigetfile('*.c3d', 'Select C3D file to process');
    fname = [pathname filename];
end

%% load file
c3d = ezc3dRead(fname);
warning off;

%% define markers names for joints based on body representations
joint_marker_list = [{'pelvis_4X4'},{'PELVIS1'};...
    {'l_thigh_4X4'},{'LHIP'}';...
    {'l_shank_4X4'},{'LKNEE'}';...
    {'l_foot_4X4'},{'LANK'}';...
    {'l_toes_4X4'},{'LMTP'}';...
    {'r_thigh_4X4'},{'RHIP'}';...
    {'r_shank_4X4'},{'RKNEE'}';...
    {'r_foot_4X4'},{'RANK'}';...
    {'r_toes_4X4'},{'RMTP'}';...
    {'torso_4X4'},{'TORSO'}';...
    {'l_uarm_4X4'},{'LSHO'}';...
    {'l_larm_4X4'},{'LELB'}';...
    {'l_hand_4X4'},{'LWRIST'}';...
    {'r_uarm_4X4'},{'RSHO'}';...
    {'r_larm_4X4'},{'RELB'}';...
    {'r_hand_4X4'},{'RWRIST'};...
    {'head_4X4'},{'CVJ'}];


%% Loop through the individual rotations
for i = 1:size(c3d.data.rotations,3)
    % Extract segment name (remove trailing "_4X4")
    segment_name = c3d.parameters.ROTATION.LABELS.DATA{i}(1:end-4);

    % Store the 4x4xM transformation matrix for this segment
    data.segments.(segment_name) = squeeze(c3d.data.rotations(:,:,i,:));

    % Check if the segment is in the joint_marker_list
    idx = find(strcmp(c3d.parameters.ROTATION.LABELS.DATA{i}, joint_marker_list(:,1)), 1);

    if ~isempty(idx)
        % Assign translation coordinates to corresponding marker
        marker_name = joint_marker_list{idx, 2};
        data.markers.(marker_name) = squeeze(c3d.data.rotations(1:3,4,i,:))';
    else
        % Optional: display missing mapping
        % fprintf('No marker mapping for segment: %s\n', c3d.parameters.ROTATION.LABELS.DATA{i});
    end
end



%% calculate some of the relative segment angles and positions
joint_coordinates = [{"pelvis"},{"worldbody"},{"pelvis"};...
    {"hip_r"},{"pelvis"},{"r_thigh"};...
    {"knee_r"},{"r_thigh"},{"r_shank"};...
    {"ankle_r"},{"r_shank"},{"r_foot"};...
    {"mtp_r"},{"r_foot"},{"r_toes"};...
    {"hip_l"},{"pelvis"},{"l_thigh"};...
    {"knee_l"},{"r_thigh"},{"l_shank"};...
    {"ankle_l"},{"r_shank"},{"l_foot"};...
    {"mtp_l"},{"r_foot"},{"l_toes"};...
    {"torso"},{"worldbody"},{"torso"};...
    {"shoulder_r"},{"torso"},{"r_uarm"};...
    {"elbow_r"},{"r_uarm"},{"r_larm"};...
    {"wrist_r"},{"r_larm"},{"r_hand"};...
    {"shoulder_r"},{"torso"},{"r_uarm"};...
    {"elbow_r"},{"r_uarm"},{"r_larm"};...
    {"wrist_r"},{"r_larm"},{"r_hand"};...
    {"head"},{"worldbody"},{"head"}];

for f = 1:length(joint_coordinates)
    T1 = data.segments.(joint_coordinates{f,2});
    T2 = data.segments.(joint_coordinates{f,3});
    [relativePosition, relativeEulerAngles] = relativeTransform(T1, T2);
    data.joints.(joint_coordinates{f,1}).Position = relativePosition;
    data.joints.(joint_coordinates{f,1}).Orientation = rad2deg(relativeEulerAngles);
end

% Detect units from the C3D file if available
if isfield(c3d.parameters.POINT, 'UNITS')
    units = lower(c3d.parameters.POINT.UNITS.DATA{:});
else
    units = 'mm'; % fallback
end

%% now set the additional markers which are those that are attached to other parts of segments
% start with heel
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_foot'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left heel
P_local = [c3d.parameters.THEIA3D.LHEEL_POS.DATA*1000; 1];
data.markers.LCALC = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_foot'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right heel segment
P_local = [c3d.parameters.THEIA3D.RHEEL_POS.DATA*1000; 1];
data.markers.RCALC = local2global(T,P_local,units);

%  toes
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_toes'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left toe
P_local = [0; str2double(c3d.parameters.THEIA3D.LTOE_LENGTH.DATA{:})*1000; 0; 1];
data.markers.LTOE = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_toes'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right toe
P_local = [0; str2double(c3d.parameters.THEIA3D.RTOE_LENGTH.DATA{:})*1000; 0; 1];
data.markers.RTOE = local2global(T,P_local,units);

% hands
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_hand'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left hand
P_local = [0; 0; -str2double(c3d.parameters.THEIA3D.LHAND_LENGTH.DATA{:})*1000; 1];
data.markers.LHAND = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_hand'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right hand
P_local = [0; 0; -str2double(c3d.parameters.THEIA3D.RHAND_LENGTH.DATA{:})*1000; 1];
data.markers.RHAND = local2global(T,P_local,units);

% head
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'head'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right hand
P_local = [c3d.parameters.THEIA3D.HEADCENTER_POS.DATA*1000; 1];
data.markers.HEAD_CENTRE = local2global(T,P_local,units);

% torso
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'torso'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right hand
P_local = [0; 0; -str2double(c3d.parameters.THEIA3D.THORAX_LENGTH.DATA{:})*1000; 1];
data.markers.TORSO_LOW = local2global(T,P_local,units);

%% now add long axis rotational markers on segments
%thigh
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_thigh'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left thigh segment
P_local = [-75 0 -200 1]';
data.markers.LTHI = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_thigh'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right thigh segment
P_local = [75 0 -200 1]';
data.markers.RTHI = local2global(T,P_local,units);

%shank
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_shank'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left shank segment
P_local = [-65 0 -200 1]';
data.markers.LSHA = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_shank'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right shank segment
P_local = [65 0 -200 1]';
data.markers.RSHA = local2global(T,P_local,units);

%rearfoot
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_foot'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left foot segment
P_local = [-40 -10 -50 1]';
data.markers.L_LCALC = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_foot'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right foot segment
P_local = [40 -10 -50 1]';
data.markers.R_LCALC = local2global(T,P_local,units);

%upper arm
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_uarm'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left upper arm segment
P_local = [0 40 -140 1]';
data.markers.LUA = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_uarm'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right upper arm segment
P_local = [0 40 -140 1]';
data.markers.RUA = local2global(T,P_local,units);

%forearm
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'l_larm'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left upper arm segment
P_local = [-40 0 -120 1]';
data.markers.LFRM = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'r_larm'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right upper arm segment
P_local = [40 0 -120 1]';
data.markers.RFRM = local2global(T,P_local,units);

%head
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'head'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left head
P_local = [-75 0 125 1]';
data.markers.HEAD_L = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'head'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right head
P_local = [75 0 125 1]';
data.markers.HEAD_R = local2global(T,P_local,units);

%torso
idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'torso'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % left torso
P_local = [-150 0 0 1]';
data.markers.TORSO_L = local2global(T,P_local,units);

idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'torso'));
T = squeeze(c3d.data.rotations(:,:,idx,:)); % right torso
P_local = [150 0 0 1]';
data.markers.TORSO_R = local2global(T,P_local,units);

% idx = find(contains(c3d.parameters.ROTATION.LABELS.DATA, 'torso'));
% T = squeeze(c3d.data.rotations(:,:,idx,:)); % low torso
% P_local = [0 76 -150 1]';
% if strcmp(units, 'm') || strcmp(units, 'meter') || strcmp(units, 'meters')
%     P_local(1:3) = P_local(1:3) / 1000; % adjust if data is in meters
% end
% data.markers.TORSO_LOW = local2global(T,P_local,units);

% pelvis2 marker is now between the hip markers - calculate as average XYZ
data.markers.PELVIS2 = [nanmean([data.markers.LHIP(:,1) data.markers.RHIP(:,1)],2) ...
    nanmean([data.markers.LHIP(:,2) data.markers.RHIP(:,2)],2) ...
    nanmean([data.markers.LHIP(:,3) data.markers.RHIP(:,3)],2)];

%% determine when all of the segment rotations are available so we can define a start and end frame for data structure
DD = (squeeze(c3d.data.rotations(1,1,2:end,:)))'; % note that the world body isn't used

% set frame column and time column for TRC file
data.Start_Frame = c3d.header.rotations.firstFrame;
data.End_Frame = c3d.header.rotations.lastFrame;

% set the start and end frames depending if this needs to be cropped when
% there is periods at start or end when the person is out of view.
if crop
    inView = find(sum(~isnan(DD),2)==18); % there should be 18 visible segments
    inView = inView(1):1:inView(end); % make a block in case markers go out of view so the time works out

    data.Start_Frame_Theia = inView(1);
    data.End_Frame_Theia = inView(end);
else
    data.Start_Frame_Theia = data.Start_Frame;
    data.End_Frame_Theia = data.End_Frame;
end

data.nframe = (data.Start_Frame:1:data.End_Frame)';
data.time = (data.nframe/c3d.header.rotations.frameRate);
data.FrameRate = c3d.header.rotations.frameRate;

% extract body mass if exists (vicon)
if isfield(c3d.parameters,'PROCESSING')
    if isfield(c3d.parameters.PROCESSING,'Bodymass')
        data.bodymass = c3d.parameters.PROCESSING.Bodymass.DATA;
    end
end

%% write marker data to C3D file
% get names of markers
data.marker_names = fieldnames(data.markers);
if ~isempty(filter_freq)
    data = filterTheiaMarkers(data, filter_freq);
end

% set the size of the number of points used and the labels of the new
% virtual markers
c3d.header.points.size = length(data.marker_names);
c3d.parameters.POINT.USED.DATA = length(data.marker_names);
c3d.parameters.POINT.LABELS.DATA = data.marker_names;

% create a new 3D matrix for each marker coordinate (N x 3) and frame
m_points = [];
for M = 1:length(data.marker_names)
    m_points(M,:,:) = data.markers.(data.marker_names{M});
end

% change order to match requirements of C3D point data
c3d.data.points = permute(m_points,[3,1,2]);

% Write the C3D
if isempty(fileout)
    [folder, base, ~] = fileparts(fname);
    fileout = [base,  '_Theia.c3d'];
end

if isfield(c3d.data,'meta_points')
    c3d.data = rmfield(c3d.data,'meta_points');
end

%c3d = crop_ezc3d(c3d, data.Start_Frame_Theia, data.End_Frame_Theia);

ezc3dWrite(fileout, c3d);

%% write the TRC and force file if requested
if TRCoutput
    %[data.TRC_Filename, data.GRF_Filename] = writeTRC(fileout); %Broken
    %and not using GRF, so fix later
    data.TRC_Filename = writeTRCfromTheia(data, fname, fileout, c3d);
end

%% animate the markers
if show_animation

    % loop through all markers and set up X Y and Z positions
    % only animate when all markers are in view
    for i = 1:length(data.marker_names)

        Markers.X(:,i) = data.markers.(data.marker_names{i})(inView,1);
        Markers.Y(:,i) = data.markers.(data.marker_names{i})(inView,2);
        Markers.Z(:,i) = data.markers.(data.marker_names{i})(inView,3);
    end

    % plot the markers for the first frame (clearing axis first)
    figure(1); cla
    H = plot3(Markers.X(1,:), Markers.Y(1,:), Markers.Z(1,:), 'ko');
    axis equal

    % update marker positions for each frame in loop
    for i = 2:length(data.nframe)
        H.XData = Markers.X(i,:);
        H.YData = Markers.Y(i,:);
        H.ZData = Markers.Z(i,:);
        drawnow
    end

    close(1)
end

%% function to write TRC file if requested
    function [markersFilename, forcesFilename] = writeTRC(c3dfilename)
        c3d = osimC3D(c3dfilename,1);

        % Rotate the data
        c3d.rotateData('x',-90)

        % Convert COP (mm to m) and Moments (Nmm to Nm) if needed
        if strcmp(units, 'mm')
            c3d.convertMillimeters2Meters();
        end

        % Write the marker and force data to file
        % Define output file names
        basename = strtok(c3dfilename,'.');
        markersFilename = strcat(basename,'.trc');
        forcesFilename = strcat(basename,'_forces.mot');

        % Write marker data to trc file.
        c3d.writeTRC(markersFilename);

        % if there are any forces then write these to the file as well
        if c3d.getNumForces > 0
            % Write force data to mot file.
            c3d.writeMOT(forcesFilename);
        end
    end


%% function to tranfrom from local to global coordinate system
    function coord = local2global(T,P_local,units)
        % if units are specified, assume they are in mm
        if nargin < 3
            units = 'mm';
        end
        % adjust P_local to meters by dividing by 1000 if units are meters
        if strcmp(units, 'm') || strcmp(units, 'meter') || strcmp(units, 'meters')
            P_local(1:3) = P_local(1:3) / 1000; % adjust if data is in meters
        end
        for i = 1:size(T,3)
            % determine global position of P_local
            P_global(i,:) = (squeeze(T(:,:,i)) * P_local)';
        end
        % output virtual marker coordinate
        coord = P_global(:,1:3);
    end


%% function to calculate euler angle and position of segments relative to each other
    function [relativePosition, relativeEulerAngles] = relativeTransform(T1, T2)

        % initialise output arrays
        relativePosition = zeros(size(T1,3),3);
        relativeEulerAngles = zeros(size(T1,3),3);

        for i = 1:size(T1,3)
            % Calculate the relative transformation matrix
            T_relative = inv(T1(:,:,i)) * T2(:,:,i);

            % Extract the relative position
            relativePosition(i,:) = T_relative(1:3, 4)';

            % Extract the relative rotation matrix
            R_relative = T_relative(1:3, 1:3);

            % Convert the relative rotation matrix to Euler angles
            relativeEulerAngles(i,:) = rotm2eul(R_relative,"XYZ"); %LW CHANGED FROM YXZ
        end
    end


end

function newfilename = writeTRCfromTheia(data, fname, fileout, c3d)
%WRITETRCFROMTHEIA Write a TRC file from Theia virtual marker data.
%
% Inputs:
%   data    - structure containing data.markers, data.marker_names, data.time
%   fname   - original input C3D file path
%   fileout - output C3D filename used earlier in the pipeline
%   c3d     - original ezc3d structure (used for frame rate and units)

    if nargin < 4
        error('writeTRCfromTheia requires data, fname, fileout, and c3d.');
    end

    % Determine output folder and filename stem
    % Save TRC next to the converted _Theia.c3d file.
    if isempty(fileout)
        [outDir, base, ~] = fileparts(fname);
        outStem = [base '_Theia'];
    else
        [outDir, outStem, ~] = fileparts(fileout);
    
        % If fileout was provided without a folder, save beside original C3D
        if isempty(outDir)
            [outDir, ~, ~] = fileparts(fname);
        end
    end
    
    newfilename = fullfile(outDir, [outStem '.trc']);

    % Build TRC table
    dataheader1 = 'Frame#\tTime\t';
    dataheader2 = '\t\t';
    format_text = '%i\t%2.4f\t';

    data_out = [data.nframe data.time];

    for i = 1:length(data.marker_names)
        markerName = data.marker_names{i};

        dataheader1 = [dataheader1 markerName '\t\t\t'];
        dataheader2 = [dataheader2 'X' num2str(i) '\t' 'Y' num2str(i) '\t' 'Z' num2str(i) '\t'];
        format_text = [format_text '%f\t%f\t%f\t'];

        % Fill gaps if needed
        m = find(isnan(data.markers.(markerName)(:,1)));
        if ~isempty(m)
            disp(['Warning - ' markerName ' data missing in parts. Frames ' num2str(m')])

            t = data.time;
            d = data.markers.(markerName);

            t(m) = [];
            d(m,:) = [];

            data.markers.(markerName) = interp1(t, d, data.time, 'linear', 'extrap');
        end

        % Swap Y and Z, then flip Z to match your current convention
        data_cols = data.markers.(markerName)(:, [1 3 2]);
        data_cols(:,3) = data_cols(:,3) * -1;

        data_out = [data_out data_cols];
    end

    dataheader1 = [dataheader1 '\n'];
    dataheader2 = [dataheader2 '\n'];
    format_text = [format_text '\n'];

    % Write file
    fid_1 = fopen(newfilename, 'w');
    if fid_1 < 0
        error('Could not open TRC file for writing: %s', newfilename);
    end

    fprintf(fid_1, 'PathFileType\t4\t(X/Y/Z)\t %s\n', newfilename);
    fprintf(fid_1, 'DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames\n');
    fprintf(fid_1, '%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\n', ...
        c3d.header.rotations.frameRate, ...
        c3d.header.rotations.frameRate, ...
        length(data.nframe), ...
        length(data.marker_names), ...
        c3d.parameters.POINT.UNITS.DATA{:}, ...
        c3d.header.rotations.frameRate, ...
        data.Start_Frame, ...
        data.End_Frame);

    fprintf(fid_1, dataheader1);
    fprintf(fid_1, dataheader2);
    fprintf(fid_1, format_text, data_out');

    fclose(fid_1);

    data.TRC_Filename = newfilename;
    disp(['TRC file saved - ' newfilename])
end

function data = filterTheiaMarkers(data, filter_freq)
%FILTERTHEIAMARKERS Low-pass filter Theia virtual marker trajectories.
%
% Filtering is only applied if filter_freq is supplied to theia2c3d.
% If filter_freq is empty, this function should not be called.

    if isempty(filter_freq)
        return
    end

    if ~isfield(data, 'FrameRate') || isempty(data.FrameRate)
        error('Cannot filter markers because data.FrameRate is missing.')
    end

    fs = data.FrameRate;
    fc = filter_freq;

    if fc <= 0
        error('filter_freq must be greater than zero.')
    end

    if fc >= fs / 2
        error('filter_freq must be less than the Nyquist frequency: %.2f Hz.', fs / 2)
    end

    % 4th-order low-pass Butterworth filter
    [b, a] = butter(4, fc / (fs / 2), 'low');

    for i = 1:numel(data.marker_names)
        markerName = data.marker_names{i};
        markerData = data.markers.(markerName);

        % Fill gaps before filtering
        for col = 1:3
            x = markerData(:, col);
            bad = isnan(x);

            if all(bad)
                warning('Marker %s column %d is entirely NaN. Skipping.', markerName, col)
                continue
            end

            if any(bad)
                t = data.time;
                x(bad) = interp1(t(~bad), x(~bad), t(bad), 'linear', 'extrap');
            end

            markerData(:, col) = filtfilt(b, a, x);
        end

        data.markers.(markerName) = markerData;
    end
end