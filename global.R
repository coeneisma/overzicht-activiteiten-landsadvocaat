# global.R - Dashboard Landsadvocaat
# ====================================

# =============================================================================
# LIBRARIES
# =============================================================================

# Core Shiny
library(shiny)
library(bslib)

# Data manipulation
library(DBI)
library(RSQLite)
library(dbplyr)
library(dplyr)
library(tidyr)

# UI components
library(DT)
library(shinyWidgets)
library(shinycssloaders)
library(sortable)

# Visualization
library(plotly)
library(ggplot2)
library(RColorBrewer)

# File handling
library(readxl)
library(writexl)

# String matching
library(stringdist)

# Security
library(digest)

# Console output
library(cli)

# JavaScript functions
library(shinyjs)

# Color picker (load after shinyjs to override colourInput)
library(colourpicker)

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

# App metadata
APP_TITLE <- "Dashboard Landsadvocaat"
APP_VERSION <- "1.0.0"

# Database configuratie
DB_PATH <- "data/landsadvocaat.db"

# File upload limits
MAX_FILE_SIZE <- 10 * 1024^2  # 10MB
ALLOWED_FILE_TYPES <- c("xlsx", "xls", "csv")

# Default filters
DEFAULT_ITEMS_PER_PAGE <- 25

# =============================================================================
# DATABASE MIGRATIONS CHECK
# =============================================================================

# Run database migrations on startup
if (file.exists("migrations/migrate.R")) {
  tryCatch({
    source("migrations/migrate.R")
    # Alleen uitvoeren in productie modus (niet tijdens development)
    if (!interactive() || Sys.getenv("RUN_MIGRATIONS") == "TRUE") {
      suppressMessages(run_migrations())
    }
  }, error = function(e) {
    warning("⚠️  Database migration check failed: ", e$message)
  })
}

# =============================================================================
# DATABASE FUNCTIONS
# =============================================================================

# Source database utilities
source("utils/database.R")

# Add resource path for media files
addResourcePath("media", "media")

# Test database connectivity at startup
tryCatch({
  con <- get_db_connection(DB_PATH)
  close_db_connection(con)
  message("✓ Database connectie succesvol")
}, error = function(e) {
  stop("❌ Database connectie mislukt: ", e$message, 
       "\nRun eerst: source('setup/fixed_initial_data.R'); complete_database_setup_fixed()")
})

# =============================================================================
# BSLIB THEME CONFIGURATION
# =============================================================================

# Hoofdthema voor de applicatie
app_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  
  # Kleuren gebaseerd op overheidshuisstijl
  primary = "#154273",      # Donkerblauw (overheid)
  secondary = "#767676",    # Grijs
  success = "#4caf50",      # Groen voor success
  info = "#2196f3",         # Blauw voor info
  warning = "#ff9800",      # Oranje voor warnings
  danger = "#f44336",       # Rood voor errors
  
  # Typography
  base_font = font_google("Source Sans Pro"),
  heading_font = font_google("Source Sans Pro", wght = "600"),
  code_font = font_google("Source Code Pro"),
  
  # Spacing
  "spacer" = "1rem"
)

