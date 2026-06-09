set.seed(777)

library(sits)

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
segments_dir <- file.path(base_dir, "segments")
classifications_dir <- file.path(base_dir, "classifications")
dir.create(classifications_dir, recursive = TRUE, showWarnings = FALSE)

# Setup versions
model_version <- "rf-cer-v4a-som-clear"
segmentation_version <- "hex-s15-c04-p00"
version <- paste0(model_version, "-", segmentation_version)

# Setup years
years <- c(2018) # ou 2015:2022

# Hardware
multicores <- 96L
memsize <- 380

# Setup parallel cluster
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

# Define processing chunks
chunk_size <- 8L
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

# Load model
model_file <- file.path(models_dir, paste0(model_version, ".rds"))
model <- readRDS(model_file)

#
# Year loop
#
for (year in years) {
  # Input cube dir for this year
  cube_dir <- file.path(cubes_dir, as.character(year))

  # Segments dir for this year/version
  segs_dir <- file.path(segments_dir, segmentation_version, as.character(year))

  # Output classification dir for this year/version
  output_dir <- file.path(classifications_dir, version, as.character(year))
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Chunk-of-tiles: sits will resume using output_dir
  for (tile_chunk in tiles) {
    message("Year ", year, " | tile(s) ", paste(tile_chunk, collapse = ", "))

    message("- loading cube")
    cube <- sits_cube(
      source     = "BDC",
      collection = "LANDSAT-OLI-16D",
      tiles      = tile_chunk,
      data_dir   = cube_dir,
      progress   = FALSE
    )

    message("- attaching segments")
    cube_seg <- sits_cube(
      source      = "BDC",
      collection  = "LANDSAT-OLI-16D",
      raster_cube = cube,
      vector_dir  = segs_dir,
      vector_band = "segments",
      multicores  = multicores,
      version     = segmentation_version,
      progress    = FALSE
    )

    message("- classifying (probabilities)")
    probs <- sits_classify(
      data       = cube_seg,
      ml_model   = model,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = version
    )

    message("- labeling")
    class <- sits_label_classification(
      cube       = probs,
      multicores = multicores,
      memsize    = memsize,
      output_dir = output_dir,
      progress   = TRUE,
      version    = version
    )
  }
}

message("- warnings")
print(warnings())
