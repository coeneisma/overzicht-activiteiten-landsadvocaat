# ui.R - Dashboard Landsadvocaat  
# ===============================

# Load modules
source("modules/login/login_ui.R")
source("modules/filters/filters_ui.R")

# Initialize shinyjs
shinyjs::useShinyjs()

# =============================================================================
# USER INTERFACE DEFINITION
# =============================================================================

ui <- div(
  # ==========================================================================
  # LOGIN MODULE (outside navbar structure)
  # ==========================================================================
  
  login_ui("login"),
  
  # ==========================================================================
  # MAIN APPLICATION (only shown when authenticated)
  # ==========================================================================
  
  conditionalPanel(
    condition = "output.user_authenticated == true",
    
    page_navbar(
      title = APP_TITLE,
      theme = app_theme,
      id = "main_navbar",
      
      # Sidebar
      sidebar = sidebar(
        id = "main_sidebar",
        width = 320,
        
        # Quick stats
        card(
          card_header("Overzicht"),
          card_body(
            div(
              class = "row text-center",
              div(class = "col-4",
                  h4(textOutput("stats_total_all", inline = TRUE), class = "text-info"),
                  div("Totaal", class = "text-muted small")
              ),
              div(class = "col-4",
                  h4(textOutput("stats_total_zaken", inline = TRUE), class = "text-primary"),
                  div("Gefilterd", class = "text-muted small")
              ),
              div(class = "col-4", 
                  h4(textOutput("stats_open_zaken", inline = TRUE), class = "text-warning"),
                  div("Open", class = "text-muted small")
              )
            )
          )
        ),
        
        # Filter module
        filters_ui("filters"),
        
        hr(),
        
        # Logout button only
        div(
          class = "d-grid",
          actionButton("btn_logout", "Uitloggen", class = "btn-outline-danger", icon = icon("sign-out-alt"))
        )
      ),
      
      # ==========================================================================
      # MAIN CONTENT TABS
      # ==========================================================================
      
      # Zaakbeheer tab (moved to first position)
      nav_panel(
        title = "Zaakbeheer",
        icon = icon("folder-open"),
        value = "tab_zaakbeheer",
        
        div(
          class = "container-fluid p-4",
          data_management_ui("data_mgmt")
        )
      ),
      
      # Analyse tab
      nav_panel(
        title = "Analyse",
        icon = icon("chart-line"),
        value = "tab_analyse",
        
        div(
          class = "container-fluid p-4",
          analyse_ui("analyse")
        )
      ),
      
      # Instellingen tab (admin only)
      nav_panel(
        title = "Instellingen",
        icon = icon("cog"),
        value = "tab_instellingen",
        
        div(
          class = "container-fluid p-4",
          
          # Show settings - alle gebruikers hebben toegang tot instellingen
          instellingen_ui("instellingen")
        )
      ),
      
      # ==========================================================================
      # FOOTER
      # ==========================================================================
      
      nav_spacer(),
      nav_item(
        tags$small(class = "text-muted", paste("Dashboard Landsadvocaat v", APP_VERSION))
      )
    )
  )
)