# modules/data_management/data_management_ui.R
# ============================================

#' Data Management Module UI
#' 
#' Creates interface for viewing, adding, editing, and deleting case data
#' 
#' @param id Module namespace ID
#' @return Shiny UI element with data management interface
data_management_ui <- function(id) {
  
  # Create namespace function
  ns <- NS(id)
  
  div(
    class = "container-fluid",
    
    # ==========================================================================
    # PAGE HEADER
    # ==========================================================================
    
    div(
      class = "d-flex justify-content-between align-items-center mb-4",
      
      # Title and description
      div(
        h1("Zaakbeheer", class = "mb-1"),
        div(
          class = "text-muted",
          "Beheer alle zaken van de landsadvocaat"
        )
      ),
      
      # Action buttons
      div(
        class = "btn-group",
        actionButton(
          ns("btn_nieuwe_zaak"),
          "Nieuwe Zaak",
          class = "btn-success",
          icon = icon("plus")
        ),
        actionButton(
          ns("btn_upload_excel"),
          "Upload Excel",
          class = "btn-outline-primary", 
          icon = icon("upload")
        ),
        actionButton(
          ns("btn_export_excel"),
          "Export Excel",
          class = "btn-outline-secondary",
          icon = icon("download")
        )
      )
    ),
    
    # ==========================================================================
    # SUMMARY CARDS
    # ==========================================================================
    
    div(
      class = "row mb-4",
      
      # Total cases card
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("total_count"), inline = TRUE), class = "text-primary mb-1"),
            div("Totaal Zaken", class = "text-muted small"),
            div(
              class = "mt-2 small text-muted",
              "Alle actieve zaken"
            )
          )
        )
      ),
      
      # Filtered count card
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("filtered_count"), inline = TRUE), class = "text-info mb-1"),
            div("Gefilterd", class = "text-muted small"),
            div(
              class = "mt-2 small text-muted",
              "Na filters"
            )
          )
        )
      ),
      
      # Open cases card
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("open_count"), inline = TRUE), class = "text-warning mb-1"),
            div("Open", class = "text-muted small"),
            div(
              class = "mt-2 small text-muted",
              "Nog in behandeling"
            )
          )
        )
      ),
      
      # Recent cases card
      div(
        class = "col-md-3",
        card(
          card_body(
            class = "text-center",
            h3(textOutput(ns("recent_count"), inline = TRUE), class = "text-success mb-1"),
            div("Recent", class = "text-muted small"),
            div(
              class = "mt-2 small text-muted",
              "Laatste 30 dagen"
            )
          )
        )
      )
    ),
    
    # ==========================================================================
    # BULK ACTIONS BAR (shown when rows selected)
    # ==========================================================================
    
    conditionalPanel(
      condition = paste0("output['", ns("has_selected_rows"), "'] == true"),
      div(
        class = "alert alert-info mb-3",
        div(
          class = "d-flex justify-content-between align-items-center",
          div(
            icon("check-square"), " ",
            textOutput(ns("selected_count"), inline = TRUE),
            " zaak(zaken) geselecteerd"
          ),
          div(
            class = "btn-group btn-group-sm",
            actionButton(
              ns("btn_bulk_edit"),
              "Bulk Bewerken",
              class = "btn-warning",
              icon = icon("edit")
            ),
            actionButton(
              ns("btn_bulk_delete"),
              "Verwijderen",
              class = "btn-danger",
              icon = icon("trash")
            ),
            actionButton(
              ns("btn_clear_selection"),
              "Selectie Wissen",
              class = "btn-outline-secondary",
              icon = icon("times")
            )
          )
        )
      )
    ),
    
    # ==========================================================================
    # DATA TABLE
    # ==========================================================================
    
    card(
      card_header(
        div(
          class = "d-flex justify-content-between align-items-center",
          div(
            h5("Zaakoverzicht", class = "mb-0"),
            div(
              class = "small text-muted",
              "Klik op een rij om details te zien, dubbelklik om te bewerken"
            )
          ),
          div(
            class = "btn-group btn-group-sm",
            actionButton(
              ns("btn_refresh"),
              "Vernieuwen",
              class = "btn-outline-primary",
              icon = icon("refresh")
            ),
            dropdownButton(
              tags$h6("Kolommen tonen/verbergen"),
              checkboxGroupInput(
                ns("visible_columns"),
                NULL,
                choices = NULL,  # Will be set by server
                selected = NULL,
                width = "200px"
              ),
              circle = FALSE,
              status = "primary",
              icon = icon("columns"),
              width = "250px",
              tooltip = tooltipOptions(title = "Kolommen beheren")
            )
          )
        )
      ),
      
      card_body(
        class = "p-0",
        
        # Loading indicator
        withSpinner(
          DT::dataTableOutput(ns("zaken_table")),
          type = 8,
          color = "#154273"
        )
      )
    ),
    
    # ==========================================================================
    # MODALS
    # ==========================================================================
    
    # Modal for new/edit case
    bsModal(
      id = ns("modal_case_form"),
      title = "Zaak Details",
      trigger = "",  # Programmatically triggered
      size = "large",
      
      # Form content will be generated by server
      div(
        id = ns("case_form_content"),
        div(
          class = "text-center p-4",
          icon("spinner", class = "fa-spin fa-2x"),
          br(), br(),
          "Formulier wordt geladen..."
        )
      ),
      
      # Modal footer with action buttons
      div(
        class = "modal-footer",
        actionButton(
          ns("btn_save_case"),
          "Opslaan",
          class = "btn-primary",
          icon = icon("save")
        ),
        actionButton(
          ns("btn_cancel_form"),
          "Annuleren",
          class = "btn-secondary",
          `data-dismiss` = "modal"
        )
      )
    ),
    
    # Modal for case details (read-only)
    bsModal(
      id = ns("modal_case_details"),
      title = "Zaak Details (Alleen Lezen)",
      trigger = "",
      size = "large",
      
      div(
        id = ns("case_details_content"),
        div(
          class = "text-center p-4",
          "Details worden geladen..."
        )
      ),
      
      div(
        class = "modal-footer",
        actionButton(
          ns("btn_edit_from_details"),
          "Bewerken",
          class = "btn-primary",
          icon = icon("edit")
        ),
        actionButton(
          ns("btn_close_details"),
          "Sluiten",
          class = "btn-secondary",
          `data-dismiss` = "modal"
        )
      )
    ),
    
    # Modal for Excel upload
    bsModal(
      id = ns("modal_upload"),
      title = "Excel Bestand Uploaden",
      trigger = "",
      size = "medium",
      
      div(
        class = "p-3",
        
        # Upload instructions
        div(
          class = "alert alert-info",
          h6("Upload Instructies:", class = "alert-heading"),
          tags$ul(
            tags$li("Ondersteunde formaten: .xlsx, .xls"),
            tags$li("Maximale bestandsgrootte: 10MB"),
            tags$li("Eerste rij moet kolomnamen bevatten"),
            tags$li("Verplichte kolommen worden gevalideerd")
          )
        ),
        
        # File input
        fileInput(
          ns("upload_file"),
          "Selecteer Excel bestand:",
          accept = c(".xlsx", ".xls"),
          width = "100%"
        ),
        
        # Upload progress
        conditionalPanel(
          condition = paste0("output['", ns("upload_in_progress"), "'] == true"),
          div(
            class = "mt-3",
            h6("Upload Voortgang:"),
            progressBar(
              id = ns("upload_progress"),
              value = 0,
              status = "info",
              striped = TRUE
            )
          )
        ),
        
        # Upload preview
        conditionalPanel(
          condition = paste0("output['", ns("upload_has_preview"), "'] == true"),
          div(
            class = "mt-3",
            h6("Preview (eerste 5 rijen):"),
            withSpinner(
              DT::dataTableOutput(ns("upload_preview")),
              type = 8
            )
          )
        )
      ),
      
      div(
        class = "modal-footer",
        actionButton(
          ns("btn_process_upload"),
          "Importeren",
          class = "btn-success",
          icon = icon("check"),
          disabled = TRUE
        ),
        actionButton(
          ns("btn_cancel_upload"),
          "Annuleren",
          class = "btn-secondary",
          `data-dismiss` = "modal"
        )
      )
    ),
    
    # Confirmation modal for deletions
    bsModal(
      id = ns("modal_confirm_delete"),
      title = "Bevestig Verwijdering",
      trigger = "",
      size = "medium",
      
      div(
        class = "p-3",
        div(
          class = "alert alert-danger",
          icon("exclamation-triangle"), " ",
          tags$strong("Waarschuwing!"),
          br(),
          "Deze actie kan niet ongedaan worden gemaakt."
        ),
        
        div(
          id = ns("delete_confirmation_text"),
          "Weet je zeker dat je de geselecteerde zaak(zaken) wilt verwijderen?"
        )
      ),
      
      div(
        class = "modal-footer",
        actionButton(
          ns("btn_confirm_delete"),
          "Ja, Verwijderen",
          class = "btn-danger",
          icon = icon("trash")
        ),
        actionButton(
          ns("btn_cancel_delete"),
          "Annuleren",
          class = "btn-secondary",
          `data-dismiss` = "modal"
        )
      )
    )
  )
}