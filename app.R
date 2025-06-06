# app.R - Dashboard Landsadvocaat
# ================================

# Main entry point for the Shiny application
# This file is automatically detected by RStudio and Shiny Server

# =============================================================================
# SETUP
# =============================================================================

# Check if we're in the right directory
if (!file.exists("global.R")) {
  stop("app.R must be run from the project root directory where global.R is located")
}

# Load global configuration and functions
source("global.R")

# Check if UI and Server files exist
if (!file.exists("ui.R")) {
  stop("ui.R file not found. Please create ui.R before running the app.")
}

if (!file.exists("server.R")) {
  stop("server.R file not found. Please create server.R before running the app.")
}

# Load UI and Server
source("ui.R")
source("server.R")

# =============================================================================
# APPLICATION OPTIONS
# =============================================================================

# Shiny options
options(
  # File upload
  shiny.maxRequestSize = MAX_FILE_SIZE,
  
  # Disable autoreload in production
  shiny.autoreload = FALSE,
  
  # Sanitize errors in production
  shiny.sanitize.errors = FALSE,  # Set to TRUE in production
  # 
  # Spinner settings
  # spinner.color = "#154273",
  spinner.type = 8,
  
  # DT options
  DT.options = list(
    pageLength = DEFAULT_ITEMS_PER_PAGE,
    language = list(
      search = "Zoeken:",
      lengthMenu = "Toon _MENU_ items per pagina",
      info = "Toont _START_ tot _END_ van _TOTAL_ items",
      infoEmpty = "Geen items beschikbaar",
      infoFiltered = "(gefilterd van _MAX_ totaal items)",
      paginate = list(
        first = "Eerste",
        last = "Laatste", 
        # `next` = "Volgende",
        previous = "Vorige"
      )
    )
  )
)

# =============================================================================
# APP STARTUP MESSAGES
# =============================================================================

cli_h1("Dashboard Landsadvocaat v{APP_VERSION}")
cli_ul(c(
  "Database: {.path {normalizePath(DB_PATH)}}",
  "Max upload: {.val {format(MAX_FILE_SIZE / 1024^2, digits = 1)}} MB",
  "Theme: {.pkg bslib} met overheidshuisstijl",
  "Status: {.emph Ready to start}"
))
cli_rule()

# =============================================================================
# LAUNCH APPLICATION
# =============================================================================

# Create and run the Shiny app
shinyApp(
  ui = ui,
  server = server,
  options = list(
    # Host and port (can be overridden by deployment)
    host = "127.0.0.1",
    port = NULL,  # Let Shiny choose available port
    
    # Display options
    launch.browser = TRUE,
    
    # App title for browser tab
    title = APP_TITLE
  )
)