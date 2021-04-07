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

## Setup necessary files and folders -------------------------------------------

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
template.model.path <- "ABM_STSM_BADL.nlogo"             # NetLogo Script template
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
biomassRemovedProportionFilename <- file.path(tempDir, str_c("ABM_biomassremoved_output.it", iteration, ".ts.", timestep, ".tif"))
outputGrazeHeavyRaster <- file.path(tempDir, str_c("ABM_grazeheavy_output.it", iteration, ".ts.", timestep, ".tif"))
outputGrazeNormRaster <- file.path(tempDir, str_c("ABM_grazenorm_output.it", iteration, ".ts.", timestep, ".tif"))
  
# Get the number of bison to generate
numBison <-datasheet(myScenario, "corestime_ExternalProgramVariable") %>%
  filter(Name == "Bison Count") %>%
  pull(Value) %>%
  `[`(1)

if(is.na(numBison))
  stop("Can't find the variable numBison")

# Set buffalo location file names for current and following run The current
# location was produced in the previous run, except in the case of the first
# time step. Copy the default locations from the Data folder for this run
locationsFile <- paste0(locationsDir, "/", timestep, ".txt")
locationsFileNext <- paste0(locationsDir, "/", timestep+1, ".txt")
locationFileExists <- file.exists(locationsFile)
if(timestep == 1){
  print("No location file. Using start timestep locations.")
  
  # Read in the location file and parse locations
  bisonLocationsRaw <- read_file(paste0(dataDir, "/locations_in.txt")) %>%
    str_split(" ") %>%
    unlist %>%
    `[`(-1)
  
  # Determine if there are more bison than locations
  resampleLocations <- numBison > (length(bisonLocationsRaw) / 2)
  
  # Pair and sample bison locations as needed
  str_c(
    bisonLocationsRaw[seq(1, length(bisonLocationsRaw), 2)],
    " ",
    bisonLocationsRaw[seq(2, length(bisonLocationsRaw), 2)]) %>%
    sample(numBison, replace = resampleLocations) %>%
    str_c(collapse = " ")
  
  # Combine pairs of X and Y, sample based on the number of bison, and write to file
  bisonLocationsRaw %>%
    {str_c(
      .[seq(1, length(.), 2)],
      " ",
      .[seq(2, length(.), 2)])} %>%
    sample(numBison, replace = resampleLocations) %>%
    str_c(collapse = " ") %>%
    write_file(locationsFile)
}

# Copy and modify the NetLogo script template to use run-specific inputs
# This script is stored in the run-specific Temp folder to avoid conflicts
absolute.model.path <- paste0(tempDir, "/", template.model.path)
nlogoScript <- readLines(file.path(template.models.folder, template.model.path), n = -1) %>%
  str_replace_all("_dataDir_", dataDir) %>%
  str_replace_all("_inputPath_", inputStateRaster) %>%
  str_replace_all("_numBison_", as.character(numBison)) %>%
  str_replace_all("locations_in.txt", locationsFile) %>%
  str_replace_all("locationsNew.txt", locationsFileNext)
writeLines(nlogoScript, absolute.model.path)

# Generate run-specific raster inputs for NetLogo
spatialState  <-  datasheetRaster(
  myScenario, 
  datasheet = "OutputSpatialState", 
  iteration = iteration, 
  timestep = (timestep-1))[[1]]
projection(spatialState) <- CRS("+proj=utm +zone=13 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")
writeRaster(spatialState, inputStateRaster, format = "ascii", overwrite = TRUE)

spatialNPP <- datasheetRaster(
  myScenario, 
  datasheet = "OutputSpatialStateAttribute", 
  iteration = iteration, 
  timestep = (timestep-1))[[1]]
projection(spatialNPP) <- CRS("+proj=utm +zone=13 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")

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
writeRaster(biomassRemovedRaster, biomassRemovedFileName, overwrite=T, NAflag = -9999)

