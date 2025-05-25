# modules/login/login_server.R
# ============================

#' Login Module Server
#' 
#' Handles user authentication against the database
#' 
#' @param id Module namespace ID
#' @param db_path Path to SQLite database
#' @return List with reactive values for authentication state and user info
login_server <- function(id) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES
    # ========================================================================
    
    # Authentication state
    authenticated <- reactiveVal(FALSE)
    login_failed <- reactiveVal(FALSE)
    
    # User information
    current_user <- reactiveVal(NULL)
    current_user_role <- reactiveVal(NULL)
    current_user_full_name <- reactiveVal(NULL)
    
    # Login attempt tracking (simple rate limiting)
    login_attempts <- reactiveVal(0)
    last_attempt_time <- reactiveVal(Sys.time())
    
    # ========================================================================
    # OUTPUTS FOR UI CONDITIONALS
    # ========================================================================
    
    # Login failed state (for conditional error message)
    output$login_failed <- reactive({
      login_failed()
    })
    outputOptions(output, "login_failed", suspendWhenHidden = FALSE)
    
    # Production mode indicator (for demo credentials display)
    output$production_mode <- reactive({
      # You can set this based on environment or config
      FALSE  # Set to TRUE in production to hide demo credentials
    })
    outputOptions(output, "production_mode", suspendWhenHidden = FALSE)
    
    # ========================================================================
    # LOGIN LOGIC
    # ========================================================================
    
    # Handle login button click
    observeEvent(input$login_btn, {
      
      # Reset previous error state
      login_failed(FALSE)
      
      # Validate inputs
      req(input$gebruikersnaam, input$wachtwoord)
      
      # Simple rate limiting - prevent rapid login attempts
      current_time <- Sys.time()
      if (difftime(current_time, last_attempt_time(), units = "secs") < 1) {
        show_notification("Te snel achter elkaar. Wacht even.", type = "warning")
        return()
      }
      
      last_attempt_time(current_time)
      login_attempts(login_attempts() + 1)
      
      # Show loading state
      updateActionButton(session, "login_btn", 
                         label = "Inloggen...", 
                         icon = icon("spinner", class = "fa-spin"))
      
      # Attempt authentication
      tryCatch({
        
        # Connect to database and check credentials
        auth_result <- controleer_login(input$gebruikersnaam, input$wachtwoord)
        
        if (auth_result) {
          # Successful login
          cli_alert_success("Gebruiker {input$gebruikersnaam} succesvol ingelogd")
          
          # Get user details from database
          con <- get_db_connection(DB_PATH)
          user_info <- tbl_gebruikers(con) %>%
            filter(gebruikersnaam == !!input$gebruikersnaam) %>%
            collect()
          close_db_connection(con)
          
          # Set user state
          authenticated(TRUE)
          current_user(input$gebruikersnaam)
          current_user_role(user_info$rol[1])
          current_user_full_name(user_info$volledige_naam[1])
          
          # Reset login attempts
          login_attempts(0)
          
          # Show success notification
          show_notification(
            paste("Welkom,", 
                  ifelse(is.na(user_info$volledige_naam[1]), 
                         input$gebruikersnaam, 
                         user_info$volledige_naam[1])),
            type = "message"
          )
          
          # Clear form
          updateTextInput(session, "gebruikersnaam", value = "")
          updateTextInput(session, "wachtwoord", value = "")
          
        } else {
          # Failed login
          cli_alert_danger("Inlogpoging mislukt voor gebruiker: {input$gebruikersnaam}")
          
          login_failed(TRUE)
          
          # Clear password field for security
          updateTextInput(session, "wachtwoord", value = "")
          
          # Auto-hide error after 4 seconds
          invalidateLater(4000)
          observe({
            login_failed(FALSE)
          })
          
          # Show notification
          show_notification("Inloggen mislukt. Controleer uw gegevens.", type = "warning")
        }
        
      }, error = function(e) {
        # Database or other error
        cli_alert_danger("Login error: {e$message}")
        
        login_failed(TRUE)
        show_notification("Er is een fout opgetreden. Probeer opnieuw.", type = "warning")
        
        # Auto-hide error
        invalidateLater(4000)
        observe({
          login_failed(FALSE)
        })
      })
      
      # Reset button state
      updateActionButton(session, "login_btn", 
                         label = "Inloggen", 
                         icon = icon("sign-in-alt"))
    })
    
    # ========================================================================
    # KEYBOARD SHORTCUTS
    # ========================================================================
    
    # Note: Keyboard shortcuts temporarily disabled
    # TODO: Add back after shinyjs is properly configured
    
    # ========================================================================
    # LOGOUT FUNCTIONALITY  
    # ========================================================================
    
    # Logout function (called from main app)
    logout <- function() {
      cli_alert_info("Gebruiker {current_user()} uitgelogd")
      
      authenticated(FALSE)
      current_user(NULL)
      current_user_role(NULL)
      current_user_full_name(NULL)
      login_failed(FALSE)
      login_attempts(0)
      
      show_notification("U bent uitgelogd", type = "message")
    }
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    # Return reactive values and functions for use by main app
    return(list(
      # Reactive values
      authenticated = authenticated,
      user = current_user,
      user_role = current_user_role,
      user_full_name = current_user_full_name,
      login_failed = login_failed,
      
      # Functions
      logout = logout,
      
      # Helper functions
      is_admin = reactive({
        current_user_role() == "admin"
      }),
      
      user_display_name = reactive({
        if (is.null(current_user_full_name()) || is.na(current_user_full_name()) || current_user_full_name() == "") {
          current_user()
        } else {
          current_user_full_name()
        }
      })
    ))
  })
}