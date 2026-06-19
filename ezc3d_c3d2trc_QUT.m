function [data] = ezc3d_c3d2trc_QUT(filein, filter_freq)
% function ezc3d_c3d2trc_app(file) OR
% function ezc3d_c3d2trc_app(data)
%
% Function to convert data from a C3D file into the TRC and MOT file
% formats for OpenSim
%
% INPUT -   filein - the C3D file path that you wish to load (leave blank to
%               choose from a dialog box) OR
%           
%
% OUTPUT -  data - structure containing the relevant data from the c3dfile
%                  Creates the TRC file and _grf.MOT file for OpenSim
%
%
% Written by Glen Lichtwark (University of Queensland)
% Updated September 2012

import org.opensim.modeling.*;
order = [2 3 1];
%% set the filter freq - note this is just take higher frequency noise out and should not be set much below 15 Hz

if nargin < 2
    filter_freq = 15;
end

%% load the c3d file
if nargin < 1
    [fname, pname] = uigetfile('*.c3d', 'Select C3D file');
else
    if isempty(fileparts(filein))
        pname = cd;
        if ispc
            pname = [pname '\'];
        else pname = [pname '/'];
        end
        fname = filein;
    else
        [pname, name, ext] = fileparts(filein);
        pname = [pname '\'];
        fname = [name ext];
    end   
end

% load the c3d file
[data] = ezc3dRead([pname fname]);

%%
% if the mass, height and name aren't present then presribe - it is
% preferrable to have these defined in the data structure before running
% this function - btk_loadc3d should try and do this for vicon data
if ~isfield(data,'Mass')
    data.Mass = 75;
end

if ~isfield(data,'Height')
    data.Height = 1750;
end

if ~isfield(data,'Name')
    data.Name = 'NoName';
end



%%
% we need to reorder the lab coordinate system to match that of the OpenSim
% system --> SKIP THIS STEP IF LAB COORDINATE SYSTEM IS SAME AS MODEL
% SYSTEM
markers = fieldnames(data.marker_data.Markers); % get markers names
nmarkers = length(fieldnames(data.marker_data.Markers)); % number of markers

if strcmp(data.marker_data.Info.Units,'mm')
    p_sc = 1000;
    data.marker_data.Info.Units = 'm';
else p_sc = 1;
end

% go through each marker field and re-order from X Y Z to Y Z X
% then reflect axis by making Y and X negative
for i = 1:nmarkers
    data.marker_data.Markers.(markers{i}) = data.marker_data.Markers.(markers{i})/p_sc;
    data.marker_data.Markers.(markers{i}) = data.marker_data.Markers.(markers{i})(:,order);
    data.marker_data.Markers.(markers{i})(:,1) = data.marker_data.Markers.(markers{i})(:,1)*-1;
    data.marker_data.Markers.(markers{i})(:,3) = data.marker_data.Markers.(markers{i})(:,3)*-1;
end

%% do some gap filling and filtering of marker data
data = markers_filtint( data , filter_freq, 0.1); 

%% also convert force plate cop if it is present in data and re-order axes
if isfield(data,'fp_data')
    %  reorder the GRF and moments if necessary (need to
    %  make y axis negative when it becomes z axis)
    for i = 1:length(data.fp_data.GRF_data)
        data.fp_data.GRF_data(i).P =  data.fp_data.GRF_data(i).P(:,order)/p_sc;
        data.fp_data.GRF_data(i).P(:,1) =  data.fp_data.GRF_data(i).P(:,1)*-1;
        data.fp_data.GRF_data(i).P(:,3) =  data.fp_data.GRF_data(i).P(:,3)*-1;
        data.fp_data.GRF_data(i).F =  data.fp_data.GRF_data(i).F(:,order);
        data.fp_data.GRF_data(i).F(:,1) =  data.fp_data.GRF_data(i).F(:,1)*-1;
        data.fp_data.GRF_data(i).F(:,3) =  data.fp_data.GRF_data(i).F(:,3)*-1;
        data.fp_data.GRF_data(i).M =  data.fp_data.GRF_data(i).M(:,order)/p_sc;
        data.fp_data.GRF_data(i).M(:,1) =  data.fp_data.GRF_data(i).M(:,1)*-1;
        data.fp_data.GRF_data(i).M(:,3) =  data.fp_data.GRF_data(i).M(:,3)*-1;
    end
end

%%
% now we need to make the headers for the column headings for the TRC file
% which are made up of the marker names and the XYZ for each marker

% define the start and end frame for analysis as first and last frame unless
% this has already been done to change the analysed frames
if ~isfield(data,'Start_Frame')
    data.Start_Frame = 1;
    data.End_Frame = data.marker_data.Info.NumFrames;
end

% define number of rows for output files
nrows = data.End_Frame-data.Start_Frame+1;
nframe = 1:nrows;

% first initialise the header with a column for the Frame # and the Time
% also initialise the format for the columns of data to be written to file
dataheader1 = 'Frame#\tTime\t';
dataheader2 = '\t\t';
format_text = '%i\t%2.4f\t';
% initialise the matrix that contains the data as a frame number and time row
data_out = [nframe; data.marker_data.Time'];

% now loop through each maker name and make marker name with 3 tabs for the
% first line and the X Y Z columns with the marker numnber on the second
% line all separated by tab delimeters
% each of the data columns (3 per marker) will be in floating format with a
% tab delimiter - also add to the data matrix
for i = 1:nmarkers
    dataheader1 = [dataheader1 markers{i} '\t\t\t'];
    dataheader2 = [dataheader2 'X' num2str(i) '\t' 'Y' num2str(i) '\t'...
        'Z' num2str(i) '\t'];
    format_text = [format_text '%f\t%f\t%f\t'];
    % add 3 rows of data for the X Y Z coordinates of the current marker
    % first check for NaN's and fill with a linear interpolant - warn the
    % user of the gaps
    clear m
    m = find(isnan(data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),1))>0);
    if ~isempty(m)
        clear t d
        disp(['Warning -' markers{i} ' data missing in parts. Frames ' num2str(m(1)) '-'  num2str(m(end))])
        t = data.marker_data.Time';
        t(m) = [];
        d = data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:);
        d(m,:) = [];
        data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:) = interp1(t,d,data.marker_data.Time','linear','extrap');
    end
    data_out = [data_out; data.marker_data.Markers.(markers{i})((data.Start_Frame:data.End_Frame),:)'];
end
dataheader1 = [dataheader1 '\n'];
dataheader2 = [dataheader2 '\n'];
format_text = [format_text '\n'];

disp('Writing trc file...')

%Output marker data to an OpenSim TRC file

newfilename = strrep(fname,'c3d','trc');

if isempty(dir([pname 'Data']))
    mkdir(pname,'Data');
end

data.TRC_Filename = [pname 'Data\' newfilename];

%open the file
fid_1 = fopen(data.TRC_Filename,'w');

% first write the header data
fprintf(fid_1,'PathFileType\t4\t(X/Y/Z)\t %s\n',newfilename);
fprintf(fid_1,'DataRate\tCameraRate\tNumFrames\tNumMarkers\tUnits\tOrigDataRate\tOrigDataStartFrame\tOrigNumFrames\n');
fprintf(fid_1,'%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\n', data.marker_data.Info.frequency, data.marker_data.Info.frequency, nrows, nmarkers, data.marker_data.Info.Units, data.marker_data.Info.frequency,data.Start_Frame,data.End_Frame);
fprintf(fid_1, dataheader1);
fprintf(fid_1, dataheader2);

% then write the output marker data
fprintf(fid_1, format_text,data_out);

% close the file
fclose(fid_1);

disp('Done.')


%%
% Write motion file containing GRFs

force_threshold = 30;
foot_distance = 0.25;

disp('Writing grf.mot file...')

if isfield(data,'fp_data')

    fp_time = 1/data.fp_data.Info(1).frequency:1/data.fp_data.Info(1).frequency:length(data.fp_data.GRF_data(1).F)/1/data.fp_data.Info(1).frequency;

    % initialise force data matrix with the time array and column header
    force_data_out = fp_time';
    force_header = 'time\t';
    force_format = '%20.6f\t';

    EXL = ExternalLoads();

    % if the assign_forces function has not been run then just make a force
    % file that contains the data from each force plate
    if isfield(data.fp_data,'GRF_data')

        for i = 1:length(data.fp_data.GRF_data)

            EXF = ExternalForce();

            FF = data.fp_data.Info(1).frequency / data.marker_data.Info.frequency;
            force_thresh_idx = data.fp_data.GRF_data(i).F(1:FF:end,2)>force_threshold;

            % check to see if this force plate exceed threshold for more
            % than 4 frames and write to GRF MOT file if this is the case
            if sum(force_thresh_idx) >= 2

                % set applied force to none
                data.force_assign{i} = 'none';
                applied_body = 'none';

                % determine which foot is in contact with the plate so
                % the force can be assigned to that plate

                % first calculate the point between calcaneus and MTP
                % markers (should be close to the COP)
                ML = (data.marker_data.Markers.LCALC+data.marker_data.Markers.LMTP)/2;
                MR = (data.marker_data.Markers.RCALC+data.marker_data.Markers.RMTP)/2;
                
                % next calculate the distance between these points and
                % COP when the force is above threshold
                DLxy = abs(ML(force_thresh_idx,[1 3]) - data.fp_data.GRF_data(i).P(find(force_thresh_idx)*FF,[1 3]));
                DL = nanmean(sqrt(DLxy(:,1).^2 + DLxy(:,2).^2));

                DRxy = abs(MR(force_thresh_idx,[1 3]) - data.fp_data.GRF_data(i).P(find(force_thresh_idx)*FF,[1 3]));
                DR = nanmean(sqrt(DRxy(:,1).^2 + DRxy(:,2).^2));

                if (DL < DR) && DL < foot_distance
                    data.force_assign{i} = 'left';
                    applied_body = 'calcn_l';
                end

                if (DR < DL) && DR < foot_distance
                    data.force_assign{i} = 'right';
                    applied_body = 'calcn_r';
                end

                if ~strcmp(applied_body,'none')

                    % add the force, COP and moment data for current plate to the force matrix
                    force_data_out = [force_data_out data.fp_data.GRF_data(i).F data.fp_data.GRF_data(i).P data.fp_data.GRF_data(i).M];
                    % define the header and formats
                    force_header = [force_header 'ground_force_' num2str(i)  '_vx\t' 'ground_force_' num2str(i)  '_vy\t' 'ground_force_' num2str(i)  '_vz\t' ...
                        'ground_force_' num2str(i)  '_px\t' 'ground_force_' num2str(i)  '_py\t' 'ground_force_' num2str(i)  '_pz\t' ...
                        'ground_torque_' num2str(i)  '_x\t' 'ground_torque_' num2str(i)  '_y\t' 'ground_torque_' num2str(i)  '_z\t'];
                    force_format = [force_format '%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t%20.6f\t'];

                    EXF.setName(['force_' num2str(i)])
                    EXF.set_applied_to_body(applied_body);
                    EXF.set_force_expressed_in_body('ground');
                    EXF.set_point_expressed_in_body('ground');
                    EXF.set_force_identifier(['ground_force_' num2str(i)  '_v']);
                    EXF.set_point_identifier(['ground_force_' num2str(i)  '_p']);
                    EXF.set_torque_identifier(['ground_torque_' num2str(i)]);
                    EXL.cloneAndAppend(EXF);

                end

            else
                data.force_assign{i} = 'none';
            end

        end

        force_header = [force_header(1:end-2) '\n'];
        force_format = [force_format(1:end-2) '\n'];

        % assign a value of zero to any NaNs
        force_data_out(logical(isnan(force_data_out))) = 0;

    end

    newfilename = [fname(1:end-4) '_grf.mot'];
    xmlfilename = [fname(1:end-4) '_extloads.xml'];

    data.GRF_Filename = [pname 'Data\' newfilename];
    data.EXL_Filename = [pname 'InverseDynamics\' xmlfilename];
    mkdir([pname 'InverseDynamics'])  

    EXL.setDataFileName(data.GRF_Filename)

    fid_2 = fopen(data.GRF_Filename,'w');

    % write the header information
    fprintf(fid_2,'%s\n',newfilename);
    fprintf(fid_2,'version=1\n');
    fprintf(fid_2,'nRows=%d\n', length(fp_time));  % total # of datacolumns
    fprintf(fid_2,'nColumns %d\n',size(force_data_out,2)); % number of datarows
    fprintf(fid_2,'inDegrees=yes\n'); % range of time data
    fprintf(fid_2,'endheader\n');
    fprintf(fid_2,force_header);

    % write the data
    fprintf(fid_2,force_format,force_data_out');

    fclose(fid_2);

    EXL.print(data.EXL_Filename); 

    clear EXF EXL

    disp('Done.')

else disp('No force plate information available.')
end
