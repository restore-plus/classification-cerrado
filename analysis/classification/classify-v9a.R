set.seed(777)

library(glue)
library(sits)

#
# Tiles of Cerrado
#
cerrado_tiles <- c(
  "009014", "010010", "010014", "013008", "013010", "013012",
  "014006", "014012", "014013", "015005", "017004", "017005"
)

#
# Setup directory
#
base_dir <- file.path("data", "derived")
cubes_dir <- file.path(base_dir, "cubes")

models_dir <- file.path(base_dir, "models")
segments_dir <- file.path(base_dir, "segments")
classifications_dir <- file.path(base_dir, "classifications")
dir.create(classifications_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(classifications_dir))

# Setup versions
model_version <- "tempcnn-cer-v9a"
raster_version <- "raster"
version <- glue("{model_version}-{raster_version}")

# Setup years
years <- c(2018) # ou 2015:2022

# Hardware
multicores <- 32L
memsize <- 128

# Setup parallel cluster
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

# Define processing chunks
chunk_size <- 1L
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

# Load model
model_file <- file.path(models_dir, glue("model-{model_version}.rds"))
model <- readRDS(model_file)

#
# Year loop
#
for (year in years) {
  # Input cube dir for this year
  cube_dir_y1 <- file.path(cubes_dir, as.character(year - 1))
  cube_dir_y2 <- file.path(cubes_dir, as.character(year))

  # Segments dir for this year/version
  segs_dir <- file.path(segments_dir, raster_version, as.character(year))

  # Output classification dir for this year/version
  output_dir <- file.path(classifications_dir, version, as.character(year))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(dir.exists(output_dir))

  # Chunk-of-tiles: sits will resume using output_dir
  for (tile_chunk in tiles) {
    message("Year ", year, " | tile(s) ", paste(tile_chunk, collapse = ", "))

    message("- loading cube")
    cube_y1 <- sits_cube(
      source = "BDC",
      collection = "LANDSAT-OLI-16D",
      tiles = tile_chunk,
      data_dir = cube_dir_y1,
      progress = FALSE
    )
    cube_y2 <- sits_cube(
      source = "BDC",
      collection = "LANDSAT-OLI-16D",
      tiles = tile_chunk,
      data_dir = cube_dir_y2,
      progress = FALSE
    )
    cube <- sits:::.merge_cube_densify(cube_y1, cube_y2)

    message("- classifying (probabilities)")
    probs <- tryCatch(sits_classify(
      data       = cube,
      ml_model   = model,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = version
    ), error = function(e) {
      message("error when classifying tile(s)")
      message(conditionMessage(e))
      NULL
    })

    if (is.null(probs)) {
      next
    }

    message("- smoothing")
    bayes <- sits_smooth(
      cube       = probs,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = version
    )

    message("- labeling")
    class <- sits_label_classification(
      cube       = bayes,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = version
    )
  }
}
#
# message("- mosaicking")
#
mosaic_dir <- file.path(output_dir, "mosaic")
crs_bdc <- paste0(readLines("~/r+/bdc.prj"), collapse = "\n")
dir.create(mosaic_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(mosaic_dir))

labels <- sits_labels(class)

class <- sits_cube(
  source     = "BDC",
  collection = "LANDSAT-OLI-16D",
  data_dir   = output_dir,
  tiles      = cerrado_tiles,
  bands      = "class",
  labels     = labels,
  version    = version,
  progress   = FALSE
)

mosaic_cube <- sits_mosaic(
  cube       = class,
  crs        = crs_bdc,
  multicores = multicores,
  output_dir = mosaic_dir,
  version    = version
)

message("- warnings")
print(warnings())
