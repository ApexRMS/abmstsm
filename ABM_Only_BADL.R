# External script to run NetLogo between every SyncroSim year. This is the
# dynamic link between the STSM and ABM.
  
# Set absolute NetLogo path, needed by RNetLogo
nlPath <- "C:/Program Files/NetLogo 6.0/app"

# Setup ------------------------------------------------------------------------

# Load libraries
library(raster)
library(RNetLogo)
library(tibble)
library(readr)
library(dplyr)
library(stringr)

# Set local paths to construct filenames, etc
workingDir <- getwd()
dataDir <- file.path(workingDir, "Data")                 # Directory with files needed by NetLogo model
outputDir <- file.path(workingDir, "ABM Only Results")   # Directory to store output files
tempDir <- file.path(workingDir, "temp")                 # Directory to store runtime files

# Set template file names, load as needed
template.models.folder <- file.path(workingDir, "Templates")
template.model.path <- "ABM_Only_BADL.nlogo"             # NetLogo Script template
template.output <- raster(paste0(dataDir, "/template.tif"))     # Output raster template

# Create local dirs if they do not exist
unlink(outputDir, recursive = T)
dir.create(outputDir)
unlink(tempDir, recursive = T)
dir.create(tempDir, showWarnings = F)

# Prepare script and outputs ---------------------------------------------------

maxIterations <- 2
maxYears <- 2

# Generate tabular output filename and initialize
outputTablePath <- file.path(outputDir, "ABM_biomass_output.csv")
outputTable <- tibble(Iteration = NULL, Year = NULL, Biomass = NULL, `Biomass Removed` = NULL)

message("Starting Simulation")
for(iteration in seq(maxIterations)) {
  
  message(paste0("Starting iteration ", iteration))
  
  # Copy and modify the NetLogo script template to use current working directory
  absolute.model.path <- paste0(tempDir, "/", template.model.path)
  nlogoScript <- readLines(file.path(template.models.folder, template.model.path), n = -1) %>%
    str_replace_all("_dataDir_", dataDir)
  writeLines(nlogoScript, absolute.model.path)
  
  # Setup NetLogo Run ----------------------------------------------------------
  nlInstance <- "nlheadless1"
  NLStart(nlPath, gui = F, nl.obj = nlInstance)
  NLLoadModel(absolute.model.path, nl.obj = nlInstance)
  NLCommand("setup", nl.obj = nlInstance)
    
  for(year in seq(maxYears)) {

    message(paste0("  Starting year ", year))
    
    # Generate raster file names for output
    outputBioRemRaster <- file.path(outputDir, str_c("ABM_biomassremoved_output", iteration, "-", year, ".tif"))
    outputGrazeHeavyRaster <- file.path(outputDir, str_c("ABM_grazeheavy_output", iteration, "-", year, ".tif"))
    outputGrazeNormRaster <- file.path(outputDir, str_c("ABM_grazenorm_output", iteration, "-", year, ".tif"))
    
    # Run NetLogo Sim for One Year ---------------------------------------------
    
    # Step forward 365 ticks (days)
    NLDoCommand(365, "go", nl.obj = nlInstance)
    
    # Extract NetLogo Outputs --------------------------------------------------
    
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
      setExtent(template.output) %>%
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
    
    # Prompt NetLogo to run for 1 more tick so it can execute "New Year" procedures,
    # otherwise the extra tick us executed at beginning of next year
    NLDoCommand(1, "go", nl.obj=nlInstance)
    
    # Add to the table of outputs
    outputTable <- outputTable %>%
      bind_rows(
        tibble(
          Iteration = iteration,
          Year = year,
          Biomass = sum(values(biomassRaster), na.rm = T),
          `Biomass Removed` = sum(values(biomassRemovedRaster), na.rm = T)))
  }
  
  # End NetLogo run ------------------------------------------------------------
      
  NLQuit(nl.obj=nlInstance)
}


# Print output table
write_csv(
  outputTable,
  outputTablePath
)

# Remove temp folder
unlink(tempDir, recursive = T)