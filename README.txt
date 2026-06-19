# Theia3D to OpenSim Pipeline

MATLAB tools for converting Theia3D markerless motion capture outputs into OpenSim-compatible virtual markers, scaling subject-specific musculoskeletal models, performing inverse kinematics, and generating body kinematics outputs.

## Workflow

```text
Theia3D C3D
    ↓
Virtual Marker Generation
    ↓
Low-Pass Filtering (default 10 Hz)
    ↓
TRC Export
    ↓
OpenSim Scaling
    ↓
Inverse Kinematics
    ↓
Body Kinematics Analysis
```

## Requirements

* MATLAB
* OpenSim 4.x MATLAB API
* ezc3d
* Theia3D-generated C3D files

## Features

* Batch processing of individual files or participant folders
* Virtual marker generation from Theia3D segment poses
* Automatic TRC creation
* Subject-specific OpenSim model scaling
* Inverse kinematics processing
* Body kinematics analysis
* Optional use of a single static calibration trial for all movement trials

## Outputs

* **ModelScaling/** – scaled OpenSim models and scale files
* **InverseKinematics/** – joint kinematics (`.mot`)
* **BodyAnalysis/** – segment positions and orientations (`.sto`)

## Authors

Glen Lichtwark
Queensland University of Technology

Logan Wade
University of New South Wales
