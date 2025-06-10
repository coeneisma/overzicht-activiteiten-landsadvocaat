# modules/filters/filters_ui.R
# ============================

#' Filter Module UI
#' 
#' Creates sidebar filter controls for case data
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with filter controls
filters_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  tagList(
    
    # ==========================================================================
    # FILTER SUMMARY
    # ==========================================================================
    
    # Shows current filter status
    div(
      class = "mb-3",
      card(
        card_body(
          class = "p-3",
          div(
            class = "d-flex justify-content-between align-items-center",
            div(
              class = "small text-muted",
              "Gefilterde zaken:"
            ),
            div(
              class = "fw-bold text-primary",
              textOutput(ns("filtered_count"), inline = TRUE)
            )
          ),
          
          # Active filters indicator
          conditionalPanel(
            condition = paste0("output['", ns("has_active_filters"), "'] == true"),
            div(
              class = "mt-2 pt-2 border-top",
              div(
                class = "d-flex justify-content-between align-items-center",
                div(
                  class = "small text-warning",
                  icon("filter"), " Actieve filters"
                ),
                actionButton(
                  ns("reset_filters"),
                  "Reset",
                  class = "btn-sm btn-outline-secondary",
                  icon = icon("undo")
                )
              )
            )
          )
        )
      )
    ),
    
    # ==========================================================================
    # SEARCH BOX
    # ==========================================================================
    
    div(
      class = "mb-3",
      textInput(
        ns("search_text"),
        label = div(
          icon("search"), " Zoeken",
          class = "fw-bold"
        ),
        placeholder = "Zoek in alle velden...",
        width = "100%"
      )
    ),
    
    # ==========================================================================
    # FILTER ACCORDIONS
    # ==========================================================================
    
    # Classification Filters
    accordion(
      id = ns("filter_accordion"),
      open = FALSE,
      
      # ========================================================================
      # CLASSIFICATION FILTERS
      # ========================================================================
      accordion_panel(
        title = div(
          icon("tags"), " Classificatie",
          class = "fw-bold"
        ),
        value = "classificatie",
        
        # Type Dienst
        div(
          class = "mb-3",
          selectInput(
            ns("type_dienst"),
            "Type Dienst:",
            choices = NULL,  # Will be populated by server
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Rechtsgebied  
        div(
          class = "mb-3",
          selectInput(
            ns("rechtsgebied"),
            "Rechtsgebied:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Type Procedure
        div(
          class = "mb-3",
          selectInput(
            ns("type_procedure"),
            "Type Procedure:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Status Zaak
        div(
          class = "mb-3",
          selectInput(
            ns("status_zaak"),
            "Status:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        )
      ),
      
      # ========================================================================
      # DATE FILTERS
      # ========================================================================
      accordion_panel(
        title = div(
          icon("calendar"), " Datum",
          class = "fw-bold"
        ),
        value = "datum",
        
        # Date range picker
        div(
          class = "mb-3",
          dateRangeInput(
            ns("datum_range"),
            "Datum Aanmaak:",
            start = NULL,  # Will be set by server
            end = NULL,
            format = "dd-mm-yyyy",
            language = "nl",
            separator = " tot ",
            width = "100%"
          )
        ),
        
        # Quick date filters
        div(
          class = "mb-3",
          div(class = "small text-muted mb-2", "Snelle selectie:"),
          div(
            class = "btn-group-vertical d-grid gap-1",
            actionButton(
              ns("date_last_month"),
              "Laatste maand",
              class = "btn-sm btn-outline-secondary"
            ),
            actionButton(
              ns("date_last_quarter"),
              "Laatste kwartaal", 
              class = "btn-sm btn-outline-secondary"
            ),
            actionButton(
              ns("date_this_year"),
              "Dit jaar",
              class = "btn-sm btn-outline-secondary"
            )
          )
        )
      ),
      
      # ========================================================================
      # ORGANIZATION FILTERS
      # ========================================================================
      accordion_panel(
        title = div(
          icon("building"), " Organisatie",
          class = "fw-bold"
        ),
        value = "organisatie",
        
        # Aanvragende Directie
        div(
          class = "mb-3",
          selectInput(
            ns("aanvragende_directie"),
            "Aanvragende Directie:",
            choices = NULL,  # Populated from data
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Advocaat/Kantoor
        div(
          class = "mb-3",
          selectInput(
            ns("advocaat"),
            "Advocaat:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Advocatenkantoor
        div(
          class = "mb-3",
          selectInput(
            ns("adv_kantoor"),
            "Advocatenkantoor:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        )
      ),
      
      # ========================================================================
      # FINANCIAL FILTERS
      # ========================================================================
      accordion_panel(
        title = div(
          icon("euro-sign"), " Financieel",
          class = "fw-bold"
        ),
        value = "financieel",
        
        # Budget range
        div(
          class = "mb-3",
          numericInput(
            ns("budget_min"),
            "Min. Budget (€):",
            value = NULL,
            min = 0,
            step = 1000,
            width = "100%"
          )
        ),
        
        div(
          class = "mb-3",
          numericInput(
            ns("budget_max"),
            "Max. Budget (€):",
            value = NULL,
            min = 0,
            step = 1000,
            width = "100%"
          )
        ),
        
        # Financial risk range
        div(
          class = "mb-3",
          numericInput(
            ns("risico_min"),
            "Min. Financieel Risico (€):",
            value = NULL,
            min = 0,
            step = 10000,
            width = "100%"
          )
        ),
        
        div(
          class = "mb-3",
          numericInput(
            ns("risico_max"),
            "Max. Financieel Risico (€):",
            value = NULL,
            min = 0,
            step = 10000,
            width = "100%"
          )
        )
      ),
      
      # ========================================================================
      # ADVANCED FILTERS
      # ========================================================================
      accordion_panel(
        title = div(
          icon("sliders-h"), " Geavanceerd",
          class = "fw-bold"
        ),
        value = "geavanceerd",
        
        # Hoedanigheid Partij
        div(
          class = "mb-3",
          selectInput(
            ns("hoedanigheid_partij"),
            "Hoedanigheid Partij:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Type Wederpartij
        div(
          class = "mb-3",
          selectInput(
            ns("type_wederpartij"),
            "Type Wederpartij:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Reden Inzet
        div(
          class = "mb-3",
          selectInput(
            ns("reden_inzet"),
            "Reden Inzet:",
            choices = NULL,
            selected = NULL,
            multiple = TRUE,
            width = "100%"
          )
        ),
        
        # Aansprakelijkheid
        div(
          class = "mb-3",
          selectInput(
            ns("aansprakelijkheid"),
            "Aansprakelijkheid:",
            choices = c("Alle" = "", "JA" = "JA", "NEE" = "NEE", "Geen waarde" = "__NA__"),
            selected = "",
            multiple = FALSE,
            width = "100%"
          )
        )
        
      )
    ),
    
    # ==========================================================================
    # FILTER ACTIONS
    # ==========================================================================
    
    # Apply filters button (for performance, optional)
    conditionalPanel(
      condition = paste0("output['", ns("show_apply_button"), "'] == true"),
      div(
        class = "mt-4 d-grid",
        actionButton(
          ns("apply_filters"),
          "Filters Toepassen",
          class = "btn-primary",
          icon = icon("filter"),
          width = "100%"
        )
      )
    )
  )
}