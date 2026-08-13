set.seed(777)

library(sits)
library(restoreutils)

restoreutils::curl_patch_config()

#
# General definitions
#

# Local directories
base_masks_dir <- restoreutils::project_masks_dir()
base_classifications_dir <- restoreutils::project_classifications_dir()

# Mask - version
mask_version <- "rules-v1"

# Classification - version
classification_version <- "v14a"

# Classification - years
classification_year <- 2020

# Hardware - Multicores
multicores <- 32

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

# Download terraclass
restoreutils::download_terraclass(
  region = "cerrado", 
  year  = 2020, 
  version = "v1"
)

# TerraClass 2020
tc_2020 <- restoreutils::load_terraclass_cerrado_2020(
  multicores = multicores,
  memsize = memsize
)

#
# 3. Download classification
#

# Build classification url
file_url <- restoreutils::aws_build_url_classification_cerrado(
  version = classification_version,
  year = classification_year
)

# Download AWS file and convert to sits file name pattern
restoreutils::aws_download(
  file = file_url,
  version = classification_version,
  year = classification_year,
  output_dir = classification_dir
)

#
# 4. Load classification
#
labels <- restoreutils::labels_cerrado_classification()
eco_class <- restoreutils::load_restore_mosaic(
  data_dir   = classification_dir,
  tiles      = "MOSAIC",
  labels     = labels,
  multicores = multicores,
  memsize    = memsize,
  version    = classification_version
)

eco_mask <- restoreutils::reclassify_cer_rule3_agr_anual(
  cube         = eco_class,
  mask         = tc_2020,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  rarg_year    = classification_year,
  version      = "step1"
)

eco_mask <- restoreutils::reclassify_cer_rule4_semi_perene(
  cube         = eco_mask,
  mask         = tc_2020,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  rarg_year    = classification_year,
  version      = "step2"
)

eco_mask <- restoreutils::reclassify_cer_rule5_perene(
  cube         = eco_mask,
  mask         = tc_2020,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  rarg_year    = classification_year,
  version      = "step3"
)

eco_mask <- restoreutils::reclassify_cer_rule6_silviculture(
  cube         = eco_mask,
  mask         = tc_2020,
  multicores   = multicores,
  memsize      = memsize,
  output_dir   = output_dir,
  rarg_year    = classification_year,
  version      = "step4"
)

#
# 5. Save cube object
#
saveRDS(eco_mask, output_dir / "mask-cube.rds")

#
# 6. COG data
#
restoreutils::gdal_addo(eco_mask)
