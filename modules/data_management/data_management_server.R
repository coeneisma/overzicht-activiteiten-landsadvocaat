# modules/data_management/data_management_server.R
# ==================================================
# MINIMAL VERSION - Step 2a: Basic Data Table + Edit Functionality

#' Data Management Module Server - With Edit Functionality
#' 
#' Handles basic data display, statistics, and edit functionality
#' 
#' @param id Module namespace ID
#' @param filtered_data Reactive containing filtered case data
#' @param raw_data Reactive containing all case data
#' @param data_refresh_trigger Reactive value to trigger data refresh
#' @param current_user Reactive containing current username
#' @param global_dropdown_refresh_trigger Reactive trigger for dropdown refresh
#' @return List with reactive values and functions
data_management_server <- function(id, filtered_data, raw_data, data_refresh_trigger, current_user, global_dropdown_refresh_trigger = NULL) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES FOR EDIT STATE
    # ========================================================================
    
    # Store the original zaak_id when editing
    original_zaak_id <- reactiveVal(NULL)
    
    # ========================================================================
    # SUMMARY STATISTICS
    # ========================================================================
    
    # Total cases (all data)
    output$stat_total <- renderText({
      data <- raw_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      total <- nrow(data)
      format(total, big.mark = " ")  # Use space instead of dot
    })
    
    # Filtered cases
    output$stat_filtered <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      filtered <- nrow(data)
      format(filtered, big.mark = " ")  # Use space instead of dot
    })
    
    # Open cases (from filtered data)
    output$stat_open <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      open_count <- sum(data$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE)
      format(open_count, big.mark = " ")  # Use space instead of dot
    })
    
    # Recent cases (this month, from filtered data)
    output$stat_recent <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      current_month <- format(Sys.Date(), "%Y-%m")
      recent_count <- sum(format(data$datum_aanmaak, "%Y-%m") == current_month, na.rm = TRUE)
      format(recent_count, big.mark = " ")  # Use space instead of dot
    })
    
    # Last updated timestamp
    output$last_updated <- renderText({
      # Trigger on data refresh
      data_refresh_trigger()
      format(Sys.time(), "%H:%M:%S")
    })
    
    # ========================================================================
    # BASIC DATA TABLE
    # ========================================================================
    
    output$zaken_table <- DT::renderDataTable({
      
      data <- filtered_data()
      
      # Show message if no data
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen zaken gevonden. Pas filters aan of voeg nieuwe zaken toe."),
          options = list(
            searching = FALSE, 
            paging = FALSE, 
            info = FALSE,
            ordering = FALSE
          ),
          rownames = FALSE
        ))
      }
      
      # Prepare display data (basic columns only)
      display_data <- data %>%
        select(
          "Zaak ID" = zaak_id,
          "Datum" = datum_aanmaak,
          "Omschrijving" = omschrijving,
          "Type Dienst" = type_dienst,
          "Rechtsgebied" = rechtsgebied,
          "Status" = status_zaak,
          "Directie" = aanvragende_directie,
          "Advocaat" = advocaat
        ) %>%
        mutate(
          Datum = format_date_nl(Datum),
          # Convert database values to display names
          `Type Dienst` = sapply(`Type Dienst`, function(x) get_weergave_naam("type_dienst", x)),
          Rechtsgebied = sapply(Rechtsgebied, function(x) get_weergave_naam("rechtsgebied", x)),
          Status = sapply(Status, function(x) get_weergave_naam("status_zaak", x)),
          Directie = sapply(Directie, function(x) get_weergave_naam("aanvragende_directie", x)),
          # Truncate long descriptions
          Omschrijving = ifelse(
            nchar(Omschrijving) > 60, 
            paste0(substr(Omschrijving, 1, 57), "..."), 
            Omschrijving
          )
        )
      
      # Create simple DataTable
      DT::datatable(
        display_data,
        selection = 'none',  # Disable row selection highlighting
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          scrollX = TRUE,
          autoWidth = FALSE,
          dom = 'frtip',  # Simple layout: filter, table, info, pagination
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ items",
            infoEmpty = "Geen items beschikbaar",
            infoFiltered = "(gefilterd van _MAX_ totaal items)",
            paginate = list(
              first = "Eerste",
              last = "Laatste",
              `next` = "Volgende",
              previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE
      ) %>%
        # Simple status color coding
        DT::formatStyle(
          "Status",
          backgroundColor = DT::styleEqual(
            c("Open", "In_behandeling", "Afgerond", "On_hold"),
            c("#fff3cd", "#d1ecf1", "#d4edda", "#f8d7da")
          )
        )
      
    }, server = TRUE)
    
    # ========================================================================
    # TABLE ROW INTERACTION
    # ========================================================================
    
    # Track last clicked row to prevent duplicate events
    last_clicked_info <- reactiveVal(NULL)
    
    # Handle table row clicks for details
    observeEvent(input$zaken_table_cell_clicked, {
      
      info <- input$zaken_table_cell_clicked
      
      if (!is.null(info$row) && info$row > 0) {
        
        # Simple duplicate prevention - check if same row/col as last click
        current_info <- paste0(info$row, "_", info$col)
        if (!is.null(last_clicked_info()) && current_info == last_clicked_info()) {
          return()  # Ignore duplicate clicks
        }
        last_clicked_info(current_info)
        
        data <- filtered_data()
        if (nrow(data) > 0 && info$row <= nrow(data)) {
          
          # Get the clicked case
          selected_zaak <- data[info$row, ]
          zaak_id <- selected_zaak$zaak_id
          
          cli_alert_info("Table row clicked for zaak: {zaak_id}")
          show_zaak_details_modal(selected_zaak)
        }
      }
    })
    
    # ========================================================================
    # DROPDOWN CHOICES FOR FORM
    # ========================================================================
    
    # Load dropdown choices for forms
    dropdown_choices <- reactiveValues()
    
    observe({
      # React to global dropdown refresh trigger
      if (!is.null(global_dropdown_refresh_trigger)) {
        global_dropdown_refresh_trigger()
      }
      
      tryCatch({
        dropdown_choices$type_dienst <- get_dropdown_opties("type_dienst")
        dropdown_choices$rechtsgebied <- get_dropdown_opties("rechtsgebied")
        dropdown_choices$status_zaak <- get_dropdown_opties("status_zaak")
        dropdown_choices$aanvragende_directie <- get_dropdown_opties("aanvragende_directie")
        
        cli_alert_success("Dropdown choices refreshed for form")
        
      }, error = function(e) {
        cli_alert_danger("Error loading dropdown choices: {e$message}")
      })
    })
    
    # ========================================================================
    # ZAAK DETAILS & EDIT MODALS
    # ========================================================================
    
    # Show case details modal (read-only)
    show_zaak_details_modal <- function(zaak_data) {
      showModal(modalDialog(
        title = paste("Zaak Details:", zaak_data$zaak_id),
        size = "l",
        easyClose = TRUE,
        
        # Details content
        div(
          class = "container-fluid",
          
          h5("Basisinformatie", class = "border-bottom pb-2 mb-3"),
          div(
            class = "row mb-3",
            div(class = "col-md-6",
                strong("Zaak ID: "), zaak_data$zaak_id, br(),
                strong("Datum: "), format_date_nl(zaak_data$datum_aanmaak), br(),
                strong("Status: "), ifelse(is.na(zaak_data$status_zaak), "-", get_weergave_naam("status_zaak", zaak_data$status_zaak)), br(),
                strong("Type Dienst: "), ifelse(is.na(zaak_data$type_dienst), "-", get_weergave_naam("type_dienst", zaak_data$type_dienst))
            ),
            div(class = "col-md-6",
                strong("Rechtsgebied: "), ifelse(is.na(zaak_data$rechtsgebied), "-", get_weergave_naam("rechtsgebied", zaak_data$rechtsgebied)), br(),
                strong("Aanvragende Directie: "), ifelse(is.na(zaak_data$aanvragende_directie), "-", get_weergave_naam("aanvragende_directie", zaak_data$aanvragende_directie)), br(),
                strong("Advocaat: "), ifelse(is.na(zaak_data$advocaat), "-", zaak_data$advocaat), br(),
                strong("Kantoor: "), ifelse(is.na(zaak_data$adv_kantoor), "-", zaak_data$adv_kantoor)
            )
          ),
          
          h5("Omschrijving", class = "border-bottom pb-2 mb-3"),
          p(ifelse(is.na(zaak_data$omschrijving), "Geen omschrijving", zaak_data$omschrijving)),
          
          h5("Financiële Informatie", class = "border-bottom pb-2 mb-3"),
          
          div(
            class = "row mb-3",
            div(class = "col-md-4",
                strong("Budget WJZ: "), 
                format_currency(as.numeric(zaak_data$la_budget_wjz))
            ),
            div(class = "col-md-4",
                strong("Budget Andere Directie: "), 
                format_currency(as.numeric(zaak_data$budget_andere_directie))
            ),
            div(class = "col-md-4",
                strong("Financieel Risico: "), 
                format_currency(as.numeric(zaak_data$financieel_risico))
            )
          ),
          
          if (!is.na(zaak_data$opmerkingen) && zaak_data$opmerkingen != "") {
            div(
              h5("Opmerkingen", class = "border-bottom pb-2 mb-3"),
              p(zaak_data$opmerkingen)
            )
          }
        ),
        
        # Modal footer
        footer = div(
          actionButton(
            session$ns("btn_details_edit"),
            "Bewerken",
            class = "btn-primary",
            icon = icon("edit"),
            onclick = paste0("Shiny.setInputValue('", session$ns("edit_zaak_id"), "', '", zaak_data$zaak_id, "', {priority: 'event'})")
          ),
          actionButton(
            session$ns("btn_details_delete"),
            "Verwijderen",
            class = "btn-danger ms-2",
            icon = icon("trash"),
            onclick = paste0("Shiny.setInputValue('", session$ns("delete_zaak_id"), "', '", zaak_data$zaak_id, "', {priority: 'event'})")
          ),
          actionButton(
            session$ns("btn_details_close"),
            "Sluiten",
            class = "btn-outline-secondary ms-2"
          )
        )
      ))
    }
    
    # Show edit modal (pre-filled form)
    show_zaak_edit_modal <- function(zaak_data) {
      showModal(modalDialog(
        title = paste("Zaak Bewerken:", zaak_data$zaak_id),
        size = "l",
        easyClose = FALSE,
        
        # Form content (same as new case but pre-filled)
        div(
          # Form validation messages area
          div(
            id = session$ns("edit_form_validation_messages"),
            style = "min-height: 20px;"
          ),
          
          # Edit form with pre-filled values
          div(
            class = "row",
            
            # Left column
            div(
              class = "col-md-6",
              
              textInput(
                session$ns("edit_form_zaak_id"),
                "Zaak ID: *",
                value = zaak_data$zaak_id
              ),
              
              dateInput(
                session$ns("edit_form_datum_aanmaak"),
                "Datum Aanmaak: *",
                value = as.Date(zaak_data$datum_aanmaak),
                format = "dd-mm-yyyy",
                language = "nl"
              ),
              
              textAreaInput(
                session$ns("edit_form_omschrijving"),
                "Omschrijving: *",
                value = ifelse(is.na(zaak_data$omschrijving), "", zaak_data$omschrijving),
                rows = 3
              ),
              
              selectInput(
                session$ns("edit_form_aanvragende_directie"),
                "Aanvragende Directie: *",
                choices = c("Selecteer..." = "", dropdown_choices$aanvragende_directie),
                selected = ifelse(is.na(zaak_data$aanvragende_directie), "", zaak_data$aanvragende_directie)
              )
            ),
            
            # Right column
            div(
              class = "col-md-6",
              
              selectInput(
                session$ns("edit_form_type_dienst"),
                "Type Dienst: *",
                choices = c("Selecteer..." = "", dropdown_choices$type_dienst),
                selected = ifelse(is.na(zaak_data$type_dienst), "", zaak_data$type_dienst),
                multiple = FALSE
              ),
              
              selectInput(
                session$ns("edit_form_rechtsgebied"),
                "Rechtsgebied: *",
                choices = c("Selecteer..." = "", dropdown_choices$rechtsgebied),
                selected = ifelse(is.na(zaak_data$rechtsgebied), "", zaak_data$rechtsgebied)
              ),
              
              selectInput(
                session$ns("edit_form_status_zaak"),
                "Status: *",
                choices = c("Selecteer..." = "", dropdown_choices$status_zaak),
                selected = ifelse(is.na(zaak_data$status_zaak), "", zaak_data$status_zaak)
              ),
              
              textInput(
                session$ns("edit_form_advocaat"),
                "Advocaat:",
                value = ifelse(is.na(zaak_data$advocaat), "", zaak_data$advocaat)
              )
            )
          ),
          
          # Optional fields section
          hr(),
          h6("Optionele Velden", class = "text-muted"),
          
          div(
            class = "row",
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("edit_form_la_budget_wjz"),
                "Budget WJZ (€):",
                value = ifelse(is.na(zaak_data$la_budget_wjz), 0, zaak_data$la_budget_wjz),
                min = 0,
                step = 1000
              )
            ),
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("edit_form_budget_andere_directie"),
                "Budget Andere Directie (€):",
                value = ifelse(is.na(zaak_data$budget_andere_directie), 0, zaak_data$budget_andere_directie),
                min = 0,
                step = 1000
              )
            ),
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("edit_form_financieel_risico"),
                "Financieel Risico (€):",
                value = ifelse(is.na(zaak_data$financieel_risico), 0, zaak_data$financieel_risico),
                min = 0,
                step = 10000
              )
            )
          ),
          
          div(
            class = "row mt-3",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("edit_form_opmerkingen"),
                "Opmerkingen:",
                value = ifelse(is.na(zaak_data$opmerkingen), "", zaak_data$opmerkingen),
                rows = 2
              )
            )
          ),
          
          # Note: Original zaak_id is stored in reactive value
        ),
        
        # Modal footer
        footer = div(
          div(class = "text-muted small float-start", "* Verplichte velden"),
          div(
            class = "float-end",
            actionButton(
              session$ns("btn_edit_form_cancel"),
              "Annuleren",
              class = "btn-outline-secondary"
            ),
            actionButton(
              session$ns("btn_edit_form_save"),
              "Bijwerken",
              class = "btn-primary ms-2",
              icon = icon("save")
            )
          )
        )
      ))
    }
    
    # ========================================================================
    # NIEUWE ZAAK MODAL
    # ========================================================================
    
    # Show new case modal
    show_nieuwe_zaak_modal <- function() {
      showModal(modalDialog(
        title = "Nieuwe Zaak Toevoegen",
        size = "l",
        easyClose = FALSE,
        
        # Form content
        div(
          # Form validation messages area
          div(
            id = session$ns("form_validation_messages"),
            style = "min-height: 20px;"
          ),
          
          # Simple form with essential fields only
          div(
            class = "row",
            
            # Left column
            div(
              class = "col-md-6",
              
              textInput(
                session$ns("form_zaak_id"),
                "Zaak ID: *",
                placeholder = "bijv. WJZ/LA/2024/001"
              ),
              
              dateInput(
                session$ns("form_datum_aanmaak"),
                "Datum Aanmaak: *",
                value = Sys.Date(),
                format = "dd-mm-yyyy",
                language = "nl"
              ),
              
              textAreaInput(
                session$ns("form_omschrijving"),
                "Omschrijving: *",
                rows = 3,
                placeholder = "Korte beschrijving van de zaak..."
              ),
              
              selectInput(
                session$ns("form_aanvragende_directie"),
                "Aanvragende Directie: *",
                choices = c("Selecteer..." = "", dropdown_choices$aanvragende_directie)
              )
            ),
            
            # Right column
            div(
              class = "col-md-6",
              
              selectInput(
                session$ns("form_type_dienst"),
                "Type Dienst: *",
                choices = c("Selecteer..." = "", dropdown_choices$type_dienst),
                multiple = FALSE
              ),
              
              selectInput(
                session$ns("form_rechtsgebied"),
                "Rechtsgebied: *",
                choices = c("Selecteer..." = "", dropdown_choices$rechtsgebied)
              ),
              
              selectInput(
                session$ns("form_status_zaak"),
                "Status: *",
                choices = c("Selecteer..." = "", dropdown_choices$status_zaak)
              ),
              
              textInput(
                session$ns("form_advocaat"),
                "Advocaat:",
                placeholder = "Naam van de advocaat"
              )
            )
          ),
          
          # Optional fields section
          hr(),
          h6("Optionele Velden", class = "text-muted"),
          
          div(
            class = "row",
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("form_la_budget_wjz"),
                "Budget WJZ (€):",
                value = 0,
                min = 0,
                step = 1000
              )
            ),
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("form_budget_andere_directie"),
                "Budget Andere Directie (€):",
                value = 0,
                min = 0,
                step = 1000
              )
            ),
            
            div(
              class = "col-md-4",
              numericInput(
                session$ns("form_financieel_risico"),
                "Financieel Risico (€):",
                value = 0,
                min = 0,
                step = 10000
              )
            )
          ),
          
          div(
            class = "row mt-3",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("form_opmerkingen"),
                "Opmerkingen:",
                rows = 2,
                placeholder = "Aanvullende opmerkingen over deze zaak..."
              )
            )
          )
        ),
        
        # Modal footer
        footer = div(
          div(class = "text-muted small float-start", "* Verplichte velden"),
          div(
            class = "float-end",
            actionButton(
              session$ns("btn_form_cancel"),
              "Annuleren",
              class = "btn-outline-secondary"
            ),
            actionButton(
              session$ns("btn_form_save"),
              "Opslaan",
              class = "btn-primary ms-2",
              icon = icon("save")
            )
          )
        )
      ))
    }
    
    # ========================================================================
    # SIMPLE BUTTON ACTIONS
    # ========================================================================
    
    # Refresh button
    observeEvent(input$btn_refresh, {
      cli_alert_info("Manual data refresh requested by user: {current_user()}")
      data_refresh_trigger(data_refresh_trigger() + 1)
      show_notification("Data ververst", type = "message")
    })
    
    # Nieuwe zaak button - show modal
    observeEvent(input$btn_nieuwe_zaak, {
      cli_alert_info("New case button clicked by user: {current_user()}")
      show_nieuwe_zaak_modal()
    })
    
    # ========================================================================
    # DELETE EVENT HANDLERS
    # ========================================================================
    
    # Handle delete button click from details modal
    observeEvent(input$delete_zaak_id, {
      
      zaak_id <- input$delete_zaak_id
      cli_alert_info("Delete requested for zaak: {zaak_id}")
      
      # Get case data for confirmation
      all_data <- raw_data()
      zaak_data <- all_data[all_data$zaak_id == zaak_id, ]
      
      if (nrow(zaak_data) > 0) {
        showModal(modalDialog(
          title = "Zaak Verwijderen",
          size = "m",
          easyClose = FALSE,
          
          div(
            div(
              class = "alert alert-warning",
              icon("exclamation-triangle"), " ",
              paste("Weet je zeker dat je zaak", strong(zaak_id), "permanent wilt verwijderen?")
            ),
            p(strong("Omschrijving: "), zaak_data$omschrijving[1]),
            p(class = "text-danger", strong("LET OP: "), "De zaak wordt permanent verwijderd uit de database en kan niet worden hersteld!")
          ),
          
          footer = div(
            actionButton(
              session$ns("btn_delete_zaak_cancel"),
              "Annuleren",
              class = "btn-outline-secondary"
            ),
            actionButton(
              session$ns("btn_delete_zaak_confirm"),
              "Permanent Verwijderen",
              class = "btn-danger ms-2",
              icon = icon("trash")
            )
          )
        ))
      }
    })
    
    # Cancel delete zaak
    observeEvent(input$btn_delete_zaak_cancel, {
      removeModal()
    })
    
    # Confirm delete zaak
    observeEvent(input$btn_delete_zaak_confirm, {
      zaak_id <- input$delete_zaak_id
      req(zaak_id)
      
      tryCatch({
        # Use existing delete function - hard delete to permanently remove
        success <- verwijder_zaak(zaak_id, hard_delete = TRUE)
        
        if (success) {
          cli_alert_success("Case permanently deleted: {zaak_id}")
          show_notification(paste("Zaak permanent verwijderd:", zaak_id), type = "message")
          
          # Trigger data refresh
          data_refresh_trigger(data_refresh_trigger() + 1)
          
          # Close both modals (confirmation and details)
          removeModal()
          
        } else {
          show_notification("Fout bij verwijderen zaak", type = "error")
        }
        
      }, error = function(e) {
        cli_alert_danger("Error deleting case: {e$message}")
        show_notification("Fout bij verwijderen zaak", type = "error")
      })
    })
    
    # ========================================================================
    # EDIT MODAL EVENT HANDLERS
    # ========================================================================
    
    # Handle edit button click from details modal
    observeEvent(input$edit_zaak_id, {
      
      zaak_id <- input$edit_zaak_id
      cli_alert_info("Edit requested for zaak: {zaak_id}")
      
      # Get full case data from database
      all_data <- raw_data()
      zaak_data <- all_data[all_data$zaak_id == zaak_id, ]
      
      if (nrow(zaak_data) > 0) {
        # Store original zaak_id in reactive value
        original_zaak_id(zaak_id)
        
        # Close current modal and show edit modal
        removeModal()
        show_zaak_edit_modal(zaak_data[1, ])
      }
    })
    
    # Close details modal
    observeEvent(input$btn_details_close, {
      removeModal()
    })
    
    # ========================================================================
    # EDIT FORM VALIDATION & SAVING
    # ========================================================================
    
    # Edit form validation
    edit_form_valid <- reactive({
      
      # Check required fields
      valid <- TRUE
      errors <- c()
      
      if (is.null(input$edit_form_zaak_id) || input$edit_form_zaak_id == "") {
        valid <- FALSE
        errors <- c(errors, "Zaak ID is verplicht")
      }
      
      if (is.null(input$edit_form_omschrijving) || input$edit_form_omschrijving == "") {
        valid <- FALSE
        errors <- c(errors, "Omschrijving is verplicht")
      }
      
      if (is.null(input$edit_form_aanvragende_directie) || input$edit_form_aanvragende_directie == "") {
        valid <- FALSE
        errors <- c(errors, "Aanvragende directie is verplicht")
      }
      
      if (is.null(input$edit_form_type_dienst) || input$edit_form_type_dienst == "") {
        valid <- FALSE
        errors <- c(errors, "Type dienst is verplicht")
      }
      
      if (is.null(input$edit_form_rechtsgebied) || input$edit_form_rechtsgebied == "") {
        valid <- FALSE
        errors <- c(errors, "Rechtsgebied is verplicht")
      }
      
      if (is.null(input$edit_form_status_zaak) || input$edit_form_status_zaak == "") {
        valid <- FALSE
        errors <- c(errors, "Status is verplicht")
      }
      
      # Check if zaak_id changed and already exists
      if (!is.null(input$edit_form_zaak_id) && !is.null(original_zaak_id())) {
        if (input$edit_form_zaak_id != original_zaak_id()) {
          existing_ids <- raw_data()$zaak_id
          if (input$edit_form_zaak_id %in% existing_ids) {
            valid <- FALSE
            errors <- c(errors, "Deze Zaak ID bestaat al")
          }
        }
      }
      
      list(valid = valid, errors = errors)
    })
    
    # Display edit validation messages
    output$edit_form_validation_messages <- renderUI({
      validation <- edit_form_valid()
      
      if (!validation$valid && length(validation$errors) > 0) {
        div(
          class = "alert alert-warning",
          icon("exclamation-triangle"), " ",
          strong("Controleer de volgende velden:"),
          tags$ul(
            lapply(validation$errors, function(error) {
              tags$li(error)
            })
          )
        )
      }
    })
    
    # Cancel edit button
    observeEvent(input$btn_edit_form_cancel, {
      removeModal()
    })
    
    # Save edit button
    observeEvent(input$btn_edit_form_save, {
      
      validation <- edit_form_valid()
      
      if (!validation$valid) {
        show_notification("Controleer de formulier velden", type = "warning")
        return()
      }
      
      tryCatch({
        
        # Prepare updated form data
        updated_data <- data.frame(
          zaak_id = input$edit_form_zaak_id,
          datum_aanmaak = as.character(input$edit_form_datum_aanmaak),
          omschrijving = input$edit_form_omschrijving,
          aanvragende_directie = input$edit_form_aanvragende_directie,
          type_dienst = input$edit_form_type_dienst,
          rechtsgebied = input$edit_form_rechtsgebied,
          status_zaak = input$edit_form_status_zaak,
          advocaat = if(is.null(input$edit_form_advocaat) || input$edit_form_advocaat == "") NA else input$edit_form_advocaat,
          la_budget_wjz = if(is.null(input$edit_form_la_budget_wjz)) 0 else input$edit_form_la_budget_wjz,
          budget_andere_directie = if(is.null(input$edit_form_budget_andere_directie)) 0 else input$edit_form_budget_andere_directie,
          financieel_risico = if(is.null(input$edit_form_financieel_risico)) 0 else input$edit_form_financieel_risico,
          opmerkingen = if(is.null(input$edit_form_opmerkingen) || input$edit_form_opmerkingen == "") NA else input$edit_form_opmerkingen,
          stringsAsFactors = FALSE
        )
        
        # Update in database using original zaak_id
        original_id <- original_zaak_id()
        
        # Use direct SQL update to avoid parameter issues
        tryCatch({
          con <- get_db_connection()
          
          # Build UPDATE query with individual fields
          DBI::dbExecute(con, "
            UPDATE zaken SET 
              zaak_id = ?,
              datum_aanmaak = ?,
              omschrijving = ?,
              aanvragende_directie = ?,
              type_dienst = ?,
              rechtsgebied = ?,
              status_zaak = ?,
              advocaat = ?,
              la_budget_wjz = ?,
              budget_andere_directie = ?,
              financieel_risico = ?,
              opmerkingen = ?,
              laatst_gewijzigd = ?,
              gewijzigd_door = ?
            WHERE zaak_id = ?
          ", list(
            updated_data$zaak_id,
            updated_data$datum_aanmaak,
            updated_data$omschrijving,
            updated_data$aanvragende_directie,
            updated_data$type_dienst,
            updated_data$rechtsgebied,
            updated_data$status_zaak,
            updated_data$advocaat,
            updated_data$la_budget_wjz,
            updated_data$budget_andere_directie,
            updated_data$financieel_risico,
            updated_data$opmerkingen,
            as.character(Sys.time()),
            current_user(),
            original_id
          ))
          
          close_db_connection(con)
          
        }, error = function(e) {
          if (exists("con") && DBI::dbIsValid(con)) {
            close_db_connection(con)
          }
          stop(e$message)
        })
        
        cli_alert_success("Case updated: {original_id} -> {updated_data$zaak_id}")
        show_notification(paste("Zaak bijgewerkt:", updated_data$zaak_id), type = "message")
        
        # Trigger data refresh
        data_refresh_trigger(data_refresh_trigger() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error updating case: {e$message}")
        show_notification("Fout bij bijwerken zaak", type = "error")
      })
    })
    
    # ========================================================================
    # FORM VALIDATION & SAVING (NEW CASE)
    # ========================================================================
    
    # Form validation
    form_valid <- reactive({
      
      # Check required fields
      valid <- TRUE
      errors <- c()
      
      if (is.null(input$form_zaak_id) || input$form_zaak_id == "") {
        valid <- FALSE
        errors <- c(errors, "Zaak ID is verplicht")
      }
      
      if (is.null(input$form_omschrijving) || input$form_omschrijving == "") {
        valid <- FALSE
        errors <- c(errors, "Omschrijving is verplicht")
      }
      
      if (is.null(input$form_aanvragende_directie) || input$form_aanvragende_directie == "") {
        valid <- FALSE
        errors <- c(errors, "Aanvragende directie is verplicht")
      }
      
      if (is.null(input$form_type_dienst) || input$form_type_dienst == "") {
        valid <- FALSE
        errors <- c(errors, "Type dienst is verplicht")
      }
      
      if (is.null(input$form_rechtsgebied) || input$form_rechtsgebied == "") {
        valid <- FALSE
        errors <- c(errors, "Rechtsgebied is verplicht")
      }
      
      if (is.null(input$form_status_zaak) || input$form_status_zaak == "") {
        valid <- FALSE
        errors <- c(errors, "Status is verplicht")
      }
      
      # Check if zaak_id already exists
      if (!is.null(input$form_zaak_id) && input$form_zaak_id != "") {
        existing_ids <- raw_data()$zaak_id
        if (input$form_zaak_id %in% existing_ids) {
          valid <- FALSE
          errors <- c(errors, "Deze Zaak ID bestaat al")
        }
      }
      
      list(valid = valid, errors = errors)
    })
    
    # Display validation messages
    output$form_validation_messages <- renderUI({
      validation <- form_valid()
      
      if (!validation$valid && length(validation$errors) > 0) {
        div(
          class = "alert alert-warning",
          icon("exclamation-triangle"), " ",
          strong("Controleer de volgende velden:"),
          tags$ul(
            lapply(validation$errors, function(error) {
              tags$li(error)
            })
          )
        )
      }
    })
    
    # Cancel button
    observeEvent(input$btn_form_cancel, {
      removeModal()
    })
    
    # Save button
    observeEvent(input$btn_form_save, {
      
      validation <- form_valid()
      
      if (!validation$valid) {
        show_notification("Controleer de formulier velden", type = "warning")
        return()
      }
      
      tryCatch({
        
        # Prepare form data
        form_data <- data.frame(
          zaak_id = input$form_zaak_id,
          datum_aanmaak = as.character(input$form_datum_aanmaak),
          omschrijving = input$form_omschrijving,
          aanvragende_directie = input$form_aanvragende_directie,
          type_dienst = input$form_type_dienst,
          rechtsgebied = input$form_rechtsgebied,
          status_zaak = input$form_status_zaak,
          advocaat = if(is.null(input$form_advocaat) || input$form_advocaat == "") NA else input$form_advocaat,
          la_budget_wjz = if(is.null(input$form_la_budget_wjz)) 0 else input$form_la_budget_wjz,
          budget_andere_directie = if(is.null(input$form_budget_andere_directie)) 0 else input$form_budget_andere_directie,
          financieel_risico = if(is.null(input$form_financieel_risico)) 0 else input$form_financieel_risico,
          opmerkingen = if(is.null(input$form_opmerkingen) || input$form_opmerkingen == "") NA else input$form_opmerkingen,
          stringsAsFactors = FALSE
        )
        
        # Save to database using direct SQL to avoid type issues
        tryCatch({
          con <- get_db_connection()
          
          # Insert new case with proper data types
          DBI::dbExecute(con, "
            INSERT INTO zaken (
              zaak_id, datum_aanmaak, omschrijving, aanvragende_directie,
              type_dienst, rechtsgebied, status_zaak, advocaat,
              la_budget_wjz, budget_andere_directie, financieel_risico,
              opmerkingen, aangemaakt_door, laatst_gewijzigd
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ", list(
            form_data$zaak_id,
            form_data$datum_aanmaak,
            form_data$omschrijving,
            form_data$aanvragende_directie,
            form_data$type_dienst,
            form_data$rechtsgebied,
            form_data$status_zaak,
            form_data$advocaat,
            as.numeric(form_data$la_budget_wjz),        # Ensure numeric
            as.numeric(form_data$budget_andere_directie), # Ensure numeric
            as.numeric(form_data$financieel_risico),    # Ensure numeric
            form_data$opmerkingen,
            current_user(),
            as.character(Sys.time())  # Consistent string format
          ))
          
          close_db_connection(con)
          
        }, error = function(e) {
          if (exists("con") && DBI::dbIsValid(con)) {
            close_db_connection(con)
          }
          stop(e$message)
        })
        
        cli_alert_success("New case created: {form_data$zaak_id}")
        show_notification(paste("Nieuwe zaak toegevoegd:", form_data$zaak_id), type = "message")
        
        # Trigger data refresh
        data_refresh_trigger(data_refresh_trigger() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error saving case: {e$message}")
        show_notification("Fout bij opslaan zaak", type = "error")
      })
    })
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    return(list(
      # Statistics
      get_stats = reactive({
        list(
          total = nrow(raw_data()),
          filtered = nrow(filtered_data()),
          open = sum(filtered_data()$status_zaak %in% c("Open", "In_behandeling"), na.rm = TRUE),
          recent = sum(format(filtered_data()$datum_aanmaak, "%Y-%m") == format(Sys.Date(), "%Y-%m"), na.rm = TRUE)
        )
      }),
      
      # Data refresh function
      refresh_data = function() {
        data_refresh_trigger(data_refresh_trigger() + 1)
      }
    ))
  })
}