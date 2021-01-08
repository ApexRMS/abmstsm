# Script to make sure all models use the configuration options set in `config.yaml`
#
# - Please ensure that the configuration in `config.yaml` is correct for your
#   machine before running this script.
#
# - If you are using R Studio, please first open the `ABM_STSM_BADL.Rproj` R
#   project file to ensure your working directory is set correctly


# Setup ------------------------------------------------------------------------

library(yaml)       # Used to parse config file
library(rsyncrosim) # Used to update the SyncroSim library as needed
library(magrittr)   # Used to write cleaner code

# Load Config ------------------------------------------------------------------

config <- read_yaml("config.yaml")

# Check that the NetLogo path exists
if(!config$`netlogo-path` %>% dir.exists)
  stop("Cannot find NetLogo directory. Please check the configuration file.")

# Check that the R executable exists
if(!config$`R-executable-path` %>% file.exists)
  stop("Cannot find the R executable. Please check the configuration file.")

# Check that both the maximum number of years and iterations are positive integers
if(!config$`max-iterations` %>% is.integer | !config$`max-years` %>% is.integer |
    config$`max-iterations` < 1            | config$`max-years` < 1)
  stop("Invalid number of iterations or years. Please check the configuration file.")

# Check that the max number of jobs is a positive integer
if(!config$`max-jobs` %>% is.integer | config$`max-jobs` < 1)
  stop("Invalid maximum number of SyncroSim jobs. Please check the configuration file.")

# Apply the Configuration ------------------------------------------------------

# Load the relevant SyncroSim library, project, etc
mylibrary <- ssimLibrary("ABM_STSM_BADL.ssim")
myproject <- project(mylibrary, "ABM_STSM_BADL")
coupledModel <- scenario(myproject, "Coupled STSM and ABM")
runControls <- scenario(myproject, "Run Controls")

## External Program ------------------------------------------------------------

# Update the External Program datasheet
externalProgramSheet <-
  data.frame(
    ExecutableName = config$`R-executable-path`,
    ScriptName = file.path(getwd(), "ABM_STSM_BADL.R"),
    CallBeforeTimesteps = paste0("0-", config$`max-years`)
  )

saveDatasheet(coupledModel, externalProgramSheet, "corestime_External")

## Run Controls ----------------------------------------------------------------

# Update the run controls datasheet
runControlSheet <-
  data.frame(
    MinimumIteration = 1,
    MaximumIteration = config$`max-iterations`,
    MinimumTimestep = 0,
    MaximumTimestep = config$`max-years`,
    IsSpatial = TRUE
  )

saveDatasheet(runControls, runControlSheet, "stsim_RunControl")

## Multiprocessing -------------------------------------------------------------

# Update the multiprocessing datasheet
multiprocessingSheet <-
  data.frame(
    EnableMultiprocessing = TRUE,
    MaximumJobs = config$`max-jobs`,
    EnableMultiScenario = TRUE
  )

saveDatasheet(mylibrary, multiprocessingSheet, "core_Multiprocessing")
