# modules/analyse/analyse_ui.R
# ====================================

#' Analyse Module UI
#' 
#' Creates the analysis interface with filters and visualizations
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with analysis dashboard
analyse_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  tagList(
    
    # ==========================================================================
    # ANALYSE VARIABELE SELECTOR & ACTION BUTTONS
    # ==========================================================================
    
    div(
      class = "row mb-3",
      
      # Analyse variabele selector
      div(
        class = "col-md-6 d-flex align-items-center",
        div(
          class = "me-3",
          strong("Analyseer op:", class = "text-muted")
        ),
        div(
          style = "flex: 1; max-width: 250px;",
          selectInput(
            ns("analyse_split_var"),
            NULL,
            choices = NULL,
            selected = NULL,
            width = "100%"
          )
        )
      ),
      
      # Action buttons
      div(
        class = "col-md-6 d-flex justify-content-end align-items-start",
        div(
          class = "btn-group",
          downloadButton(
            ns("download_excel"),
            "Export naar Excel",
            class = "btn-success",
            icon = icon("file-excel")
          ),
          actionButton(
            ns("btn_refresh"),
            "Ververs Data",
            class = "btn-outline-primary",
            icon = icon("sync-alt")
          )
        )
      )
    ),
    
    
    # ==========================================================================
    # KPI CARDS
    # ==========================================================================
    
    div(
      class = "row mb-4",
      
      # Totaal aantal zaken
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("kpi_total_cases"), inline = TRUE), class = "text-primary mb-1"),
            div("Totaal Zaken", class = "text-muted small"),
            div(textOutput(ns("kpi_total_subtitle"), inline = TRUE), class = "text-success small")
          )
        )
      ),
      
      # Gemiddelde looptijd
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("kpi_avg_duration"), inline = TRUE), class = "text-info mb-1"),
            div("Gem. Looptijd", class = "text-muted small"),
            div("dagen", class = "text-muted small")
          )
        )
      ),
      
      # Open zaken
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("kpi_open_cases"), inline = TRUE), class = "text-warning mb-1"),
            div("Lopende Zaken", class = "text-muted small"),
            div(textOutput(ns("kpi_open_percentage"), inline = TRUE), class = "text-warning small")
          )
        )
      ),
      
      # Totaal financieel risico
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("kpi_total_risk"), inline = TRUE), class = "text-danger mb-1"),
            div("Totaal Risico", class = "text-muted small"),
            div("euro", class = "text-muted small")
          )
        )
      )
    ),
    
    # ==========================================================================
    # MAIN ANALYSIS CHARTS
    # ==========================================================================
    
    div(
      class = "row",
      
      # Left column - Looptijd analyse
      div(
        class = "col-md-6",
        
        # Looptijd analyse card
        card(
          card_header(
            h5("Looptijd Analyse", class = "mb-0"),
            div(class = "small text-muted", "Gemiddelde looptijd per categorie")
          ),
          
          card_body(
            withSpinner(
              plotlyOutput(ns("looptijd_plot"), height = "400px"),
              type = 8,
              color = "#154273"
            )
          )
        )
      ),
      
      # Right column - Verdeling analyse
      div(
        class = "col-md-6",
        
        # Verdeling analyse card
        card(
          card_header(
            h5("Verdeling Analyse", class = "mb-0"),
            div(class = "small text-muted", "Distributie van zaken")
          ),
          
          card_body(
            withSpinner(
              plotlyOutput(ns("verdeling_plot"), height = "400px"),
              type = 8,
              color = "#154273"
            )
          )
        )
      )
    ),
    
    # ==========================================================================
    # DETAIL TABLES
    # ==========================================================================
    
    div(
      class = "row mt-4",
      
      div(
        class = "col-12",
        
        card(
          card_header(
            h5("Detailgegevens", class = "mb-0")
          ),
          
          card_body(
            tabsetPanel(
              id = ns("detail_tabs"),
              
              # Looptijd details
              tabPanel(
                "Looptijd Details",
                div(
                  class = "mt-3",
                  withSpinner(
                    DT::dataTableOutput(ns("looptijd_table")),
                    type = 8,
                    color = "#154273"
                  )
                )
              ),
              
              # Verdeling details  
              tabPanel(
                "Verdeling Details",
                div(
                  class = "mt-3",
                  withSpinner(
                    DT::dataTableOutput(ns("verdeling_table")),
                    type = 8,
                    color = "#154273"
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