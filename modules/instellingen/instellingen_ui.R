# modules/instellingen/instellingen_ui.R
# =========================================

#' Instellingen Module UI
#' 
#' Admin interface for user management and dropdown configuration
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with admin settings
instellingen_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  # Main settings interface
  div(
    class = "container-fluid p-4",
    
    # Page header
    div(
      class = "row mb-4",
      div(
        class = "col-12",
        h1("Systeem Instellingen", class = "mb-2"),
        p("Beheer gebruikers en dropdown opties", class = "text-muted")
      )
    ),
    
    # Settings tabs
    tabsetPanel(
      id = ns("settings_tabs"),
      type = "tabs",
      
      # ======================================================================
      # USER MANAGEMENT TAB
      # ======================================================================
      
      tabPanel(
        title = div(icon("users"), " Gebruikersbeheer"),
        value = "tab_users",
        
        div(
          class = "mt-4",
          
          # Users section header
          div(
            class = "d-flex justify-content-between align-items-center mb-3",
            h3("Gebruikers"),
            actionButton(
              ns("btn_add_user"),
              "Nieuwe Gebruiker",
              class = "btn-primary",
              icon = icon("user-plus")
            )
          ),
          
          # Users table
          div(
            class = "card",
            div(
              class = "card-body",
              DT::dataTableOutput(ns("users_table"))
            )
          )
        )
      ),
      
      # ======================================================================
      # DROPDOWN MANAGEMENT TAB
      # ======================================================================
      
      tabPanel(
        title = div(icon("list"), " Dropdown Beheer"),
        value = "tab_dropdowns",
        
        div(
          class = "mt-4",
          
          # Dropdown categories section
          div(
            class = "row",
            
            # Left column - Category selection
            div(
              class = "col-md-4",
              
              div(
                class = "card",
                div(
                  class = "card-header",
                  h5("Categorieën", class = "mb-0")
                ),
                div(
                  class = "card-body",
                  
                  # Category list
                  div(
                    class = "list-group",
                    
                    # Type Dienst
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'type_dienst', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Type Dienst", class = "mb-1"),
                        span(textOutput(ns("count_type_dienst"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Rechtsgebied  
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'rechtsgebied', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Rechtsgebied", class = "mb-1"),
                        span(textOutput(ns("count_rechtsgebied"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Status Zaak
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'status_zaak', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Status Zaak", class = "mb-1"),
                        span(textOutput(ns("count_status_zaak"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Aanvragende Directie
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'aanvragende_directie', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Aanvragende Directie", class = "mb-1"),
                        span(textOutput(ns("count_aanvragende_directie"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Type Wederpartij
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'type_wederpartij', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Type Wederpartij", class = "mb-1"),
                        span(textOutput(ns("count_type_wederpartij"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Reden Inzet
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'reden_inzet', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Reden Inzet", class = "mb-1"),
                        span(textOutput(ns("count_reden_inzet"), inline = TRUE), class = "badge bg-secondary")
                      )
                    ),
                    
                    # Hoedanigheid Partij
                    tags$a(
                      href = "#",
                      class = "list-group-item list-group-item-action",
                      onclick = paste0("Shiny.setInputValue('", ns("selected_category"), "', 'hoedanigheid_partij', {priority: 'event'})"),
                      div(
                        class = "d-flex w-100 justify-content-between",
                        h6("Hoedanigheid Partij", class = "mb-1"),
                        span(textOutput(ns("count_hoedanigheid_partij"), inline = TRUE), class = "badge bg-secondary")
                      )
                    )
                  )
                )
              )
            ),
            
            # Right column - Category values
            div(
              class = "col-md-8",
              
              div(
                class = "card",
                div(
                  class = "card-header d-flex justify-content-between align-items-center",
                  h5(textOutput(ns("category_title"), inline = TRUE), class = "mb-0"),
                  actionButton(
                    ns("btn_add_dropdown_value"),
                    "Nieuwe Waarde",
                    class = "btn-primary btn-sm",
                    icon = icon("plus")
                  )
                ),
                div(
                  class = "card-body",
                  
                  # Values table
                  conditionalPanel(
                    condition = paste0("input['", ns("selected_category"), "'] != null"),
                    DT::dataTableOutput(ns("dropdown_values_table"))
                  ),
                  
                  # No category selected message
                  conditionalPanel(
                    condition = paste0("input['", ns("selected_category"), "'] == null"),
                    div(
                      class = "text-center py-5 text-muted",
                      icon("arrow-left", class = "fa-2x mb-3"),
                      h5("Selecteer een categorie"),
                      p("Kies een categorie aan de linkerkant om de waarden te bekijken")
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
}