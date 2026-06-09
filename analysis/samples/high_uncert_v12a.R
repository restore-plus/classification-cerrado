set.seed(777)

library(glue)
library(sits)

#
# Tiles of Cerrado
#
cerrado_tiles <- c(
  "013008", "016005", "017004", "017005", "017006" # intersecting tiles
)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
cubes_dir <- file.path(base_dir, "cubes")
samples_dir <- file.path(base_dir, "timeseries")

# Setup versions
samples_version <- "cer-v12a"
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

# Get labels
labels <- sits_labels(samples)
names(labels) <- seq_along(labels)

# Setup year
year <- 2018
tile_chunk <- tiles[[1]]

classifications_dir <- file.path(base_dir, "classifications", paste0(model_version, "-raster"), year)

message("- loading class cube")
cube_class <- sits_cube(
  source = "BDC",
  collection = "LANDSAT-OLI-16D",
  data_dir = classifications_dir,
  tiles = tile_chunk,
  bands = "class",
  labels = labels,
  version = version
)

# Find samples with high uncertainty
message("- finding samples")
new_samples <- sits_stratified_sampling(
  cube = cube_class,
  samples_per_class = 5000,
  multicores = multicores,
  memsize = 2L,
  progress = TRUE
)
saveRDS(new_samples, uncert_file)

message("- loading ext-maps")
tc <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/tc/cer/boundary/tc_30m_cer_2018-01-01_2018-12-31_class_boundary.tif", vsi = TRUE)
names(tc) <- "tc_boundary_2018"

natveg <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/natveg/cer/v2/natveg_30m_cer_2018-01-01_2018-12-31_class_v2.tif", vsi = TRUE)
names(natveg) <- "natveg_v2_2018"

mapbiomas <- terra::rast("https://restore-plus.s3.us-east-1.amazonaws.com/ext-maps/mb/br/original/mb_30m_br_2018-01-01_2018-12-31_class_original.tif", vsi = TRUE)
names(natveg) <- "mb_original_2018"


# ---- tc ----
points <- terra::project(
  terra::vect(
    x = new_samples
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
new_samples <- new_samples[!is.na(tc_vals), ]

new_samples$tc_class <- unlist(
  tc_labels[paste0(tc_vals[!is.na(tc_vals)])],
  use.names = FALSE
)

saveRDS(new_samples, file = uncert_file)
new_samples <- readRDS(uncert_file)

# ---- natveg ----

points <- terra::project(
  terra::vect(
    x = new_samples
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
new_samples <- new_samples[!is.na(natveg_vals), ]

new_samples$natveg_class <- unlist(
  natveg_labels[paste0(natveg_vals[!is.na(natveg_vals)])],
  use.names = FALSE
)

saveRDS(new_samples, file = uncert_file)

# ---- mapbiomas ----

points <- terra::project(
  terra::vect(
    x = new_samples
  ),
  terra::crs(mapbiomas)
)

mb_labels <- list(
  `3` = "form_flor",
  `4` = "form_savanica",
  `5` = "mangue",
  `6` = "flor_alagavel",
  `9` = "silvicultura",
  `11` = "campo_alag_area_pantanosa",
  `12` = "form_campestre",
  `15` = "pastagem",
  `20` = "cana",
  `21` = "mosaico_usos",
  `23` = "praia_duna_areal",
  `24` = "area_urbanizada",
  `25` = "outras_areas_nao_vegetadas",
  `29` = "afloramento_rochoso",
  `30` = "mineracao",
  `31` = "aquicultura",
  `32` = "apicum",
  `33` = "rio_lago_oceano",
  `35` = "dende",
  `39` = "soja",
  `40` = "arroz",
  `41` = "outras_lavouras_temporarias",
  `46` = "cafe",
  `47` = "citrus",
  `48` = "outras_lavouras_perenes",
  `49` = "restinga_arborea",
  `50` = "restinga_herbacea",
  `62` = "algodao",
  `75` = "usina_fotovoltaica"
)

mb_vals <- terra::extract(mapbiomas, points, ID = FALSE)

new_samples <- new_samples[!is.na(mb_vals), ]

new_samples$mb_class <- unlist(
  mb_labels[paste0(mb_vals[!is.na(mb_vals)])],
  use.names = FALSE
)

saveRDS(new_samples, file = uncert_file)

vect_file <- sub("\\.rds$", ".gpkg", uncert_file)
new_samples <- new_samples[
  new_samples$label == "Silviculture" &
    (new_samples$tc_class == "veg_nat_primaria" |
      new_samples$mb_class == "silvicultura"),
]
new_samples$selected <- "Y"
sf::st_write(
  new_samples,
  vect_file,
  append = FALSE
)
