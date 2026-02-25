set.seed(777)

library(sits)
library(restoreutils)

#
# General definitions
#

# Local directories
base_masks_dir <- restoreutils::project_masks_dir()
base_classifications_dir <- restoreutils::project_classifications_dir()

# Mask - tiles (works as a roi)
mask_tiles <- c()

# Mask - version
mask_version <- "rules-v2"

# Classification - version
classification_version <- "samples-cer-v4a-tempcnn"

# samples-cer-v4a-tempcnn-default-spacing-10-compactness-05-2018
# samples-cer-v4a-tempcnn-default-spacing-20-compactness-03-2018
# samples-cer-v4a-tempcnn-tuning-spacing-10-compactness-05-2018

# Classification - years
classification_year <- 2018

# Hardware - Multicores
multicores <- 80

# Hardware - Memory size
memsize <- 120

#
# 1. Define output directory
#
output_dir <- restoreutils::create_data_dir(
  base_masks_dir / mask_version / classification_version, classification_year
)

classification_dir <- (
  base_classifications_dir / classification_version / classification_year
)

#
# 2. Load base masks
#

# Vegetation maps
veg_map <- restoreutils::load_vegmap(
  year = classification_year, multicores = multicores, memsize = memsize
)

#
# 3. Load classification
#
labels <- restoreutils::labels_cerrado_classification()
eco_class <- restoreutils::load_restore_mosaic(
  data_dir   = classification_dir,
  tiles      = "MOSAIC",
  labels     = labels,
  multicores = multicores,
  memsize    = memsize,
  version    = "v1"
)

eco_mask <- restoreutils::reclassify_cer_rule0_natveg(
  cube         = eco_class,
  mask         = veg_map,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  version      = "step1"
)

eco_mask <- restoreutils::reclassify_cer_rule1_veg(
  cube         = eco_class,
  mask         = veg_map,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  version      = "step2"
)


#
# 5. Save cube object
#
saveRDS(eco_mask, output_dir / "mask-cube.rds")

#
# 6. COG data
#
sf::gdal_addo(eco_mask[["file_info"]][[1]][["path"]])

#
# Crop cube to tiles
#
if (length(mask_tiles)) {
  cube_files <- crop_to_roi(
    cube        = eco_mask,
    tiles       = mask_tiles,
    multicores  = multicores,
    output_dir  = output_dir,
    grid_system = "BDC_MD_V2"
  )

  saveRDS(cube_files, output_dir / "mask-cube-tiles.rds")
}