# Save map of biomass as a raster
biomass <- NLGetPatches(c("pxcor","pycor","biomass"), nl.obj=nlInstance)
coordinates(biomass) <- ~ pxcor + pycor
gridded(biomass) <- TRUE
biomassRaster <- raster(biomass) %>%
  setExtent(template.output, keepres=FALSE, snap=TRUE) %>%
  mask(template.output)
projection(biomassRaster) <- CRS("+proj=utm +zone=13 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs ")
biomassFileName <- paste0(tempDir, "/biomass.tif")
writeRaster(biomassRaster, biomassFileName, overwrite=T, NAflag = -9999)

# Reload rasters so N/A values are removed (avoids errors in raster math)
biomassRemovedRaster <- raster(biomassRemovedFileName)
biomassRaster <- raster(biomassFileName)

# Calculate proportion of biomass removed and save to outputs
biomassRemovedProportion <- biomassRemovedRaster/(biomassRaster + biomassRemovedRaster)
biomassRemovedProportion <- writeRaster(biomassRemovedProportion, biomassRemovedProportionFilename, format="GTiff", overwrite=TRUE, NAflag = -9999)

# Calculate binary maps of heavy and normal grazing based on proportion of NPP removed. Save to outputs
propNppRemoved <- biomassRemovedRaster/spatialNPP
grazeHeavy <- propNppRemoved
grazeHeavy[propNppRemoved < .75]<- 0
grazeHeavy[propNppRemoved >= .75]<- 1
grazeNormal <- propNppRemoved
grazeNormal[propNppRemoved >= 0.25 & propNppRemoved < .75]<- 1
grazeNormal[propNppRemoved < 0.25 | propNppRemoved >= .75]<- 0
writeRaster(grazeHeavy, outputGrazeHeavyRaster, format="GTiff", overwrite=TRUE, NAflag = -9999)
writeRaster(grazeNormal, outputGrazeNormRaster, format="GTiff", overwrite=TRUE, NAflag = -9999)

# Export results to SyncroSim --------------------------------------------------

# Save grazing maps as a Transition Spatial Multiplier

grazingSheetName <- "stsim_TransitionSpatialMultiplier"

grazingDataHeavy <- data.frame(
  Iteration=iteration,
  Timestep=timestep,
  TransitionGroupID="Grazing - Heavy, Season Long",
  TransitionMultiplierTypeID="Temporal", #optional field
  MultiplierFileName = outputGrazeHeavyRaster,
  stringsAsFactors=F)

grazingDataNormal <- data.frame(
  Iteration=iteration,
  Timestep=timestep,
  TransitionGroupID="Grazing - Normal, Season Long",
  TransitionMultiplierTypeID="Temporal", #optional field
  MultiplierFileName = outputGrazeNormRaster,
  stringsAsFactors=F)
grazingData <- rbind(grazingDataHeavy, grazingDataNormal)

saveDatasheet(myScenario, grazingData, name = grazingSheetName, append=T)

# Save maps of proportion of biomass removed
biomassRemovedSheetName <- "stsimsf_FlowSpatialMultiplier"

biomassRemovedData <- data.frame(
  Iteration=iteration,
  Timestep=timestep,
  FlowGroupID="Grazing Biomass Removal",
  MultiplierFileName = biomassRemovedProportionFilename,
  stringsAsFactors=F)
saveDatasheet(myScenario, biomassRemovedData, name = biomassRemovedSheetName, append=T)

# Collect tabular data
outputTable <- data.frame(
  Iteration = iteration,
  Timestep = timestep,
  Name = c("Biomass", "Biomass Removed", "Bison Count"),
  Value = c(sum(values(biomassRaster), na.rm = T), sum(values(biomassRemovedRaster), na.rm = T), numBison),
  stringsAsFactors = F)
saveDatasheet(myScenario, outputTable, "corestime_ExternalProgramVariable", append = T)

# Clean and terminate NetLogo instance -----------------------------------------

# Prompt NetLogo to run for 1 more tick so it can execute "New Year" procedures,
# otherwise the extra tick us executed at beginning of next timestep
NLDoCommand(1, "go", nl.obj=nlInstance)

NLQuit(nl.obj=nlInstance)
