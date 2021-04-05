# External script to run NetLogo between every SyncroSim timestep. This is the
# dynamic link between the STSM and ABM.
  
# Setup ------------------------------------------------------------------------

# Load libraries
library(rsyncrosim)
library(raster)
library(RNetLogo)
library(tibble)
library(readr)
library(dplyr)
library(stringr)
library(yaml)

## Setup up necessary files and folders ----------------------------------------

# Set local paths to construct filenames, etc
workingDir <- dirname(ssimEnvironment()$LibraryFilePath)
# If running in a parallel folder, move up to the parent directory
if(str_detect(workingDir, ".ssim.temp"))
  workingDir <- str_replace(workingDir, "/[\\n\\w\\d]+\\.ssim\\.temp.*", "")
dataDir <- file.path(workingDir, "Data")                 # Directory with files needed by NetLogo model
tempDir <- ssimEnvironment()$TempDirectory %>%           # Run-specific temp folder to avoid file collisions during parallel processing
  str_replace_all("\\\\", "/")                           # R can handle forward slashes in paths, even on windows machines
transferDir <- ssimEnvironment()$TransferDirectory %>%   # Run-specific data transfer folder
  str_replace_all("\\\\", "/")                           # R can handle forward slashes in paths, even on windows machines
locationsDir <- file.path(tempDir, "locations")          # Directory store buffalo locations                         

# Set template file names, load as needed
template.models.folder <- file.path(workingDir, "Templates")
template.model.path <- "ABM_Only_BADL.nlogo"             # NetLogo Script template
template.output <- raster(paste0(dataDir, "/template.tif"))     # Output raster template

# Create local dirs if they do not exist
dir.create(locationsDir)

# Setup SyncroSim connection, load info about this run
mySession <- rsyncrosim::session()
myLibrary <- ssimLibrary()
myScenario <- scenario()
timestep <- ssimEnvironment()$BeforeTimestep
iteration <- ssimEnvironment()$BeforeIteration

## Parse config ----------------------------------------------------------------
config <- read_yaml(str_c(workingDir, "/config.yaml"))

nlPath <- config$`netlogo-path`
if(!dir.exists(nlPath))
  stop("Could not find Net Logo install path! Please check `config.yaml`")


# Generate Run-specific Scripts and Inputs -------------------------------------

# Generate raster file names to be placed in the run-specific Transfer folder
inputStateRaster <- file.path(tempDir, "ABM_input.asc")
outputBioRemRaster <- file.path(tempDir, str_c("ABM_biomassremoved_output", timestep, ".tif"))
outputGrazeHeavyRaster <- file.path(tempDir, str_c("ABM_grazeheavy_output", timestep, ".tif"))
outputGrazeNormRaster <- file.path(tempDir, str_c("ABM_grazenorm_output", timestep, ".tif"))

# Set buffalo location file names for current and following run The current
# location was produced in the previous run, except in the case of the first
# time step. Copy the default locations from the Data folder for this run
locationsFile <- paste0(locationsDir, "/", timestep, ".txt")
locationsFileNext <- paste0(locationsDir, "/", timestep+1, ".txt")
locationFileExists <- file.exists(locationsFile)
if(!(locationFileExists)){
  print("No location file. Using start timestep locations.")
  file.copy(
    paste0(dataDir, "/locations_in.txt"), 
    locationsFile, 
    overwrite = FALSE)
}

# Copy and modify the NetLogo script template to use run-specific inputs
# This script is stored in the run-specific Temp folder to avoid conflicts
absolute.model.path <- paste0(tempDir, "/", template.model.path)
nlogoScript <- readLines(file.path(template.models.folder, template.model.path), n = -1) %>%
  str_replace_all("_dataDir_", dataDir) %>%
  str_replace_all("locations_in.txt", locationsFile) %>%
  str_replace_all("locationsNew.txt", locationsFileNext)
writeLines(nlogoScript, absolute.model.path)

# Run NetLogo ------------------------------------------------------------------
nlInstance <- "nlheadless1"
NLStart(nlPath, gui = F, nl.obj = nlInstance)
NLLoadModel(absolute.model.path, nl.obj = nlInstance)
NLCommand("setup", nl.obj = nlInstance)
NLDoCommand(365, "go", nl.obj = nlInstance)

# Extract NetLogo Outputs ------------------------------------------------------

# Save map of biomass removed as a raster
biomassRemoved <- NLGetPatches(c("pxcor","pycor","biomass_removed"), nl.obj=nlInstance)
coordinates(biomassRemoved) <- ~ pxcor + pycor
gridded(biomassRemoved) <- TRUE
biomassRemovedRaster <- raster(biomassRemoved) %>%
  setExtent(template.output, keepres=FALSE, snap=TRUE) %>%
  mask(template.output)
projection(biomassRemovedRaster) <- CRS("+proj=utm +zone=13 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")
biomassRemovedFileName <- paste0(tempDir, "/biomassRemoved.tif")
writeRaster(biomassRemovedRaster, biomassRemovedFileName, overwrite=T)

# Save map of biomass as a raster
biomass <- NLGetPatches(c("pxcor","pycor","biomass"), nl.obj=nlInstance)
coordinates(biomass) <- ~ pxcor + pycor
gridded(biomass) <- TRUE
biomassRaster <- raster(biomass) %>%
  setExtent(template.output, keepres=FALSE, snap=TRUE) %>%
  mask(template.output)
projection(biomassRaster) <- CRS("+proj=utm +zone=13 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")
biomassFileName <- paste0(tempDir, "/biomass.tif")
writeRaster(biomassRaster, biomassFileName, overwrite=T)

# Reload rasters so N/A values are removed (avoids errors in raster math)
biomassRemovedRaster <- raster(biomassRemovedFileName)
biomassRaster <- raster(biomassFileName)

# Calculate proportion of biomass removed and save to outputs
biomassRemovedProportion <- biomassRemovedRaster/(biomassRaster + biomassRemovedRaster)
writeRaster(biomassRemovedProportion, outputBioRemRaster, format="GTiff", overwrite=TRUE)

# Export results to SyncroSim --------------------------------------------------

# Collect tabular data
outputTable <- data.frame(
  Iteration = iteration,
  Timestep = timestep,
  Name = c("Biomass", "Biomass Removed"),
  Value = c(sum(values(biomassRaster), na.rm = T), sum(values(biomassRemovedRaster), na.rm = T)),
  stringsAsFactors = F)
saveDatasheet(myScenario, outputTable, "corestime_ExternalProgramVariable", append = T)

# Clean and terminate NetLogo instance -----------------------------------------

# Prompt NetLogo to run for 1 more tick so it can execute "New Year" procedures,
# otherwise the extra tick us executed at beginning of next timestep
NLDoCommand(1, "go", nl.obj=nlInstance)

NLQuit(nl.obj=nlInstance)