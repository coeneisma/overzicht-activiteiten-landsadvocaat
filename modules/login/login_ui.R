# modules/login/login_ui.R
# ========================

#' Login Module UI
#' 
#' Creates a full-screen login overlay that appears when user is not authenticated
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with login form
login_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  # Login overlay with modal-style form
  conditionalPanel(
    condition = "!output.user_authenticated",
    
    # Full screen overlay
    div(
      id = ns("login_overlay"),
      style = "
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background-color: rgba(21, 66, 115, 0.9);
        z-index: 1050;
        display: flex;
        align-items: center;
        justify-content: center;
      ",
      
      # Login card
      div(
        class = "card shadow-lg",
        style = "width: 420px; max-width: 90vw; border: none;",
        
        # Card header with logo/title
        div(
          class = "card-header bg-primary text-white text-center py-4",
          style = "border: none;",
          
          # App logo/icon
          div(
            class = "mb-3",
            icon("shield-halved", class = "fa-3x")
          ),
          
          # Title
          h3(class = "mb-0 fw-bold", "Dashboard Landsadvocaat"),
          div(class = "opacity-75 small", "Ministerie van Onderwijs Cultuur en Wetenschap")
        ),
        
        # Card body with form
        div(
          class = "card-body p-4",
          
          # Form instructions
          div(
            class = "text-center mb-4",
            h5("Inloggen", class = "card-title"),
            div(class = "text-muted small", "Gebruik uw ministerie-inloggegevens")
          ),
          
          # Login form
          tags$form(
            id = ns("login_form"),
            
            # Username field
            div(
              class = "mb-3",
              div(
                class = "input-group",
                tags$span(
                  class = "input-group-text",
                  icon("user")
                ),
                textInput(
                  ns("gebruikersnaam"),
                  label = NULL,
                  placeholder = "Gebruikersnaam",
                  width = "100%"
                )
              )
            ),
            
            # Password field  
            div(
              class = "mb-4",
              div(
                class = "input-group",
                tags$span(
                  class = "input-group-text", 
                  icon("lock")
                ),
                passwordInput(
                  ns("wachtwoord"),
                  label = NULL,
                  placeholder = "Wachtwoord",
                  width = "100%"
                )
              )
            ),
            
            # Login button
            div(
              class = "d-grid mb-3",
              actionButton(
                ns("login_btn"),
                "Inloggen",
                class = "btn-primary btn-lg",
                icon = icon("sign-in-alt"),
                width = "100%"
              )
            )
          ),
          
          # Error message area
          conditionalPanel(
            condition = paste0("output['", ns("login_failed"), "'] == true"),
            div(
              class = "alert alert-danger text-center",
              icon("exclamation-triangle"), " ",
              div(class = "fw-bold", "Inloggen mislukt"),
              div("Controleer uw gebruikersnaam en wachtwoord")
            )
          ),
          
          # Demo credentials (only in development)
          conditionalPanel(
            condition = "!output.production_mode",
            div(
              class = "mt-4 p-3 bg-light rounded",
              h6("Demo Inloggegevens:", class = "text-muted"),
              div(
                class = "small text-muted",
                div(class = "fw-bold d-inline", "Admin:"), " admin / admin123",
                tags$br(),
                div(class = "fw-bold d-inline", "Test:"), " test / test123"
              )
            )
          )
        ),
        
        # Card footer
        div(
          class = "card-footer text-center text-muted py-3",
          style = "border: none; background: transparent;",
          div(
            class = "small",
            icon("info-circle"), " ",
            "Bij problemen contact opnemen met het OCW datalab"
          )
        )
      )
    )
  )
}