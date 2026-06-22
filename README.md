# Theia3D to OpenSim Pipeline

MATLAB tools for converting Theia3D markerless motion capture outputs (C3D files) into OpenSim-compatible virtual markers, scaling an OpenSim model, running inverse kinematics, and exporting body kinematics.

## Requirements

- MATLAB
- OpenSim 4.x MATLAB API
- ezc3d
- Theia3D-generated C3D files
- OpenSim model and setup files:
  - generic model (`.osim`)
  - Scale Tool setup file (`scale_setup.xml`)
  - Inverse Kinematics setup file (`ik_setup.xml`)

## How to run

1. Open MATLAB.
2. Add the repository folder, OpenSim MATLAB API, and ezc3d to the MATLAB path.
3. Open the main Theia-to-OpenSim batch-processing script [theia_opensim_batch_script].
4. Check that the model and setup-file paths are correct.
5. Run the script.
6. Choose whether to process:
   - a full participant folder, or
   - selected C3D files.
7. Enter the participant mass in kg when prompted.
8. Choose the scaling mode:
   - **Every file**: scale a separate OpenSim model for each trial.
   - **Calibration trial**: select one static/calibration trial and reuse that scaled model for all movement trials.
        - If using a calibration trial, select the static/calibration C3D file when prompted. Theia needs movement to scale a trial adequately, thus your calibration/'static' trial should have movement in. The example 'static' trial here starts and ends with an A frame posture, with movement in the middle.
10. The script will then:
    - convert Theia3D C3D files to virtual marker C3D files,
    - write TRC files,
    - scale the OpenSim model,
    - run inverse kinematics,
    - run body kinematics analysis.


Example C3D files are provided to help get you started.

## Outputs

The script creates the following output folders inside the selected participant folder.

### `ModelScaling/`
Contains scaled model outputs, including:
- scaled OpenSim models (`.osim`)
- applied scale files (`.xml`)
- marker placement files (`.xml`)
- static motion files (`.mot`)
- Scale Tool setup files (`.xml`)

### `InverseKinematics/`
Contains inverse kinematics outputs, including:
- joint kinematics (`.mot`)
- IK setup files (`.xml`)

### `BodyAnalysis/`
Contains body kinematics outputs, including:
- segment positions (`.sto`)
- segment orientations (`.sto`)
- other OpenSim BodyKinematics outputs

## Notes
- Virtual markers are generated from Theia3D segment poses, not from physical markers.
- Marker trajectories are filtered before TRC export, model scaling, and inverse kinematics (10Hz by default).
- Users should check that marker definitions, model coordinates, and setup files are appropriate for their OpenSim model.
- Derived outcome measures should be selected carefully and should be appropriate for markerless motion capture data.

## Authors
**Glen Lichtwark**  
Queensland University of Technology

**Logan Wade**  
University of New South Wales

## Issues
If you have any issues running this code, please contact: logan.wade@unsw.edu.au