# Theme customizations
app_theme <- bs_add_rules(app_theme, 
                          # STEP 1: Testing navbar styling only
                          "
  /* Navbar styling to match login screen */
  .navbar, .navbar-expand-lg, .navbar-light {
    background-color: #154273 !important;
    background: #154273 !important;
  }
  
  .navbar-brand, .navbar-nav .nav-link, .navbar-text {
    color: white !important;
  }
  
  .navbar-toggler {
    border-color: rgba(255, 255, 255, 0.3) !important;
  }
  
  /* Version number in navbar should be white */
  .navbar .nav-item .text-muted,
  .navbar .text-muted {
    color: white !important;
  }
  
  /* Basic UI improvements - should be safe */
  .sidebar {
    background-color: var(--bs-gray-50);
    border-right: 1px solid var(--bs-border-color);
  }

  .card {
    box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
    border: 1px solid rgba(0, 0, 0, 0.125);
  }

  .btn-primary {
    background-color: var(--bs-primary);
    border-color: var(--bs-primary);
  }

  .table th {
    background-color: var(--bs-gray-100);
    border-color: var(--bs-border-color);
    font-weight: 600;
  }

  .alert {
    border: none;
    border-radius: 0.375rem;
  }
  
  /* Modal improvements */
  .modal-header {
    background-color: var(--bs-primary);
    color: white;
    border-bottom: none;
  }

  .modal-header .btn-close {
    filter: brightness(0) invert(1);
  }

  /* Loading spinner styling */
  .shiny-spinner-output-container {
    text-align: center;
  }
  
  /* Fix scroll issues */
  html, body {
    overflow-x: hidden !important;
    overflow-y: auto !important;
    height: auto !important;
    min-height: 100vh;
  }

  .container-fluid {
    overflow: visible !important;
  }

  /* Ensure main content area is scrollable */
  .tab-content {
    overflow-y: auto !important;
    max-height: none !important;
  }

  /* Fix potential modal scroll blocking */
  .modal-open {
    overflow: hidden !important;
  }

  .modal-open .navbar,
  .modal-open .sidebar {
    filter: none !important;
  }
  
  /* Bulk Upload Wizard Styling */
  .progress-wizard {
    padding: 1rem 0;
  }
  
  .wizard-step {
    text-align: center;
    flex: 1;
    position: relative;
  }
  
  .wizard-step-circle {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    background-color: #e9ecef;
    color: #6c757d;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: bold;
    margin: 0 auto 0.5rem auto;
    transition: all 0.3s ease;
  }
  
  .wizard-step-circle.active {
    background-color: #154273 !important;
    color: white !important;
  }
  
  .wizard-step-circle.completed {
    background-color: #28a745 !important;
    color: white !important;
  }
  
  .wizard-step-label {
    font-size: 0.875rem;
    color: #6c757d;
    font-weight: 500;
  }
  
  .wizard-step.active .wizard-step-label {
    color: #154273 !important;
    font-weight: 600;
  }
  
  .wizard-step.completed .wizard-step-label {
    color: #28a745 !important;
    font-weight: 600;
  }
  
  /* Bulk Upload Corrections Layout Fixes */
  .corrections-card .selectize-dropdown {
    z-index: 1050 !important;
  }
  
  .corrections-card .form-check {
    margin-bottom: 0.5rem;
  }
  
  .corrections-card .d-flex.align-items-center {
    gap: 1rem;
  }
  
  .corrections-card .selectize-control {
    margin-bottom: 0;
  }
  
  /* Prevent card overflow issues - key fix */
  .corrections-card .card-body {
    overflow: visible !important;
  }
  
  .corrections-container {
    overflow: visible !important;
  }
  
  /* Ensure dropdowns appear above everything */
  .corrections-card .selectize-dropdown,
  .corrections-card .bootstrap-select .dropdown-menu {
    position: absolute !important;
    z-index: 1060 !important;
    box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15) !important;
  }
  
  /* Fix conditional panel positioning */
  .corrections-card .shiny-input-container {
    position: static !important;
  }
  ")

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Format currency values for display
format_currency <- function(x) {
  ifelse(is.na(x) | x == 0, 
         "€ 0", 
         paste0("€ ", format(x, big.mark = ".", decimal.mark = ",", nsmall = 0, scientific = FALSE)))
}

#' Format dates for display
format_date_nl <- function(x) {
  if (is.null(x) || all(is.na(x))) return("")
  format(as.Date(x), "%d-%m-%Y")
}

#' Create a notification with consistent styling
show_notification <- function(message, type = "message", duration = 3) {
  showNotification(
    message,
    type = type,
    duration = duration,
    closeButton = TRUE
  )
}

