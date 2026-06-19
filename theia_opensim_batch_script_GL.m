%% script to process theia C3D file to opensim outputs
clear
import org.opensim.modeling.*

%% define the generic model and specific parameters relevant
%  these parameters can be changed

% participant mass 
mass = 84.4;
% filter frequency (low pass)
filter_freq = 10;
% participant code (model name)
participant_code = 'P01'; 

% Generic OpenSim model used for scaling
generic_model = 'C:\Users\z3550257\Dropbox\University\GitHubClones\TheiaOpensim\TheiaModel\Rajagopal2015_Theia3D_V5.osim';

% Scale Tool XML setup file
scale_setup = 'C:\Users\z3550257\Dropbox\University\GitHubClones\TheiaOpensim\TheiaModel\scale_setup_v5.xml';

% Inverse Kinematics XML setup file
ik_setup = 'C:\Users\z3550257\Dropbox\University\GitHubClones\TheiaOpensim\TheiaModel\ik_setup_v5.xml';

%% loop through all files and process
[filenames, pathname, ~] = uigetfile('*.c3d', 'Select C3D files to process', 'MultiSelect','on');

if ~iscell(filenames)
    filenames = {filenames};
end

for F = 1:length(filenames)
    %% load the c3d file into structure
    % [filename, pathname, ~] = uigetfile('*.c3d', 'Select C3D file to process');

    fpath = [pathname filenames{F}];
    theia_fpath = [fpath(1:end-4) '_Theia.c3d'];

    disp(['Created Theia C3D file - ' theia_fpath])

    % turn the theia rotations into virtual markers and save into a new C3D
    % file - this function also crops to periods when all segments are visible
    % (use theia2c3d_2025.m if you don't want this)
    c3d_data = theia2c3d(fpath,theia_fpath,false,false,false);

    %% run the processing to create the TRC files and GRF data if relevant
    data = ezc3d_c3d2trc_QUT(theia_fpath,filter_freq);

    %% scale model

    disp('Running Scale Tool...')
    % get the name of the file and model
    [~,name,~] = fileparts(theia_fpath);
    data.name = name;
    [~,mod_name,~] = fileparts(generic_model);

    % load scale tool and associated tools
    ScTool = ScaleTool(scale_setup);
    ScTool.setName(participant_code)
    ScTool.setPathToSubject('');
    GMM = ScTool.getGenericModelMaker;
    MS = ScTool.getModelScaler;
    MP = ScTool.getMarkerPlacer;

    %add model to generic setup file
    GMM.setModelFileName(generic_model);
    GMM.setName(mod_name);

    %add output files
    MS.setOutputScaleFileName([pathname 'ModelScaling\' name '_scaleSetApplied' '.xml']);
    MS.setOutputModelFileName([pathname 'ModelScaling\' name '_Scaled' '.osim']);
    MP.setOutputMotionFileName([pathname 'ModelScaling\' name '_static' '.mot']);
    MP.setOutputModelFileName([pathname 'ModelScaling\' name '_Scaled' '.osim']);
    MP.setOutputMarkerFileName([pathname 'ModelScaling\' name '_markersScaled' '.xml']);
    data.ScaledModel = [pathname 'ModelScaling\' name '_Scaled' '.osim'];

    % setup the specific file parameters
    % note that the name and path of the file is in the data_structure for static file
    MS.setMarkerFileName(data.TRC_Filename);
    MP.setMarkerFileName(data.TRC_Filename);

    %add time range
    InitialTime = data.marker_data.Time(3);
    FinalTime = data.marker_data.Time(50);
    time_range = ArrayDouble;
    time_range.append(InitialTime);
    time_range.append(FinalTime);
    MS.setTimeRange(time_range);
    MP.setTimeRange(time_range);

    %add mass
    ScTool.setSubjectMass(mass);

    %create the ModelScaling directory above c3d directory if it
    %doesn't exist
    if isempty(dir([pathname 'ModelScaling']))
        mkdir(pathname,'ModelScaling');
    end

    %write new .xml file in setup folder
    ScTool.print([pathname 'ModelScaling\' participant_code '_setupScale.xml']);

    % run scaling tool;
    ScTool.run();

    disp('Done.')

    %% perform inverse kinematics analysis
    disp('Running Inverse Kinematics Tool...')

    ikTool = InverseKinematicsTool(ik_setup);

    model = Model(data.ScaledModel);

    % Tell Tool to use the loaded model
    ikTool.setModel(model);

    % define the file names

    marker_file = data.TRC_Filename;
    [~,fname,~] = fileparts(marker_file);
    mot_file = [pathname 'InverseKinematics\' fname '.mot'];
    data.MOT_Filename = mot_file;
    setup_file = [pathname 'InverseKinematics\' fname '_iksetup.xml'];

    %create the InverseKinematics directory above c3d directory if it
    %doesn't exist
    if isempty(dir([pathname 'InverseKinematics']))
        mkdir(pathname,'InverseKinematics');
    end

    % Get trc data to determine time range
    markerData = MarkerData(marker_file);

    % Get initial and intial time
    initial_time = markerData.getStartFrameTime();
    final_time = markerData.getLastFrameTime();

    % Setup the ikTool for this trial
    ikTool.setMarkerDataFileName(marker_file);
    ikTool.setStartTime(initial_time);
    ikTool.setEndTime(final_time);
    ikTool.setOutputMotionFileName(mot_file);
    ikTool.setName(fname)
    ikTool.setResultsDir([pathname 'InverseKinematics\']);

    %write the XML setup file in same directory as MOT file
    ikTool.print(setup_file);

    % Run IK via API
    ikTool.run();

    % Load the results from the STO file and save to the IK
    % structure
    data.ik_results = load_sto_file(mot_file);

    disp('Done.')

    %% run inverse dynamics - commmented out for kinematic analysis only

    % disp('Running Inverse Dynamics Tool...')
    %
    % idTool = InverseDynamicsTool();
    % idTool.setModelFileName(data.ScaledModel);
    % idTool.setCoordinatesFileName(data.MOT_Filename);
    % idTool.setLowpassCutoffFrequency(filter_freq);
    %
    % % Get mot data to determine time range
    % motData = Storage(data.MOT_Filename);
    %
    % % Get initial and intial time
    % initial_time = motData.getFirstTime();
    % final_time = motData.getLastTime();
    %
    % idTool.setStartTime(initial_time);
    % idTool.setEndTime(final_time);
    %
    % %Set folders
    % idTool.setResultsDir([pathname 'InverseDynamics\']);
    % sto_filename = [pathname 'InverseDynamics\' name '.sto'];
    % data.ID_Filename = sto_filename;
    % idTool.setOutputGenForceFileName([name '.sto']);
    %
    % %create the InverseDynamics directory above c3d directory if it
    % %doesn't exist
    % if isempty(dir([pathname 'InverseDynamics']))
    %     mkdir(pathname,'InverseDynamics');
    % end
    %
    % % Set forces_to_exclude
    % excludedForces = ArrayStr();
    % excludedForces.append('Muscles');
    % idTool.setExcludedForces(excludedForces);
    %
    % % Define the new external loads file to use
    % idTool.setExternalLoadsFileName(data.EXL_Filename);
    %
    % %Print ID setup file
    % setupIDFile = [pathname 'InverseDynamics\' name '_setupID.xml'];
    % idTool.print(setupIDFile);
    %
    % idTool.run();
    %
    % % Load the results from the STO file and save to the IK
    % % structure
    % data.id_results = load_sto_file(sto_filename);
    %
    % disp('Done.')


    %% body analysis tool - commmented out for kinematic analysis only

    disp('Running Body Analysis Tool...')

    %create the MuscleAnalysis directory above c3d directory if it
    %doesn't exist
    if isempty(dir([pathname 'BodyAnalysis']))
        mkdir(pathname,'BodyAnalysis');
    end

    motData = Storage(data.MOT_Filename);
    initial_time = motData.getFirstTime();
    final_time = motData.getLastTime();

    M = Model(data.ScaledModel);

    Body_AnL = BodyKinematics(M);
    Body_AnL.setStartTime(initial_time);
    Body_AnL.setEndTime(final_time);
    M.addAnalysis(Body_AnL);

    tool = AnalyzeTool();
    tool.setModel(M);
    tool.setModelFilename(data.ScaledModel)
    tool.setCoordinatesFileName(data.MOT_Filename);
    tool.setLoadModelAndInput(true);
    tool.setSolveForEquilibrium(true);
    tool.setName(name);
    tool.setResultsDir([pathname 'BodyAnalysis\']);
    tool.setStartTime(initial_time);
    tool.setFinalTime(final_time);

    AS = tool.getAnalysisSet;
    AS.set(0,Body_AnL);

    setup_file = [pathname 'BodyAnalysis\' name '_BAsetup.xml'];
    tool.print(setup_file);
    tool.run();

    % Load the results from the STO file and save to the IK
    % structure
    f = dir([pathname 'BodyAnalysis\' name '*.sto']);
    for i = 1:length(f)
        analysis_name = strrep(strrep(strrep(f(i).name,'_BodyKinematics_',''),name,''),'.sto','');
        data.body_results.(analysis_name) = load_sto_file([f(i).folder '\' f(i).name]);
    end

    disp('Done..')

end
