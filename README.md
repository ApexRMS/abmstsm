# Coupled STSM and ABM models

This repository contains files to run an example coupled state-and-transition
simulation model (STSM) and agent-based model (ABM) as described in Miller and
Frid (2020). This proof-of-concept coupled model simulates bison grazing in the
previous bison range of Badlands National Park.

This repository also contains the files to run comparable simulations using
only an STSM or only an ABM.

## Table of Contents

#### [Versions and Dependencies](#versions-and-dependencies)
#### [Configuring the Models](#configuring-the-models)
#### [Running the Models](#running-the-models)
#### [Project Organization](#project-organization)
#### [Citing](#citing)
#### [Acknowledgements](#acknowledgements)

## Versions and Dependencies

The model requires working installations of SyncroSim, NetLogo, and R. In
SyncroSim, the `stsim` package and `stsimsf` add-on package must be installed,
or will be installed when the SyncrSim library is loaded. In R, the
`rsyncrosim`, `RNetLogo`, `raster`, `tidyverse`, and `yaml` packages must be
installed. The models and scripts were developed using SyncroSim v2.2.25 with
the ST-Sim (v3.2.23) and stsimsf (v3.2.15) packages; NetLogo 6.0; and R v4.0.3
with the RNetLogo (v1.0-4) and rsyncrosim (v1.2.4) packages.

To install any missing R packages, run the following in R:

```{r}
packages <- c("rsyncrosim", "raster", "RNetLogo", "tidyverse")

lapply(
  packages,
    function(x) 
      if (!require(x, character.only = TRUE, quietly = TRUE))
        install.packages(x, dependencies = TRUE)
)
```

## Configuring the Models

The `config.yaml` file is used to configure all three model scenarios in one
place. R Studio and most modern text editors have syntax highlighting for YAML
files, but may not be associated with these files by default. The syntax for
YAML is fairly self-evident, but please refer to this short
[tutorial](https://rollout.io/blog/yaml-tutorial-everything-you-need-get-started/)
for details.

Five values need to be set in the configuration file:

  1. `netlogo-path` is the location of the NetLogo folder that includes the
     NetLogo executable you would like to use.
      - Note that the NetLogo scripts may need to be updated if using a version
        other than NetLogo 6.0. This can be done by opening the two NetLogo
        scripts in the `Templates/` folder with your chosen version of NetLogo.

  2. `R-executable-path` is the location of the R executable you would like to
     use to in the coupled model.
      - R Script is suggested for non-interactive runs, but RStudio can be used
        instead to run the script interactively. This is particularly useful for
        debugging the coupled model.
      - Note that the default configuration assumes that R v4.0.3 is installed.
        Be sure to update this value if that is not the case.

  3. `max-years` is the total number of years to simulate.

  4. `max-iterations` is the total number of realizations to simulate.

  5. `max-jobs` is the maximum number of jobs to allow SyncroSim to run in
      parallel.

Once the configuration values have been set, run the `config.R` script to apply
the configuration to all three models. If you choose to use RStudio to do this,
first open the `ABM_STSM_BADL.Rproj` R project file to ensure RStudio is using
the correct working directory.

## Running the Models

### Running just the STSM

After configuration, the STSM Only scenario can be run by opening SyncroSim and
navigating to the "[1115] STSM Only" scenario. Once the scenario is selected, 
press the `Run Scenario` button in the main toolbar to begin the simulation. The
results of the run can be viewed using the Chart and Map user interfaces in
SyncroSim or exported for use in other visualization or analysis pipelines.

### Running just the ABM

After configuration, the ABM Only scenario can be run by running the
`ABM_Only_BADL.R` script. If you choose to use RStudio to do this, first open
the `ABM_STSM_BADL.Rproj` R project file to ensure RStudio is using the correct
working directory. The results of the run will be stored in the `ABM Only Results/`
folder that is created by this script.

### Running the Coupled Model

After configuration, the STSM Only scenario can be run by opening SyncroSim and
navigating to the "[1110] Coupled STSM and ABM" scenario. Once the scenario is
selected, press the `Run Scenario` button in the main toolbar to begin the
simulation. The results of the run can be viewed using the Chart and Map user
interfaces in SyncroSim or exported for use in other visualization or analysis
pipelines.

## Project Organization

`ABM_STSM_BADL.ssim` is the SyncroSim library that is used to organize the
entire coupled model. The STSM portion of this model, which includes simulating
changes in vegetation composition over years, is defined and run within
SyncroSim. Between timesteps, this file also calls the R script `ABM_STSM_BADL.R`
which acts as the dynamic link between the STSM and ABM.

`ABM_STSM_BADL.R` is the R script that acts as the dynamic link between the STSM
and ABM. It uses information from the SyncroSim environment to set the initial
conditions for the ABM, starts NetLogo, and finally passes the ABM results back
to SyncroSim.

`ABM_STSM_BADL.nlogo` is the _template_ for a NetLogo script that simulates the
movement and grazing of buffalo within simulated years. The R script copies and
modifies this template based on the initial conditions provided by the STSM for
a given iteration and timestep to generate a working NetLogo script that is
subsequently called by the same R script.

The `extensions` folder contains standard NetLogo extensions, and is required to
be in the same directory as the .nlogo files in orde to implement the ABM.

The `Data` folder contains all necessary input data for the coupled model.

## Citing

If you use or refer to these models, data, scripts, or techniques, we ask that
you cite:

Miller, B. W., & Frid, L. (2020). A New Approach for Representing
Agent-Environment Feedbacks: Coupled Agent-Based and State-And-Transition
Simulation Models. Landscape Ecology. In Review.

## Acknowledgements

We are grateful to Josie Hughes and Alex Embrey for helping develop the coupled
model script, to Tyler Beeton for sharing an ABM that served as the seed for
the one described here, and to Shreeram Senthivasn for helping update and tidy
the project for this repository. This research was funded by the North Central
Climate Adaptation Science Center, U.S. Geological Survey. Any use of trade,
firm, or product names is for descriptive purposes only and does not imply
endorsement by the U.S. Government.

