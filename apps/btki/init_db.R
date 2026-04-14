# One-time script: Generate credentials.sqlite with the same passphrase
# Recommended: Set environment variable SM_PASSPHRASE in your system (don't hardcode passphrase)
# macOS/Linux:  export SM_PASSPHRASE="$(openssl rand -base64 32)"
# Windows PS:   $env:SM_PASSPHRASE=[System.Convert]::ToBase64String((1..32 | % {Get-Random -Max 256}))
# If SM_PASSPHRASE is not set, a default passphrase will be used automatically

if (!requireNamespace("shinymanager", quietly = TRUE)) install.packages("shinymanager")
library(shinymanager)

passphrase <- Sys.getenv("SM_PASSPHRASE")
if (!nzchar(passphrase)) {
  passphrase <- "default_passphrase_change_in_production"
  message("SM_PASSPHRASE not set, using default passphrase. For production, please set SM_PASSPHRASE environment variable.")
}

users <- data.frame(
  user     = c("admin", "demo", "Novartis"),
  password = c("Admin#123", "Demo#123", "Novartis#123"),
  admin    = c(TRUE, FALSE, FALSE),
  stringsAsFactors = FALSE
)

sqlite_path <- "credentials.sqlite"
if (file.exists(sqlite_path)) {
  message("Detected existing ", sqlite_path, ", will overwrite and rebuild (old users will be lost).")
  file.remove(sqlite_path)
}

shinymanager::create_db(
  credentials_data = users,
  sqlite_path      = sqlite_path,
  passphrase       = passphrase
)

info <- file.info(sqlite_path)
message("Created ", normalizePath(sqlite_path), " (size: ", info$size, " bytes)")