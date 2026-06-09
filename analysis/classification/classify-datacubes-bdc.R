set.seed(777)

library(sits)
library(restoreutils)

#
# General definitions
#
base_cubes_dir <- restoreutils::project_cubes_dir()
base_segmentations_dir <- fs::path("data/derived/segmentations") # restoreutils::project_classifications_dir()
base_classifications_dir <- restoreutils::project_classifications_dir()
processing_context <- "coids::rolf::cerrado"


# Model
model_version <- "ltae_cer-v4a"

# Segmentation - version
segmentation_version <- "hex-s15-c04-p00"

# Classification - version
classification_version <- paste0(segmentation_version, "-", model_version)

# Classification - years
classification_years <- 2018

# Hardware - Multicores
multicores <- 120

# Hardware - Memory size
memsize <- 480


#
# 1. Load model
#
model <- readRDS(
  restoreutils::project_model_file(version = model_version)
)


#
# 2. Classify cubes
#
for (classification_year in classification_years) {
  # restoreutils::notify(
  #   processing_context, paste("classify cubes > started >", classification_year, classification_version)
  # )

  tryCatch({
    # Define output directories
    cube_dir <- restoreutils::create_data_dir(
      base_cubes_dir, classification_year
    )
  
    classification_dir <- restoreutils::create_data_dir(
      base_classifications_dir / classification_version, classification_year
    )
  
    classification_rds <- classification_dir / "mosaic.rds"
  
    # Load segmentation cube
    segmentation_dir <- base_segmentations_dir / segmentation_version / classification_year
    segmentation_rds <- segmentation_dir / "segments.rds"
    cube <- readRDS(segmentation_rds)
  
    # Classify cube
    probs <- sits_classify(
      data        = cube,
      ml_model    = model,
      multicores  = multicores,
      memsize     = memsize,
      output_dir  = classification_dir,
      progress    = TRUE,
      version     = classification_version
    )
  
    # # Smooth cube
    # bayes <- sits_smooth(
    #   cube       = probs,
    #   multicores = multicores,
    #   memsize    = memsize,
    #   output_dir = classification_dir,
    #   progress   = TRUE,
    #   version    = classification_version
    # )
  
    # Define classification labels
    class <- sits_label_classification(
      cube       = probs,
      multicores = multicores,
      memsize    = memsize,
      output_dir = classification_dir,
      progress   = TRUE,
      version    = classification_version
    )
  
    # Mosaic cubes
    mosaic_cube <- sits_mosaic(
      cube       = class,
      multicores = multicores,
      output_dir = classification_dir,
      version    = classification_version
    )

    # Save rds
    saveRDS(mosaic_cube, classification_rds)
  }, error = function(e) {
    message(conditionMessage(e))
    # restoreutils::notify(
    #   processing_context, paste("classify cubes > error >", conditionMessage(e))
    # )
  })
  # restoreutils::notify(
  #   processing_context, paste("classify cubes > finished >", classification_year, classification_version)
  # )
}
