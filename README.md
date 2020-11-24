# Coupled STSM and ABM models

This project contains files to run an example coupled state-and-transition
simulation model (STSM) and agent-based model (ABM) as described in Miller and
Frid (2020). This proof-of-concept coupled model simulates bison grazing in the
previous bison range of Badlands National Park.

## Running the Models

To run the model, first clone this repository and set the following three paths
based on the organization of your computer.
  1. At the top of the `ABM_STSM_BADL.R` script, modify the `nlPath` variable 
     to reflect the path to the NetLogo binary on your computer.
  2. In the `ABM_STSM_BADL.ssim` SyncroSim library under Scenario Properties ->
     Advanced -> External Program, set the External Program to the location of
     the RScript binary on your computer. Note that RStudio can be used in place
     of RScript for debugging.
  3. In the same External Program dialog as above, choose `ABM_STSM_BADL.R` as
     the External Script. This path will depend on where you clone the
     repository to on your computer.

Optionally, you can modify the number of time steps and replicates (iterations)
to simulate using the Scenario Properties -> Run Control dialog in SyncroSim and
set the maximum number of jobs to run using the multiprocessing tab in the main
toolbar.

Finally, hit Run in the main toolbar in SyncroSim to run the model. The results
of the run can be viewed using the Chart and Map user interfaces in SyncroSim or
exported for use in other visualization or analysis pipelines.

## Versions and Dependencies

The model requires working installations of SyncroSim, NetLogo, and R. In
SyncroSim, the `stsim` package and `stsimsf` add-on package must be installed,
or will be installed when the SyncrSim library is loaded. In R, the
`rsyncrosim`, `RNetLogo`, `raster`, and `tidyverse` packages must be installed.
The models and scripts were developed using SyncroSim v2.2.21 with the ST-Sim
(v3.2.23) and stsimsf (v3.2.15) packages; NetLogo 6.0; and R v4.0.3 with the
RNetLogo (v1.0-4) and rsyncrosim (v1.2.4) packages.

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

## Project Organization

`ABM_STSM_BADL.ssim` is the SyncroSim library that is used to organize the
entire coupled model. The STSM portion of this model, which includes simulating
changes in vegetation composition over years, is defined and run within
SyncroSim. Between timesteps, this file also calls the R script which acts as
the dynamic link between the STSM and ABM.

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

