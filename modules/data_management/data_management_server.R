# modules/data_management/data_management_server.R
# ================================================

#' Data Management Module Server
#' 
#' Handles CRUD operations for case data
#' 
#' @param id Module namespace ID
#' @param filtered_data Reactive containing filtered case data
#' @param raw_data Reactive containing all case data
#' @param current_user Reactive containing current user name
#' @param refresh_trigger Function to trigger data refresh
#' @return List with reactive values for data changes
data_management_server <- function(id, filtered_data, raw_data, current_user, refresh_trigger) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES
    # ========================================================================
    
    # Selected rows in data table
    selected_rows <- reactiveVal(numeric(0))
    
    # Current form mode: "create", "edit", "view"
    form_mode <- reactiveVal("create")
    
    # Current case being edited
    current_case <- reactiveVal(NULL)
    
    # Upload state
    upload_data <- reactiveVal(NULL)
    upload_progress <- reactiveVal(0)
    
    # Data change tracker
    data_changed <- reactiveVal(0)
    
    # Column visibility
    visible_columns <- reactiveVal(NULL)
    
    # ========================================================================
    # SUMMARY STATISTICS
    # ========================================================================
    
    # Total count (all active cases)
    output$total_count <- renderText({
      data <- raw_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      active_count <- sum(data$status_zaak != "Verwijderd", na.rm = TRUE)
      format(active_count, big.mark = ".")
    })
    
    # Filtered count
    output$filtered_count <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      format(nrow(data), big.mark = ".")
    })
    
    # Open cases count
    output$open_count <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      open_count <- sum(data$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE)
      format(open_count, big.mark = ".")
    })
    
    # Recent cases (last 30 days)
    output$recent_count <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      cutoff_date <- Sys.Date() - 30
      recent_count <- sum(data$datum_aanmaak >= cutoff_date, na.rm = TRUE)
      format(recent_count, big.mark = ".")
    })
    
    # ========================================================================
    # DATA TABLE
    # ========================================================================
    
    # Initialize column choices
    observe({
      data <- filtered_data()
      if (!is.null(data) && nrow(data) > 0) {
        
        # Define user-friendly column names
        column_choices <- c(
          "Zaak ID" = "zaak_id",
          "Datum" = "datum_aanmaak", 
          "Omschrijving" = "omschrijving",
          "Type Dienst" = "type_dienst",
          "Rechtsgebied" = "rechtsgebied",
          "Status" = "status_zaak",
          "Directie" = "aanvragende_directie",
          "Advocaat" = "advocaat",
          "Budget WJZ" = "la_budget_wjz",
          "Financieel Risico" = "financieel_risico"
        )
        
        # Set default visible columns
        if (is.null(visible_columns())) {
          default_visible <- c("zaak_id", "datum_aanmaak", "omschrijving", "type_dienst", 
                               "rechtsgebied", "status_zaak", "aanvragende_directie")
          visible_columns(default_visible)
        }
        
        updateCheckboxGroupInput(
          session, "visible_columns",
          choices = column_choices,
          selected = visible_columns()
        )
      }
    })
    
    # Update visible columns when user changes selection
    observeEvent(input$visible_columns, {
      visible_columns(input$visible_columns)
    })
    
    # Render data table
    output$zaken_table <- DT::renderDataTable({
      
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(data.frame(Bericht = "Geen data beschikbaar"), 
                             options = list(dom = 't')))
      }
      
      # Select visible columns
      if (!is.null(visible_columns()) && length(visible_columns()) > 0) {
        display_data <- data[, visible_columns(), drop = FALSE]
      } else {
        # Fallback to key columns
        key_cols <- intersect(c("zaak_id", "datum_aanmaak", "omschrijving", "status_zaak"), names(data))
        display_data <- data[, key_cols, drop = FALSE]
      }
      
      # Format data for display
      if ("datum_aanmaak" %in% names(display_data)) {
        display_data$datum_aanmaak <- format_date_nl(display_data$datum_aanmaak)
      }
      
      if ("la_budget_wjz" %in% names(display_data)) {
        display_data$la_budget_wjz <- format_currency(display_data$la_budget_wjz)
      }
      
      if ("financieel_risico" %in% names(display_data)) {
        display_data$financieel_risico <- format_currency(display_data$financieel_risico)
      }
      
      # Create user-friendly column names
      friendly_names <- c(
        "zaak_id" = "Zaak ID",
        "datum_aanmaak" = "Datum",
        "omschrijving" = "Omschrijving", 
        "type_dienst" = "Type Dienst",
        "rechtsgebied" = "Rechtsgebied",
        "status_zaak" = "Status",
        "aanvragende_directie" = "Directie",
        "advocaat" = "Advocaat",
        "la_budget_wjz" = "Budget WJZ",
        "financieel_risico" = "Risico"
      )
      
      # Rename columns to friendly names
      for (col in names(display_data)) {
        if (col %in% names(friendly_names)) {
          names(display_data)[names(display_data) == col] <- friendly_names[[col]]
        }
      }
      
      # Create data table
      DT::datatable(
        display_data,
        selection = list(mode = "multiple", target = "row"),
        options = list(
          pageLength = 25,
          scrollX = TRUE,
          autoWidth = TRUE,
          columnDefs = list(
            list(targets = "_all", className = "dt-center")
          ),
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items",
            info = "_START_ tot _END_ van _TOTAL_ zaken",
            infoEmpty = "Geen zaken beschikbaar",
            infoFiltered = "(gefilterd van _MAX_ totaal)",
            paginate = list(
              first = "Eerste",
              last = "Laatste",
              next = "Volgende",
              previous = "Vorige"
            ),
            zeroRecords = "Geen zaken gevonden"
          )
        ),
        class = "table table-striped table-hover"
      )
      
    }, server = TRUE)
    
    # ========================================================================
    # ROW SELECTION
    # ========================================================================
    
    # Track selected rows
    observeEvent(input$zaken_table_rows_selected, {
      selected_rows(input$zaken_table_rows_selected)
    })
    
    # Has selected rows output
    output$has_selected_rows <- reactive({
      length(selected_rows()) > 0
    })
    outputOptions(output, "has_selected_rows", suspendWhenHidden = FALSE)
    
    # Selected count output
    output$selected_count <- renderText({
      count <- length(selected_rows())
      if (count == 1) {
        "1 zaak"
      } else {
        paste(count, "zaken")
      }
    })
    
    # Clear selection
    observeEvent(input$btn_clear_selection, {
      proxy <- DT::dataTableProxy("zaken_table")
      DT::selectRows(proxy, NULL)
      selected_rows(numeric(0))
    })
    
    # ========================================================================
    # CASE FORM GENERATION
    # ========================================================================
    
    # Generate case form UI
    generate_case_form <- function(case_data = NULL, mode = "create") {
      
      # Get dropdown choices
      type_dienst_choices <- get_dropdown_opties("type_dienst")
      rechtsgebied_choices <- get_dropdown_opties("rechtsgebied")
      status_choices <- get_dropdown_opties("status_zaak")
      
      # Create form
      div(
        fluidRow(
          # Left column
          column(6,
                 # Basic information
                 h5("Basis Informatie", class = "text-primary mb-3"),
                 
                 textInput(
                   session$ns("form_zaak_id"),
                   "Zaak ID:",
                   value = if (!is.null(case_data)) case_data$zaak_id else "",
                   placeholder = "bijv. WJZ/LA/2024/001"
                 ),
                 
                 dateInput(
                   session$ns("form_datum_aanmaak"),
                   "Datum Aanmaak:",
                   value = if (!is.null(case_data)) case_data$datum_aanmaak else Sys.Date(),
                   format = "dd-mm-yyyy",
                   language = "nl"
                 ),
                 
                 textAreaInput(
                   session$ns("form_omschrijving"),
                   "Omschrijving:",
                   value = if (!is.null(case_data)) case_data$omschrijving else "",
                   rows = 3,
                   placeholder = "Korte beschrijving van de zaak..."
                 ),
                 
                 selectInput(
                   session$ns("form_type_dienst"),
                   "Type Dienst:",
                   choices = c("Selecteer..." = "", type_dienst_choices),
                   selected = if (!is.null(case_data)) case_data$type_dienst else ""
                 ),
                 
                 selectInput(
                   session$ns("form_rechtsgebied"),
                   "Rechtsgebied:",
                   choices = c("Selecteer..." = "", rechtsgebied_choices),
                   selected = if (!is.null(case_data)) case_data$rechtsgebied else ""
                 ),
                 
                 selectInput(
                   session$ns("form_status_zaak"),
                   "Status:",
                   choices = c("Selecteer..." = "", status_choices),
                   selected = if (!is.null(case_data)) case_data$status_zaak else "Open"
                 )
          ),
          
          # Right column
          column(6,
                 # Organization information
                 h5("Organisatie", class = "text-primary mb-3"),
                 
                 textInput(
                   session$ns("form_aanvragende_directie"),
                   "Aanvragende Directie:",
                   value = if (!is.null(case_data)) case_data$aanvragende_directie else "",
                   placeholder = "bijv. VWS, IenW, BZK"
                 ),
                 
                 textInput(
                   session$ns("form_advocaat"),
                   "Advocaat:",
                   value = if (!is.null(case_data)) case_data$advocaat else "",
                   placeholder = "Naam van de advocaat"
                 ),
                 
                 textInput(
                   session$ns("form_adv_kantoor"),
                   "Advocatenkantoor:",
                   value = if (!is.null(case_data)) case_data$adv_kantoor else "",
                   placeholder = "Naam van het kantoor"
                 ),
                 
                 # Financial information
                 h5("Financieel", class = "text-primary mb-3 mt-4"),
                 
                 numericInput(
                   session$ns("form_la_budget_wjz"),
                   "Budget WJZ (€):",
                   value = if (!is.null(case_data)) case_data$la_budget_wjz else NA,
                   min = 0,
                   step = 1000
                 ),
                 
                 numericInput(
                   session$ns("form_budget_andere_directie"),
                   "Budget Andere Directie (€):",
                   value = if (!is.null(case_data)) case_data$budget_andere_directie else NA,
                   min = 0,
                   step = 1000
                 ),
                 
                 numericInput(
                   session$ns("form_financieel_risico"),
                   "Financieel Risico (€):",
                   value = if (!is.null(case_data)) case_data$financieel_risico else NA,
                   min = 0,
                   step = 10000
                 )
          )
        ),
        
        # Notes section
        fluidRow(
          column(12,
                 h5("Opmerkingen", class = "text-primary mb-3 mt-4"),
                 textAreaInput(
                   session$ns("form_opmerkingen"),
                   NULL,
                   value = if (!is.null(case_data)) case_data$opmerkingen else "",
                   rows = 3,
                   placeholder = "Aanvullende opmerkingen over de zaak..."
                 )
          )
        )
      )
    }
    
    # ========================================================================
    # MODAL HANDLING
    # ========================================================================
    
    # New case button
    observeEvent(input$btn_nieuwe_zaak, {
      form_mode("create")
      current_case(NULL)
      
      # Generate form content
      form_content <- generate_case_form(mode = "create")
      
      # Show notification for now (modals not implemented yet)
      show_notification("Nieuwe zaak formulier wordt binnenkort toegevoegd", type = "message")
    })
    
    # Double click to edit
    observeEvent(input$zaken_table_cell_clicked, {
      if (!is.null(input$zaken_table_cell_clicked$row)) {
        show_notification("Zaak bewerken wordt binnenkort toegevoegd", type = "message")
      }
    })
    
    # ========================================================================
    # SAVE CASE (placeholder)
    # ========================================================================
    
    observeEvent(input$btn_save_case, {
      show_notification("Opslaan functionaliteit wordt binnenkort toegevoegd", type = "message")
    })
    
    # ========================================================================
    # REFRESH DATA
    # ========================================================================
    
    observeEvent(input$btn_refresh, {
      cli_alert_info("Manual data refresh requested")
      refresh_trigger()
      show_notification("Data ververst", type = "message")
    })
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    return(list(
      data_changed = reactive({ data_changed() }),
      selected_count = reactive({ length(selected_rows()) }),
      refresh_data = function() {
        refresh_trigger()
        data_changed(data_changed() + 1)
      }
    ))
  })
}