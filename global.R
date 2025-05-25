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

# Visualization
library(plotly)
library(ggplot2)

# File handling
library(readxl)
library(writexl)

# Security
library(digest)

# Console output
library(cli)

# JavaScript functions
library(shinyjs)

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
# DATABASE FUNCTIONS
# =============================================================================

# Source database utilities
source("utils/database.R")

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
                          # Custom CSS rules
                          "
  .navbar-brand {
    font-weight: 600;
    font-size: 1.3em;
  }
  
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
  
  /* Loading spinner styling */
  .shiny-spinner-output-container {
    text-align: center;
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
  "
)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

#' Format currency values for display
format_currency <- function(x) {
  ifelse(is.na(x) | x == 0, 
         "€ 0", 
         paste0("€ ", format(x, big.mark = ".", decimal.mark = ",", digits = 0, nsmall = 0)))
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
# source("modules/data_management/data_management_ui.R") 
# source("modules/data_management/data_management_server.R")

# Analytics module
# source("modules/analytics/analytics_ui.R")
# source("modules/analytics/analytics_server.R")

# Export module
# source("modules/export/export_ui.R")
# source("modules/export/export_server.R")

message("Dashboard Landsadvocaat - Global configuration loaded")