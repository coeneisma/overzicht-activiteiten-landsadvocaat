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
                  h4(textOutput("stats_total_zaken", inline = TRUE), class = "text-primary"),
                  div("Gefilterd", class = "text-muted small")
              ),
              div(class = "col-4", 
                  h4(textOutput("stats_open_zaken", inline = TRUE), class = "text-warning"),
                  div("Open", class = "text-muted small")
              ),
              div(class = "col-4",
                  h4("3", class = "text-info"),
                  div("Totaal", class = "text-muted small")
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
      
      # Dashboard tab
      nav_panel(
        title = "Dashboard",
        icon = icon("chart-line"),
        value = "tab_dashboard",
        
        div(
          class = "container-fluid",
          h1("Dashboard Overzicht"),
          p("Analytics module wordt binnenkort geladen...", class = "text-muted")
        )
      ),
      
      # Zaakbeheer tab  
      nav_panel(
        title = "Zaakbeheer",
        icon = icon("folder-open"),
        value = "tab_zaakbeheer",
        
        div(
          class = "container-fluid",
          h1("Zaakbeheer"),
          p("Data management module wordt binnenkort geladen...", class = "text-muted")
        )
      ),
      
      # Export tab
      nav_panel(
        title = "Export", 
        icon = icon("file-export"),
        value = "tab_export",
        
        div(
          class = "container-fluid",
          h1("Export & Rapporten"),
          p("Export module wordt binnenkort geladen...", class = "text-muted")
        )
      ),
      
      # Instellingen tab (admin only)
      nav_panel(
        title = "Instellingen",
        icon = icon("cog"),
        value = "tab_instellingen",
        
        conditionalPanel(
          condition = "output.user_is_admin == true",
          div(
            class = "container-fluid",
            h1("Systeem Instellingen"),
            p("Admin functionaliteiten worden binnenkort geladen...", class = "text-muted")
          )
        ),
        
        conditionalPanel(
          condition = "output.user_is_admin != true",
          div(
            class = "container-fluid",
            div(
              class = "alert alert-warning",
              icon("lock"), " Alleen administrators hebben toegang tot deze pagina."
            )
          )
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