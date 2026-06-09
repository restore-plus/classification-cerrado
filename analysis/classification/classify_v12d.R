set.seed(777)

library(glue)
library(sits)

source(normalizePath("~/r+/lulcbr-publish.R"))

#
# Tiles of Cerrado
#
cerrado_tiles <- c(
  "007009", "008009", "008010", "009009", "009010", "009011", "009013", "009014",
  "010009", "010010", "010011", "010012", "010013", "010014", "010015", "011009",
  "011010", "011011", "011012", "011013", "011014", "011015", "012008", "012009",
  "012010", "012011", "012012", "012013", "012014", "012015", "013006", "013007",
  "013008", "013009", "013010", "013011", "013012", "013013", "013014", "013015",
  "014005", "014006", "014007", "014008", "014009", "014010", "014011", "014012",
  "014013", "014014", "014015", "015005", "015006", "015007", "015008", "015009",
  "015010", "015011", "015012", "015013", "015014", "016004", "016005", "016006",
  "016007", "016008", "016009", "016010", "016011", "016012", "016013", "017004",
  "017005", "017006", "017007", "017010", "017011"
)

#
# Setup directory
#
base_dir <- file.path("data", "derived")
cubes_dir <- file.path(base_dir, "cubes")

models_dir <- file.path(base_dir, "models")
classifications_dir <- file.path(base_dir, "classifications")

dir.create(classifications_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(classifications_dir))

#
# Setup versions
#
publication_version <- "v12d"
model_version <- glue("rfor-cer-{publication_version}")
raster_version <- "raster"
classification_version <- glue("{model_version}-{raster_version}")

#
# Setup years
#
years <- c(2018) # ou 2015:2022
start_year_offset <- 1L # 1L para classificação com 2 anos; 0L para classificação com 1 ano

#
# Hardware
#
multicores <- 31L
memsize <- 124

#
# Setup parallel cluster
#
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

#
# Define processing chunks
#
chunk_size <- 7L
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

#
# Load model
#
model_file <- file.path(models_dir, glue("model-{model_version}.rds"))
model <- readRDS(model_file)

#
# Year loop
#
for (year in years) {
  # Input cube dir for this year
  start_year <- year - start_year_offset
  end_year <- year

  cube_dir_y1 <- file.path(cubes_dir, as.character(start_year))
  cube_dir_y2 <- file.path(cubes_dir, as.character(end_year))

  # Output classification dir for this year/version
  output_dir <- file.path(classifications_dir, classification_version, as.character(end_year))

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(dir.exists(output_dir))

  # Chunk-of-tiles: sits will resume using output_dir
  for (tile_chunk in tiles) {
    message("Year ", end_year, " | tile(s) ", paste(tile_chunk, collapse = ", "))

    message("- loading cube")
    cube_y1 <- sits_cube(
      source     = "BDC",
      collection = "LANDSAT-OLI-16D",
      tiles      = tile_chunk,
      data_dir   = cube_dir_y1,
      progress   = FALSE
    )

    if (start_year == end_year) {
      cube_2y <- cube_y1
    } else {
      cube_y2 <- sits_cube(
        source     = "BDC",
        collection = "LANDSAT-OLI-16D",
        tiles      = tile_chunk,
        data_dir   = cube_dir_y2,
        progress   = FALSE
      )

      cube_2y <- sits_merge(cube_y1, cube_y2)
    }

    message("- classifying (probabilities)")
    probs <- tryCatch(sits_classify(
      data       = cube_2y,
      ml_model   = model,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = classification_version
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
      version    = classification_version
    )

    message("- uncertainty")
    class <- sits_uncertainty(
      cube       = bayes,
      type       = "margin",
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      version    = classification_version,
      progress   = TRUE
    )

    message("- labeling")
    class <- sits_label_classification(
      cube       = bayes,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = classification_version
    )
  }

  #
  # Prepare mosaic
  #
  mosaic_dir <- file.path(output_dir, "mosaic")
  crs_bdc <- paste0(readLines("~/r+/bdc.prj"), collapse = "\n")

  dir.create(mosaic_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(dir.exists(mosaic_dir))
  stopifnot(exists("class"))

  labels <- sits_labels(class)

  class_cube <- sits_cube(
    source     = "BDC",
    collection = "LANDSAT-OLI-16D",
    data_dir   = output_dir,
    tiles      = cerrado_tiles,
    bands      = "class",
    labels     = labels,
    version    = classification_version,
    progress   = FALSE
  )

  message("- mosaicking classification")
  mosaic_class <- sits_mosaic(
    cube       = class_cube,
    crs        = crs_bdc,
    multicores = multicores,
    output_dir = mosaic_dir,
    version    = classification_version
  )

  uncert_cube <- sits_cube(
    source     = "BDC",
    collection = "LANDSAT-OLI-16D",
    data_dir   = output_dir,
    tiles      = cerrado_tiles,
    bands      = "margin",
    labels     = labels,
    version    = classification_version,
    progress   = FALSE
  )

  message("- mosaicking uncertainty")
  mosaic_uncert <- sits_mosaic(
    cube       = uncert_cube,
    crs        = crs_bdc,
    multicores = multicores,
    output_dir = mosaic_dir,
    version    = classification_version
  )

  #
  # Publish
  #
  message("- publish")
  publish_cer(
    start_year = start_year,
    end_year = end_year,
    publication_version = publication_version,
    model_version = model_version,
    raster_version = raster_version,
    upload = TRUE
  )
}

#
# Warnings
#
message("- warnings")
print(warnings())
