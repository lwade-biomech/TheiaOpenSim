# Theia3D to OpenSim Pipeline

MATLAB tools for converting Theia3D markerless motion capture outputs into OpenSim-compatible virtual markers, scaling subject-specific musculoskeletal models, performing inverse kinematics, and generating body kinematics outputs.

## Workflow

```mermaid
flowchart TD
    A[Theia3D C3D] --> B[Virtual Marker Generation]
    B --> C[Low-Pass Filtering<br/>Default: 10 Hz]
    C --> D[TRC Export]
    D --> E[OpenSim Model Scaling]
    E --> F[Inverse Kinematics]
    F --> G[Body Kinematics Analysis]
```

## Requirements

* MATLAB
* OpenSim 4.x MATLAB API
* ezc3d
* Theia3D-generated C3D files

## Features

* Batch processing of individual files or participant folders
* Virtual marker generation from Theia3D segment poses
* Automatic TRC generation
* Subject-specific OpenSim model scaling
* Inverse kinematics processing
* Body kinematics analysis
* Optional static calibration workflow using a single scaled model for all trials

## Outputs

### `ModelScaling/`

* Scaled OpenSim models (`.osim`)
* Scale factors (`.xml`)
* Marker placement files
* Static motion files

### `InverseKinematics/`

* Joint kinematics (`.mot`)
* IK setup files (`.xml`)

### `BodyAnalysis/`

* Segment positions and orientations (`.sto`)
* Body kinematics outputs

## Notes

* Virtual markers are generated from Theia3D segment poses and are intended for OpenSim scaling and inverse kinematics workflows.
* Marker trajectories are low-pass filtered prior to TRC generation, scaling, and inverse kinematics.
* Users are responsible for ensuring that derived outcome measures are appropriate for markerless motion capture applications and supported by relevant validation literature.

## Authors

**Glen Lichtwark**
Queensland University of Technology

**Logan Wade**
University of New South Wales