#' Validate file upload
validate_file_upload <- function(file_info) {
  if (is.null(file_info)) {
    return(list(valid = FALSE, message = "Geen bestand geselecteerd"))
  }
  
  # Check file size
  if (file_info$size > MAX_FILE_SIZE) {
    return(list(valid = FALSE, message = "Bestand is te groot (max 10MB)"))
  }
  
  # Check file extension
  ext <- tools::file_ext(file_info$name)
  if (!tolower(ext) %in% ALLOWED_FILE_TYPES) {
    return(list(valid = FALSE, message = paste("Bestandstype niet toegestaan. Gebruik:", paste(ALLOWED_FILE_TYPES, collapse = ", "))))
  }
  
  return(list(valid = TRUE, message = "Bestand is geldig"))
}

#' Create consistent value boxes
create_value_box <- function(title, value, subtitle = NULL, color = "primary", icon = NULL) {
  card_class <- paste0("border-", color)
  header_class <- paste0("bg-", color, " text-white")
  
  card_content <- div(
    class = "card",
    div(class = paste("card-header", header_class),
        h5(class = "card-title mb-0", title)
    ),
    div(class = "card-body text-center",
        h2(class = paste0("text-", color), value),
        if (!is.null(subtitle)) p(class = "text-muted mb-0", subtitle)
    )
  )
  
  return(card_content)
}

# =============================================================================
# REACTIVE VALUES INITIALIZATION
# =============================================================================

# Deze worden gebruikt door de modules
# (Hier alleen gedefineerd, worden geïnitialiseerd in server.R)

# Global reactive values structure:
# - user_authenticated: reactiveVal(FALSE)  
# - current_user: reactiveVal(NULL)
# - current_user_role: reactiveVal(NULL)
# - data_refresh_trigger: reactiveVal(0)
# - selected_filters: reactiveValues()

# =============================================================================
# STARTUP CHECKS
# =============================================================================

# Check if all required directories exist
required_dirs <- c("data", "utils", "modules")
for (dir in required_dirs) {
  if (!dir.exists(dir)) {
    warning("Directory '", dir, "' does not exist. Some features may not work.")
  }
}

# Check if database has data
tryCatch({
  con <- get_db_connection(DB_PATH)
  
  # Check for dropdown options
  dropdown_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM dropdown_opties")$n
  if (dropdown_count == 0) {
    warning("Database contains no dropdown options. Run the setup script first.")
  }
  
  # Check for users
  user_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM gebruikers")$n
  if (user_count == 0) {
    warning("Database contains no users. Run the setup script first.")
  }
  
  close_db_connection(con)
  
  message("✓ Database health check passed")
  message("✓ Global.R loaded successfully")
  
}, error = function(e) {
  warning("Database health check failed: ", e$message)
})

# =============================================================================
# MODULE LOADING
# =============================================================================

# Source all modules when they exist
# (Will be uncommented as modules are created)

# Login module
source("modules/login/login_ui.R")
source("modules/login/login_server.R")

# Filter module  
source("modules/filters/filters_ui.R")
source("modules/filters/filters_server.R")

# Data management module
tryCatch({
  source("modules/data_management/data_management_ui.R") 
  source("modules/data_management/data_management_server.R")
  message("✓ Data management module (minimal) loaded successfully")
}, error = function(e) {
  warning("❌ Error loading data management module: ", e$message)
  print(e)
})

# Instellingen module
tryCatch({
  source("modules/instellingen/instellingen_ui.R")
  source("modules/instellingen/instellingen_server.R")
  message("✓ Instellingen module loaded successfully")
}, error = function(e) {
  warning("❌ Error loading instellingen module: ", e$message)
  print(e)
})

# Analyse module
tryCatch({
  source("modules/analyse/analyse_ui.R")
  source("modules/analyse/analyse_server.R")
  message("✓ Analyse module loaded successfully")
}, error = function(e) {
  warning("❌ Error loading analyse module: ", e$message)
  print(e)
})

# Bulk Upload module
tryCatch({
  source("modules/bulk_upload/bulk_upload_ui.R")
  source("modules/bulk_upload/bulk_upload_server.R")
  message("✓ Bulk Upload module loaded successfully")
}, error = function(e) {
  warning("❌ Error loading bulk upload module: ", e$message)
  print(e)
})

# Export module
# source("modules/export/export_ui.R")
# source("modules/export/export_server.R")


message("Dashboard Landsadvocaat - Global configuration loaded")