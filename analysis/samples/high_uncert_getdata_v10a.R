set.seed(777)

library(glue)
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
base_dir <- file.path("~/classification-cerrado", "data", "derived")
cubes_dir <- file.path(base_dir, "cubes")
samples_dir <- file.path(base_dir, "timeseries")

# Setup versions
samples_version <- "cer-v10a"
model_version <- glue("tempcnn-{samples_version}")
raster_version <- "raster"
version <- glue("{model_version}-{raster_version}")

# Hardware
multicores <- 32L
memsize <- 128

# Setup parallel cluster
sits_parallel(workers = multicores, log = TRUE, output_dir = getwd())

# Define processing chunks
chunk_size <- length(cerrado_tiles)
tiles <- split(cerrado_tiles, ceiling(seq_along(cerrado_tiles) / chunk_size))

# Load samples
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))
samples <- readRDS(samples_file)
uncert_file <- file.path(samples_dir, glue("high_uncert-{samples_version}.rds"))
uncert_samples <- readRDS(uncert_file)
new_points_file <- file.path(samples_dir, glue("new_points-{samples_version}.rds"))

# Get labels
labels <- sits_labels(samples)
names(labels) <- seq_along(labels)

# Setup year
year <- 2018
tile_chunk <- tiles[[1]]
classifications_dir <- file.path(base_dir, "classifications", paste0(model_version, "-raster"), year)

message("- loading lulcbrasil cube")
cube_class <- sits_cube(
  source = "BDC",
  collection = "LANDSAT-OLI-16D",
  data_dir = classifications_dir,
  tiles = tile_chunk,
  bands = "class",
  labels = labels,
  version = version
)

message("- get data")
uncert_samples_class <- sits_get_class(
  cube = cube_class,
  samples = uncert_samples
)

saveRDS(uncert_samples_class, file = uncert_file)
uncert_samples_class <- readRDS(uncert_file)

message("- loading ext-maps")
tc <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/tc/cer/v1/tc_30m_cer_2018-01-01_2018-12-31_class_v1.tif", vsi = TRUE)
names(tc) <- "tc_v1_2018"

natveg <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/natveg/cer/v2/natveg_30m_cer_2018-01-01_2018-12-31_class_v2.tif", vsi = TRUE)
names(natveg) <- "natveg_v2_2018"

inv4 <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/4inv/cer/original/4inv_30m_cer_2016-01-01_2016-12-31_class_original.tif", vsi = TRUE)
names(inv4) <- "inv4_original_2016"


# ---- tc ----
points <- terra::project(
  terra::vect(
    x = uncert_samples_class,
    geom = c("longitude", "latitude"),
    crs = "EPSG:4326",
    keepgeom = TRUE
  ),
  terra::crs(tc)
)

tc_labels <- list(
  `1` = "veg_nat_primaria",
  `2` = "veg_nat_secundaria",
  `9` = "silvicultura",
  `11` = "pastagem",
  `12` = "agr_perene",
  `13` = "agr_semiperene",
  `14` = "agr_temp_1_ciclo",
  `15` = "agr_temp_mais_1_ciclo",
  `16` = "mineracao",
  `17` = "urbanizada",
  `20` = "outros_usos",
  `21` = "outras_areas_edific",
  `22` = "desflorest_ano",
  `23` = "corpo_dagua",
  `25` = "nao_observado"
)
tc_vals <- terra::extract(tc, points, ID = FALSE)
uncert_samples_class <- uncert_samples_class[!is.na(tc_vals), ]

uncert_samples_class$tc_class <- unlist(
  tc_labels[paste0(tc_vals[!is.na(tc_vals)])],
  use.names = FALSE
)

saveRDS(uncert_samples_class, file = uncert_file)
uncert_samples_class <- readRDS(uncert_file)

# ---- natveg ----

points <- terra::project(
  terra::vect(
    x = uncert_samples_class,
    geom = c("longitude", "latitude"),
    crs = "EPSG:4326",
    keepgeom = TRUE
  ),
  terra::crs(natveg)
)

natveg_labels <- list(
  `1` = "form_flor",
  `3` = "form_flor",
  `11` = "veg_nat_cerr_denso",
  `12` = "veg_nat_cerr_tipico",
  `13` = "veg_nat_cerr_ralo",
  `14` = "veg_nat_cerr_rup",
  `15` = "veg_nat_pq_cerr",
  `17` = "veg_nat_babacual",
  `19` = "veg_nat_vereda",
  `21` = "campo_nat_sujo",
  `25` = "campo_nat_limpo",
  `29` = "campo_nat_rup",
  `32` = "corpos_dagua",
  `34` = "nao_obs",
  `37` = "desmat_ano",
  `38` = "duna",
  `39` = "flor_mangue",
  `40` = "flor_sav_estep_flor",
  `41` = "veg_nat_sav_estep_arb",
  `43` = "campo_nat_sav_estep_gram_lenh",
  `44` = "dep_fluvial",
  `51` = "antrop_form_flor",
  `53` = "antrop_form_flor",
  `61` = "antrop_veg_nat_cerr_denso",
  `62` = "antrop_veg_nat_cerr_tipico",
  `63` = "antrop_veg_nat_cerr_ralo",
  `64` = "antrop_veg_nat_cerr_rup",
  `65` = "antrop_veg_nat_pq_cerr",
  `67` = "antrop_veg_nat_babacual",
  `69` = "antrop_veg_nat_vereda",
  `71` = "antrop_campo_nat_sujo",
  `75` = "antrop_campo_nat_limpo",
  `79` = "antrop_campo_nat_rup",
  `81` = "antrop_area_antrop",
  `82` = "antrop_corpos_dagua",
  `84` = "antrop_nao_obs",
  `87` = "antrop_desmat_ano",
  `88` = "antrop_duna",
  `89` = "antrop_flor_mangue",
  `90` = "antrop_flor_sav_estep_flor",
  `91` = "antrop_veg_nat_sav_estep_arb",
  `93` = "antrop_campo_nat_sav_estep_gram_lenh",
  `94` = "antrop_dep_fluvial"
)
natveg_vals <- terra::extract(natveg, points, ID = FALSE)
uncert_samples_class <- uncert_samples_class[!is.na(natveg_vals), ]

