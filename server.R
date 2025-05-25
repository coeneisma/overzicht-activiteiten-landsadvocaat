# server.R - Dashboard Landsadvocaat
# ===================================

# Load modules
source("modules/login/login_server.R")
source("modules/filters/filters_server.R")

# =============================================================================
# SERVER FUNCTION
# =============================================================================

server <- function(input, output, session) {
  
  # Enable bookmarking
  enableBookmarking(store = "url")
  
  # =========================================================================
  # GLOBAL REACTIVE VALUES
  # =========================================================================
  
  # Data refresh trigger (incremented when data changes)
  data_refresh_trigger <- reactiveVal(0)
  
  # =========================================================================
  # LOGIN MODULE
  # =========================================================================
  
  # Initialize login module
  login_result <- login_server("login")
  
  # =========================================================================
  # AUTHENTICATION OUTPUTS
  # =========================================================================
  
  # Main authentication status (used by conditionalPanel in UI)
  output$user_authenticated <- reactive({
    login_result$authenticated()
  })
  outputOptions(output, "user_authenticated", suspendWhenHidden = FALSE)
  
  # Admin status check
  output$user_is_admin <- reactive({
    login_result$is_admin()
  })
  outputOptions(output, "user_is_admin", suspendWhenHidden = FALSE)
  
  # Current user display name
  output$current_user_display <- renderText({
    req(login_result$authenticated())
    login_result$user_display_name()
  })
  
  # =========================================================================
  # DATA LOADING (only when authenticated)
  # =========================================================================
  
  # Load raw data from database (reactive to changes)
  raw_data <- reactive({
    req(login_result$authenticated())
    
    # Trigger refresh when data changes
    data_refresh_trigger()
    
    # Load data from database
    tryCatch({
      lees_zaken()
    }, error = function(e) {
      cli_alert_danger("Error loading data: {e$message}")
      show_notification("Fout bij laden data", type = "error")
      data.frame() # Return empty data frame on error
    })
  })
  
  # =========================================================================
  # SIDEBAR STATISTICS
  # =========================================================================
  
  # Total number of cases (filtered)
  output$stats_total_zaken <- renderText({
    req(login_result$authenticated())
    data <- filtered_data()
    if (nrow(data) == 0) return("0")
    
    # Exclude deleted cases
    active_data <- data[data$status_zaak != "Verwijderd", ]
    format(nrow(active_data), big.mark = ".")
  })
  
  # Number of open cases (filtered)
  output$stats_open_zaken <- renderText({
    req(login_result$authenticated())
    data <- filtered_data()
    if (nrow(data) == 0) return("0")
    
    open_cases <- sum(data$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE)
    format(open_cases, big.mark = ".")
  })
  
  # =========================================================================
  # FILTER MODULE
  # =========================================================================
  
  # Initialize filter module (always, but data only loads after login)
  filter_result <- filters_server("filters", raw_data, data_refresh_trigger)
  
  # Get filtered data
  filtered_data <- filter_result$filtered_data
  
  # =========================================================================
  # MAIN NAVIGATION ACTIONS
  # =========================================================================
  
  # Logout button
  observeEvent(input$btn_logout, {
    cli_alert_info("Logout requested by user")
    login_result$logout()
  })
  
  # Nieuwe zaak button (placeholder)
  observeEvent(input$btn_nieuwe_zaak, {
    show_notification("Nieuwe zaak functie wordt binnenkort toegevoegd", type = "message")
  })
  
  # Export button (placeholder)
  observeEvent(input$btn_export, {
    show_notification("Export functie wordt binnenkort toegevoegd", type = "message")
  })
  
  # =========================================================================
  # TAB CONTENT PLACEHOLDERS
  # =========================================================================
  
  # Dashboard tab - show when user switches to it
  observeEvent(input$main_navbar, {
    if (input$main_navbar == "tab_dashboard" && login_result$authenticated()) {
      cli_alert_info("User navigated to Dashboard tab")
    }
  })
  
  # Zaakbeheer tab
  observeEvent(input$main_navbar, {
    if (input$main_navbar == "tab_zaakbeheer" && login_result$authenticated()) {
      cli_alert_info("User navigated to Zaakbeheer tab")
    }
  })
  
  # Export tab  
  observeEvent(input$main_navbar, {
    if (input$main_navbar == "tab_export" && login_result$authenticated()) {
      cli_alert_info("User navigated to Export tab")
    }
  })
  
  # Instellingen tab (admin only)
  observeEvent(input$main_navbar, {
    if (input$main_navbar == "tab_instellingen" && login_result$authenticated()) {
      if (login_result$is_admin()) {
        cli_alert_info("Admin user navigated to Instellingen tab")
      } else {
        cli_alert_warning("Non-admin user attempted to access Instellingen tab")
      }
    }
  })
  
  # =========================================================================
  # ERROR HANDLING & DEBUGGING
  # =========================================================================
  
  # Global error handler
  options(shiny.error = function() {
    cli_alert_danger("Shiny error occurred")
    show_notification("Er is een onverwachte fout opgetreden", type = "error")
  })
  
  # Session end cleanup
  session$onSessionEnded(function() {
    cli_alert_info("User session ended")
  })
  
  # =========================================================================
  # DEVELOPMENT HELPERS
  # =========================================================================
  
  # Show user info in console (development only)
  observe({
    if (login_result$authenticated()) {
      cli_rule("User Session Info")
      cli_li("User: {login_result$user()}")
      cli_li("Role: {login_result$user_role()}")
      cli_li("Display name: {login_result$user_display_name()}")
      cli_li("Is admin: {login_result$is_admin()}")
      cli_li("Data rows: {nrow(raw_data())}")
    }
  }) %>% bindEvent(login_result$authenticated(), ignoreInit = TRUE)
  
  # Data refresh function (for future modules to trigger)
  refresh_data <- function() {
    cli_alert_info("Data refresh triggered")
    data_refresh_trigger(data_refresh_trigger() + 1)
  }
  
  # =========================================================================
  # RETURN VALUES FOR MODULES
  # =========================================================================
  
  # Return list of reactive values and functions that modules can use
  # (This will be used when we add more modules)
  return(list(
    # Authentication
    user_authenticated = login_result$authenticated,
    current_user = login_result$user,
    user_role = login_result$user_role,
    is_admin = login_result$is_admin,
    
    # Data
    raw_data = raw_data,
    refresh_data = refresh_data,
    
    # Utilities
    show_notification = show_notification
  ))
}