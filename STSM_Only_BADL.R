# External script to run NetLogo between every SyncroSim timestep. This is the
# dynamic link between the STSM and ABM.
  
# Setup ------------------------------------------------------------------------

# Load libraries
library(rsyncrosim)
library(raster)
library(dplyr)
library(stringr)

## Setup up necessary files and folders ----------------------------------------

# Setup SyncroSim connection, load info about this run
mySession <- rsyncrosim::session()
myLibrary <- ssimLibrary()
myScenario <- scenario()
timestep <- ssimEnvironment()$AfterTimestep
iteration <- ssimEnvironment()$AfterIteration

# Extract relevant output ------------------------------------------------------
datasheet(myScenario, summary = T)
biomass <- datasheet(myScenario, "stsimsf_OutputStock") %>%
  filter(
    Iteration == iteration,
    Timestep == timestep,
    str_detect(StockGroupID, "Total Biomass")) %>%
  pull(Amount) %>%
  sum
biomassRemoved <- datasheet(myScenario, "stsimsf_OutputFlow") %>%
  filter(
    Iteration == iteration,
    Timestep == timestep,
    str_detect(FlowGroupID, "Grazing Biomass Removal")) %>%
  pull(Amount) %>%
  sum

# Save results to SyncroSim ----------------------------------------------------
  
# Collect tabular data
outputTable <- data.frame(
  Iteration = iteration,
  Timestep = timestep,
  Name = c("Biomass", "Biomass Removed"),
  Value = c(biomass,
            biomassRemoved),
  stringsAsFactors = F)
saveDatasheet(myScenario, outputTable, "corestime_ExternalProgramVariable", append = T)
