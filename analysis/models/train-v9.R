set.seed(777)

library(glue)
library(sits)

#
# Setup directory
#
base_dir <- file.path("~/classification-cerrado", "data", "derived")
samples_dir <- file.path(base_dir, "timeseries")
models_dir <- file.path(base_dir, "models")
dir.create(models_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(models_dir))

# Setup versions
model_method <- "tempcnn"
ml_method <- sits_tempcnn()
samples_version <- "cer-v10b"
model_version <- glue("{model_method}-{samples_version}")

# Samples
samples_file <- file.path(samples_dir, glue("samples-{samples_version}.rds"))
stopifnot(file.exists(samples_file))

# Model
model_file <- file.path(models_dir, glue("model-{model_version}.rds"))
acc_model_file <- file.path(models_dir, glue("model-{model_version}_acc.rds"))

if (!file.exists(model_file)) {
    message("- training")

    # Load samples
    samples <- readRDS(samples_file)

    # Train model
    model <- sits_train(
        samples = samples,
        ml_method = ml_method
    )

    # Save model
    saveRDS(model, model_file)
}

message("- cross-validation")

folds <- multicores <- 5L
acc_model <- sits_kfold_validate(
    samples,
    folds = folds,
    ml_method = ml_method,
    multicores = multicores,
    progress = TRUE
)

saveRDS(acc_model, acc_model_file)
