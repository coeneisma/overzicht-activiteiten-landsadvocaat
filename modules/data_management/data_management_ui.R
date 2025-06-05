# modules/data_management/data_management_ui.R
# ===============================================
# MINIMAL VERSION - Step 1: Basic Data Table Only

#' Data Management Module UI - Minimal
#' 
#' Creates basic data table interface without complex modals
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with basic data table
data_management_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  tagList(
    
    # ==========================================================================
    # PAGE HEADER
    # ==========================================================================
    
    div(
      class = "d-flex justify-content-between align-items-center mb-4",
      
      # Title section
      div(
        h1("Zaakbeheer", class = "mb-1"),
        p("Overzicht van alle zaken van de landsadvocaat", class = "text-muted mb-0")
      ),
      
      # Action buttons (placeholder for now)
      div(
        class = "btn-group",
        actionButton(
          ns("btn_nieuwe_zaak"),
          "Nieuwe Zaak",
          class = "btn-primary",
          icon = icon("plus")
        ),
        downloadButton(
          ns("download_excel"),
          "Export naar Excel",
          class = "btn-success",
          icon = icon("file-excel")
        ),
        actionButton(
          ns("btn_refresh"),
          "Ververs",
          class = "btn-outline-secondary",
          icon = icon("sync-alt")
        )
      )
    ),
    
    # ==========================================================================
    # SUMMARY STATISTICS
    # ==========================================================================
    
    div(
      class = "row mb-4",
      
      # Total cases
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("stat_total"), inline = TRUE), class = "text-primary mb-1"),
            div("Totaal Zaken", class = "text-muted small")
          )
        )
      ),
      
      # Filtered cases
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("stat_filtered"), inline = TRUE), class = "text-info mb-1"),
            div("Gefilterd", class = "text-muted small")
          )
        )
      ),
      
      # Open cases
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("stat_open"), inline = TRUE), class = "text-warning mb-1"),
            div("Open", class = "text-muted small")
          )
        )
      ),
      
      # Recent cases (this month)
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("stat_recent"), inline = TRUE), class = "text-success mb-1"),
            div("Deze Maand", class = "text-muted small")
          )
        )
      )
    ),
    
    # ==========================================================================
    # BASIC DATA TABLE
    # ==========================================================================
    
    card(
      card_header(
        class = "d-flex justify-content-between align-items-center",
        
        # Table title
        div(
          h5("Zaken Overzicht", class = "mb-0"),
          div(class = "small text-muted", "Klik op een zaak voor details, dubbelklik om te bewerken")
        ),
        
        # Simple status indicator
        div(
          class = "small text-muted",
          "Laatst bijgewerkt: ", textOutput(ns("last_updated"), inline = TRUE)
        )
      ),
      
      card_body(
        class = "p-0",
        
        # Basic data table with spinner
        withSpinner(
          DT::dataTableOutput(ns("zaken_table")),
          type = 8,
          color = "#154273"
        )
      )
    ),
    
    # ==========================================================================
    # ZAAK DETAILS MODAL (READ-ONLY)
    # ==========================================================================
    
    # This modal is created dynamically by server when row is clicked
    
    # ==========================================================================
    # ZAAK BEWERKEN MODAL
    # ==========================================================================
    
    # This modal is created dynamically by server when edit is clicked
    
    # Note: Both modals are created dynamically by server for better state management
  )
}