uncert_samples_class$natveg_class <- unlist(
  natveg_labels[paste0(natveg_vals[!is.na(natveg_vals)])],
  use.names = FALSE
)

saveRDS(uncert_samples_class, file = uncert_file)
uncert_samples_class <- readRDS(uncert_file)

# ---- inv4 ----

points <- terra::project(
  terra::vect(
    x = uncert_samples_class,
    geom = c("longitude", "latitude"),
    crs = "EPSG:4326",
    keepgeom = TRUE
  ),
  terra::crs(inv4)
)

inv4_labels <- list(
  `1`  = "flor_man",
  `2`  = "flor_nao_man",
  `3`  = "flor_sec",
  `4`  = "flor_corte_sel",
  `5`  = "silvicultura",
  `6`  = "agr_anual",
  `7`  = "agr_semiperene",
  `8`  = "agr_perene",
  `9`  = "pastagem",
  `10` = "pastagem_degrad",
  `11` = "campo_man",
  `12` = "campo_nao_man",
  `13` = "campo_sec",
  `14` = "outras_form_lenh_man",
  `15` = "outras_form_lenh_nao_man",
  `16` = "outras_form_lenh_sec",
  `17` = "corpo_dagua",
  `18` = "reservatorio",
  `19` = "assentamento",
  `20` = "duna_man",
  `21` = "duna_nao_man",
  `22` = "aflor_rochoso_man",
  `23` = "aflor_rochoso_nao_man",
  `24` = "mineracao",
  `25` = "solo_exposto",
  `26` = "nao_observado"
)

inv4_vals <- terra::extract(inv4, points, ID = FALSE)
uncert_samples_class <- uncert_samples_class[!is.na(inv4_vals), ]

uncert_samples_class$inv4_class <- unlist(
  inv4_labels[paste0(inv4_vals[!is.na(inv4_vals)])],
  use.names = FALSE
)

saveRDS(uncert_samples_class, file = uncert_file)
uncert_samples_class <- readRDS(uncert_file)

# ---- end ----

# points <- terra::project(
#   terra::vect(
#     x = uncert_samples_class,
#     geom = c("longitude", "latitude"),
#     crs = "EPSG:4326",
#     keepgeom = TRUE
#   ),
#   "EPSG:4326"
# )
#
# terra::writeVector(points, sub("\\.rds", ".gpkg", uncert_file), overwrite = TRUE)
#
# # ---- new points ----
#
# uncert_samples_class |>
#   dplyr::filter(label == "Perennial_Crop") |>
#   dplyr::count(tc_class, natveg_class) |>
#   print(n = 100)
#
#
# uncert_samples_class |>
#   dplyr::filter(label == "Perennial_Crop") |>
#   dplyr::count(tc_class)
#
# # Cerradao
# new_cerradao <- uncert_samples_class |>
#   dplyr::filter(label == "Perennial_Crop") |>
#   dplyr::filter(tc_class == "veg_nat_primaria") |>
#   dplyr::filter(natveg_class == "form_flor") |>
#   dplyr::mutate(label = "Cerradao")
#
# # Pasture
# new_pasture <- uncert_samples_class |>
#   dplyr::filter(label == "Perennial_Crop") |>
#   dplyr::filter(tc_class == "pastagem") |>
#   dplyr::mutate(label = "Pasture")
#
# new_points <- dplyr::bind_rows(list(new_cerradao, new_pasture))
#
# saveRDS(new_points, file = new_points_file)
# new_points <- readRDS(new_points_file)
#
# # Get data
# message("- loading cube")
# cube_y1_dir <- file.path(cubes_dir, "2017")
# cube_y2_dir <- file.path(cubes_dir, "2018")
# cube_y1 <- sits_cube(
#   source     = "BDC",
#   collection = "LANDSAT-OLI-16D",
#   tiles      = cerrado_tiles,
#   data_dir   = cube_y1_dir,
#   progress   = FALSE
# )
# cube_y2 <- sits_cube(
#   source     = "BDC",
#   collection = "LANDSAT-OLI-16D",
#   tiles      = cerrado_tiles,
#   data_dir   = cube_y2_dir,
#   progress   = FALSE
# )
# cube_2y <- sits_merge(cube_y1, cube_y2)
#
# message("- extract ts")
# new_points <- sits_get_data(
#   cube = cube_2y,
#   samples = new_points,
#   multicores = multicores
# )
#
# saveRDS(new_points, new_points_file)
#
# v11a <- dplyr::bind_rows(list(new_points, samples))
#
# saveRDS(v11a, sub("v10a", "v11a", samples_file))
