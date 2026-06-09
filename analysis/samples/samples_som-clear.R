library(sits)

v4a <- readRDS(url("https://github.com/restore-plus/classification-cerrado/raw/refs/heads/main/data/derived/timeseries/samples-cer-v4a-complete.rds"))
som_v4a_40x40 <- sits::sits_som_map(
  data = v4a,
  grid_xdim = 40,
  grid_ydim = 40,
  alpha = 1,
  rlen = 100,
  distance = "dtw",
  som_radius = 2,
  mode = "batch"
)
saveRDS(som_v4a_40x40, "som_v4a_40x40.rds")

som_v4a_40x40 <- readRDS("som_v4a_40x40.rds")

plot(sits_som_evaluate_cluster(som_v4a_40x40))


library(dplyr)

neurons <- som_v4a_40x40$labelled_neurons |>
  dplyr::group_by(id_neuron) |>
  dplyr::slice_max(count, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::select(id_neuron, label_samples)

som_v4a_40x40$data <- som_v4a_40x40$data |>
  dplyr::left_join(neurons, by = "id_neuron")

v4a_clean <- som_v4a_40x40$data |>
  dplyr::filter(label == label_samples)

summary(v4a_clean)

saveRDS(v4a_clean, "v4a-som-clean.rds")

# simoes <- readRDS(url("https://github.com/restore-plus/classification-cerrado/raw/refs/heads/main/data/derived/timeseries/samples-simoes-original-complete.rds"))
#
# summary(simoes)
# som_simoes_40x40 <- sits::sits_som_map(
#     data = simoes,
#     grid_xdim = 40,
#     grid_ydim = 40,
#     alpha = 1,
#     rlen = 100,
#     distance = "dtw",
#     som_radius = 2,
#     mode = "batch"
# )
# saveRDS(som_simoes_40x40, "som_simoes_40x40.rds")
#
# natveg <- readRDS(url("https://github.com/restore-plus/classification-cerrado/raw/refs/heads/main/data/derived/timeseries/samples-simoes-natveg-complete.rds"))
# summary(natveg)
#
# jobs <- list(
#     list(samples = natveg, res = 20),
#     list(samples = natveg, res = 30),
#     list(samples = natveg, res = 40)
# )
#
# mirai::daemons(0)
#
# som_lst <- jobs |>
#     stream(function(job) {
#         library(sits)
#
#         samples <- job$samples
#         res <- job$res
#         sits::sits_som_map(
#             data = samples,
#             grid_xdim = res,
#             grid_ydim = res,
#             alpha = 1,
#             rlen = 100,
#             distance = "dtw",
#             som_radius = 2,
#             mode = "batch"
#         )
#     }, backend = mirai_backend()) |>
#     stream_run(1000)
#
# library(sits)
#
# som_simoes_40x40 <- readRDS("som_simoes_40x40.rds")
# som_natveg_40x40 <- readRDS("som_natveg_40x40.rds")
#
# legend <- tibble::tribble(
#     ~name,                                             ~color,
#     "Annual_Crop",                                     "#ffab00",
#     "Campo Natural (Campo Limpo)",                     "#0afb50",
#     "Campo Natural (Campo Rupestre)",                  "#9aff90",
#     "Campo Natural (Campo Sujo)",                      "#00bb20",
#     "Corpos d'Água",                                   "#1111bb",
#     "Floresta",                                        "#007700",
#     "Floresta (Savana-Estépica Florestada)",           "#888800",
#     "Formações Arenosas",                              "#ddab88",
#     "Pasture",                                         "#ffff00",
#     "Perennial_Crop",                                  "#993400",
#     "Silviculture",                                    "#117766",
#     "Sugarcane",                                       "#ab6096",
#     "Vegetação Natural (Babaçual)",                    "#80ff00",
#     "Vegetação Natural (Cerrado Denso)",               "#80ff00",
#     "Vegetação Natural (Cerrado Ralo)",                "#80ff00",
#     "Vegetação Natural (Cerrado Rupestre)",            "#80ff00",
#     "Vegetação Natural (Cerrado Típico)",              "#80ff00",
#     "Vegetação Natural (Parque de Cerrado)",           "#80ff00",
#     "Vegetação Natural (Savana-Estépica Arborizada)",  "#80ff00",
#     "Vegetação Natural (Vereda)",                      "#80ff00",
#     "No_Samples",                                      "#ababab"
# )
#
# plot(som_simoes_40x40, band = "NDVI", legend = legend)
# plot(som_natveg_40x40, band = "NDVI", legend = legend)
#
# plot(sits_som_evaluate_cluster(som_simoes_40x40), legend = legend)
# plot(sits_som_evaluate_cluster(som_natveg_40x40), legend = legend)
#
# nrow(som_simoes_40x40$labelled_neurons)
