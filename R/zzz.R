# On load
.onAttach <- function(lib, pkg) {
  packageStartupMessage("Restore+ Package - Classification cerrado.")
  packageStartupMessage(paste0("Using restoreutils version: ", restoreutils::version()))
}
