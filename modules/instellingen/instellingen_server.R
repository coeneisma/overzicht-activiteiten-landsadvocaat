# modules/instellingen/instellingen_server.R
# =============================================

#' Instellingen Module Server
#' 
#' Admin functionality for user and dropdown management
#' 
#' @param id Module namespace ID
#' @param current_user Reactive containing current username
#' @param is_admin Reactive indicating if user is admin
#' @param global_dropdown_refresh_trigger Reactive trigger for global dropdown refresh
#' @return List with reactive values and functions
instellingen_server <- function(id, current_user, is_admin, global_dropdown_refresh_trigger = NULL) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES
    # ========================================================================
    
    # Currently selected dropdown category
    selected_category <- reactiveVal(NULL)
    
    # Data refresh triggers
    users_refresh <- reactiveVal(0)
    dropdown_refresh <- reactiveVal(0)
    
    # Click tracking for duplicate prevention
    last_clicked_dropdown_info <- reactiveVal(NULL)
    last_clicked_user_info <- reactiveVal(NULL)
    
    # Store original value for editing
    editing_original_waarde <- reactiveVal(NULL)
    
    # Store username being edited
    editing_username <- reactiveVal(NULL)
    
    # ========================================================================
    # USER MANAGEMENT
    # ========================================================================
    
    # Load users data
    users_data <- reactive({
      users_refresh()  # Trigger refresh
      
      req(is_admin())
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        DBI::dbGetQuery(con, "
          SELECT gebruikersnaam, rol, actief, 
                 aangemaakt_op, laatste_login as laatst_ingelogd
          FROM gebruikers 
          ORDER BY gebruikersnaam
        ")
      }, error = function(e) {
        cli_alert_danger("Error loading users: {e$message}")
        data.frame()
      })
    })
    
    # Users table output
    output$users_table <- DT::renderDataTable({
      
      data <- users_data()
      
      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen gebruikers gevonden"),
          options = list(searching = FALSE, paging = FALSE, info = FALSE),
          rownames = FALSE
        ))
      }
      
      # Format data for display
      display_data <- data %>%
        mutate(
          `Actief` = ifelse(actief == 1, "Ja", "Nee"),
          `Aangemaakt` = format_date_nl(as.Date(aangemaakt_op)),
          `Laatst Ingelogd` = ifelse(is.na(laatst_ingelogd), "Nooit", 
                                   format_date_nl(as.Date(laatst_ingelogd))),
          `Acties` = ifelse(gebruikersnaam %in% c("admin", "system"), 
                           "", # No delete button for admin and system
                           '<button class="btn btn-sm btn-outline-danger"><i class="fa fa-trash"></i></button>')
        ) %>%
        select(
          "Gebruikersnaam" = gebruikersnaam,
          "Rol" = rol,
          "Actief" = Actief,
          "Aangemaakt" = Aangemaakt,
          "Laatst Ingelogd" = `Laatst Ingelogd`,
          "Acties" = Acties
        )
      
      DT::datatable(
        display_data,
        selection = 'none',  # Disable row selection highlighting
        options = list(
          pageLength = 10,
          searching = TRUE,
          dom = 'frtip',
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ gebruikers",
            infoEmpty = "Geen gebruikers beschikbaar",
            paginate = list(
              first = "Eerste", last = "Laatste",
              "next" = "Volgende", previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE,
        callback = DT::JS("
          table.on('click', '.btn-outline-danger', function(e) {
            e.stopPropagation(); // Prevent row click event
            var username = $(this).closest('tr').find('td:first').text();
            console.log('Delete button clicked for user:', username);
            Shiny.setInputValue('instellingen-delete_user', username, {priority: 'event'});
          });
        ")
      )
      
    }, server = TRUE)
    
    # Handle users table row clicks for edit (but not on action buttons)
    observeEvent(input$users_table_cell_clicked, {
      
      info <- input$users_table_cell_clicked
      
      if (!is.null(info$row) && info$row > 0) {
        
        # Don't open edit modal if clicked on Actions column (last column)
        data <- users_data()
        if (is.null(data) || nrow(data) == 0) return()
        
        # Actions column is the last column (index 5: Gebruikersnaam, Rol, Actief, Aangemaakt, Laatst Ingelogd, Acties)
        if (!is.null(info$col) && info$col >= 5) {
          return()  # Ignore clicks on Actions column
        }
        
        # Simple duplicate prevention
        current_info <- paste0(info$row, "_", info$col)
        if (!is.null(last_clicked_user_info()) && current_info == last_clicked_user_info()) {
          return()  # Ignore duplicate clicks
        }
        last_clicked_user_info(current_info)
        
        if (info$row <= nrow(data)) {
          
          # Get the clicked user
          selected_user <- data[info$row, ]
          username <- selected_user$gebruikersnaam
          
          cli_alert_info("Users table row clicked for: {username}")
          show_edit_user_modal(selected_user)
        }
      }
    })
    
    # ========================================================================
    # DROPDOWN MANAGEMENT
    # ========================================================================
    
    # Handle category selection
    observeEvent(input$selected_category, {
      cli_alert_info("Category selection event triggered: {input$selected_category}")
      selected_category(input$selected_category)
      cli_alert_info("Selected dropdown category stored: {selected_category()}")
    })
    
    # Category title
    output$category_title <- renderText({
      category <- selected_category()
      if (is.null(category)) return("Selecteer een categorie")
      
      switch(category,
        "type_dienst" = "Type Dienst Waarden",
        "rechtsgebied" = "Rechtsgebied Waarden", 
        "status_zaak" = "Status Zaak Waarden",
        "aanvragende_directie" = "Aanvragende Directie Waarden",
        "type_wederpartij" = "Type Wederpartij Waarden",
        "reden_inzet" = "Reden Inzet Waarden",
        "hoedanigheid_partij" = "Hoedanigheid Partij Waarden",
        "Onbekende Categorie"
      )
    })
    
    # Load dropdown counts
    dropdown_counts <- reactive({
      dropdown_refresh()  # Trigger refresh
      
      req(is_admin())
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        counts <- DBI::dbGetQuery(con, "
          SELECT categorie, COUNT(*) as count
          FROM dropdown_opties 
          WHERE actief = 1
          GROUP BY categorie
        ")
        
        # Convert to named list for easy access
        setNames(counts$count, counts$categorie)
        
      }, error = function(e) {
        cli_alert_danger("Error loading dropdown counts: {e$message}")
        list()
      })
    })
    
    # Helper function for safe count access
    get_safe_count <- function(counts, category) {
      tryCatch({
        count <- counts[[category]]
        as.character(if(is.null(count) || length(count) == 0) 0 else count)
      }, error = function(e) {
        cli_alert_warning("Error getting count for {category}: {e$message}")
        "0"
      })
    }
    
    # Category count outputs
    output$count_type_dienst <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "type_dienst")
    })
    
    output$count_rechtsgebied <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "rechtsgebied")
    })
    
    output$count_status_zaak <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "status_zaak")
    })
    
    output$count_aanvragende_directie <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "aanvragende_directie")
    })
    
    output$count_type_wederpartij <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "type_wederpartij")
    })
    
    output$count_reden_inzet <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "reden_inzet")
    })
    
    output$count_hoedanigheid_partij <- renderText({
      counts <- dropdown_counts()
      get_safe_count(counts, "hoedanigheid_partij")
    })
    
    # Load dropdown values for selected category
    dropdown_values_data <- reactive({
      category <- selected_category()
      req(category)
      
      dropdown_refresh()  # Trigger refresh
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        DBI::dbGetQuery(con, "
          SELECT waarde, weergave_naam, actief, kleur,
                 aangemaakt_door, aangemaakt_op
          FROM dropdown_opties 
          WHERE categorie = ?
          ORDER BY weergave_naam
        ", list(category))
        
      }, error = function(e) {
        cli_alert_danger("Error loading dropdown values: {e$message}")
        data.frame()
      })
    })
    
    # Dropdown values table
    output$dropdown_values_table <- DT::renderDataTable({
      
      data <- dropdown_values_data()
      
      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen waarden gevonden voor deze categorie"),
          options = list(searching = FALSE, paging = FALSE, info = FALSE),
          rownames = FALSE
        ))
      }
      
      # Debug: print waarden to console
      if (nrow(data) > 0) {
        cli_alert_info("Processing dropdown values for category {selected_category()}: {paste(data$waarde, collapse=', ')}")
        protected_values <- data$waarde[data$waarde == "niet_ingesteld" | 
                                       (!is.na(data$weergave_naam) & data$weergave_naam == "Niet ingesteld") |
                                       data$waarde == "Niet ingesteld"]
        if (length(protected_values) > 0) {
          cli_alert_info("Protected values found: {paste(protected_values, collapse=', ')}")
        }
      }
      
      # Format data for display
      display_data <- data %>%
        mutate(
          `Weergave Naam` = ifelse(is.na(weergave_naam) | weergave_naam == "", 
                                 waarde, weergave_naam),
          `Actief` = ifelse(actief == 1, "Ja", "Nee"),
          `Kleur` = ifelse(is.na(kleur) | kleur == "", 
                          "", 
                          paste0('<span style="background-color: ', kleur, '; color: white; padding: 2px 8px; border-radius: 3px; font-size: 12px;">', kleur, '</span>')),
          `Aangemaakt` = format_date_nl(as.Date(aangemaakt_op)),
          # Don't show delete button for "niet_ingesteld" values or "Niet ingesteld" display names
          is_protected = waarde == "niet_ingesteld" | 
                        (!is.na(weergave_naam) & weergave_naam == "Niet ingesteld") |
                        waarde == "Niet ingesteld",
          `Acties` = ifelse(is_protected, 
                           "", # No delete button for protected values
                           paste0('<button class="btn btn-sm btn-outline-danger delete-dropdown-btn" data-waarde="', 
                                 waarde, '"><i class="fa fa-trash"></i></button>'))
        ) %>%
        select(
          "Waarde" = `Weergave Naam`,
          "Actief" = Actief,
          "Kleur" = Kleur,
          "Door" = aangemaakt_door,
          "Aangemaakt" = Aangemaakt,
          "Acties" = Acties
        )
      
      DT::datatable(
        display_data,
        selection = 'none',  # Disable row selection highlighting
        options = list(
          pageLength = 15,
          searching = FALSE,
          dom = 'frtip',
          language = list(
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ waarden",
            infoEmpty = "Geen waarden beschikbaar",
            paginate = list(
              first = "Eerste", last = "Laatste",
              "next" = "Volgende", previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE,
        callback = DT::JS("
          table.on('click', '.delete-dropdown-btn', function(e) {
            e.stopPropagation(); // Prevent row click event
            var waarde = $(this).attr('data-waarde');
            console.log('Delete dropdown button clicked for value:', waarde);
            Shiny.setInputValue('instellingen-delete_dropdown', waarde, {priority: 'event'});
          });
        ")
      )
      
    }, server = TRUE)
    
    # Handle dropdown table row clicks for edit
    observeEvent(input$dropdown_values_table_cell_clicked, {
      
      info <- input$dropdown_values_table_cell_clicked
      cli_alert_info("Dropdown table cell clicked - Row: {info$row}, Col: {info$col}")
      
      if (!is.null(info$row) && info$row > 0 && !is.null(selected_category())) {
        
        # Don't open edit modal if clicked on Actions column (last column)
        data <- dropdown_values_data()
        if (is.null(data) || nrow(data) == 0) {
          cli_alert_warning("No data available for edit modal")
          return()
        }
        
        # Actions column is the last column (index 4: Waarde, Actief, Door, Aangemaakt, Acties)
        # DT uses 0-based indexing, so Actions column is index 4
        if (!is.null(info$col) && info$col == 4) {
          cli_alert_info("Click on Actions column (col {info$col}), ignoring")
          return()  # Ignore clicks on Actions column
        }
        
        # Simple duplicate prevention
        current_info <- paste0(info$row, "_", info$col)
        if (!is.null(last_clicked_dropdown_info()) && current_info == last_clicked_dropdown_info()) {
          return()  # Ignore duplicate clicks
        }
        last_clicked_dropdown_info(current_info)
        
        if (nrow(data) > 0 && info$row <= nrow(data)) {
          
          # Get the clicked dropdown value
          selected_value <- data[info$row, ]
          waarde <- selected_value$waarde
          category <- selected_category()
          
          cli_alert_info("Dropdown table row clicked for: {category}/{waarde}")
          show_edit_dropdown_modal(selected_value, category)
        }
      }
    })
    
    # Delete dropdown value handler
    observeEvent(input$delete_dropdown, {
      cli_alert_info("Delete dropdown event triggered: {input$delete_dropdown}")
      req(is_admin(), input$delete_dropdown, selected_category())
      
      waarde <- input$delete_dropdown
      category <- selected_category()
      cli_alert_info("Delete dropdown processing: {category}/{waarde}")
      cli_alert_info("Waarde details: '{waarde}' (length: {nchar(waarde)}, class: {class(waarde)})")
      
      # Prevent deleting protected values (comprehensive check)
      if (waarde == "niet_ingesteld" || waarde == "Niet ingesteld" || 
          tolower(waarde) == "niet ingesteld" || grepl("niet.{0,5}ingesteld", tolower(waarde))) {
        show_notification("Deze waarde kan niet worden verwijderd", type = "error")
        return()
      }
      
      # Validate supported categories
      supported_categories <- c("type_dienst", "rechtsgebied", "status_zaak", "aanvragende_directie",
                                "type_wederpartij", "reden_inzet", "hoedanigheid_partij")
      if (!category %in% supported_categories) {
        show_notification("Deze categorie ondersteunt geen verwijderen", type = "error")
        return()
      }
      
      # Get weergave naam for display in modal
      weergave_naam <- get_weergave_naam_cached(category, waarde)
      display_name <- if (!is.null(weergave_naam) && !is.na(weergave_naam) && weergave_naam != "") {
        weergave_naam
      } else {
        waarde
      }
      
      showModal(modalDialog(
        title = "Dropdown Waarde Verwijderen",
        size = "m",
        easyClose = TRUE,
        
        div(
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            HTML(paste("Weet je zeker dat je de waarde <strong>", display_name, "</strong> wilt verwijderen?"))
          ),
          p("Als deze waarde in gebruik is bij bestaande zaken, wordt deze vervangen door 'Niet ingesteld'.")
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_delete_dropdown_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_delete_dropdown_confirm"),
            "Verwijderen",
            class = "btn-danger ms-2",
            icon = icon("trash")
          )
        )
      ))
    })
    
    # Cancel delete dropdown
    observeEvent(input$btn_delete_dropdown_cancel, {
      removeModal()
    })
    
    # Confirm delete dropdown
    observeEvent(input$btn_delete_dropdown_confirm, {
      waarde <- input$delete_dropdown
      category <- selected_category()
      req(is_admin(), waarde, category)
      
      cli_alert_info("Attempting to delete dropdown value: '{waarde}' from category: '{category}'")
      
      tryCatch({
        # Gebruik de nieuwe database functie
        result <- verwijder_dropdown_optie(category, waarde, current_user())
        
        cli_alert_info("Delete result: success={result$success}, zaken_updated={result$zaken_updated}")
        
        if (result$success) {
          cli_alert_success("Dropdown value deleted: {category}/{waarde}")
          
          if (result$zaken_updated > 0) {
            show_notification(
              paste("Waarde", waarde, "verwijderd.", result$zaken_updated, "zaken bijgewerkt naar 'Niet ingesteld'."), 
              type = "message"
            )
          } else {
            show_notification(paste("Waarde", waarde, "succesvol verwijderd."), type = "message")
          }
          
          # Refresh dropdowns locally and globally
          dropdown_refresh(dropdown_refresh() + 1)
          if (!is.null(global_dropdown_refresh_trigger)) {
            global_dropdown_refresh_trigger(global_dropdown_refresh_trigger() + 1)
          }
          
        } else {
          cli_alert_danger("Error deleting dropdown value: {result$error}")
          show_notification("Fout bij verwijderen dropdown waarde", type = "error")
        }
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error deleting dropdown value: {e$message}")
        show_notification("Fout bij verwijderen dropdown waarde", type = "error")
        removeModal()
      })
    })
    
    # ========================================================================
    # ADD USER MODAL
    # ========================================================================
    
    # Show add user modal
    observeEvent(input$btn_add_user, {
      req(is_admin())
      
      showModal(modalDialog(
        title = "Nieuwe Gebruiker Toevoegen",
        size = "m",
        easyClose = FALSE,
        
        div(
          # Form validation messages
          div(id = session$ns("user_form_messages")),
          
          # User form
          div(
            class = "row",
            
            div(
              class = "col-12",
              
              textInput(
                session$ns("new_user_username"),
                "Gebruikersnaam: *",
                placeholder = "bijv. j.janssen"
              ),
              
              passwordInput(
                session$ns("new_user_password"),
                "Wachtwoord: *",
                placeholder = "Minimaal 6 karakters"
              ),
              
              passwordInput(
                session$ns("new_user_password_confirm"),
                "Bevestig Wachtwoord: *",
                placeholder = "Herhaal het wachtwoord"
              ),
              
              selectInput(
                session$ns("new_user_role"),
                "Rol: *",
                choices = list(
                  "Gebruiker" = "gebruiker",
                  "Administrator" = "admin"
                ),
                selected = "gebruiker"
              ),
              
              checkboxInput(
                session$ns("new_user_active"),
                "Account actief",
                value = TRUE
              )
            )
          )
        ),
        
        footer = div(
          div(class = "text-muted small float-start", "* Verplichte velden"),
          div(
            class = "float-end",
            actionButton(
              session$ns("btn_user_cancel"),
              "Annuleren",
              class = "btn-outline-secondary"
            ),
            actionButton(
              session$ns("btn_user_save"),
              "Opslaan",
              class = "btn-primary ms-2",
              icon = icon("save")
            )
          )
        )
      ))
    })
    
    # Cancel user modal
    observeEvent(input$btn_user_cancel, {
      removeModal()
    })
    
    # Save new user
    observeEvent(input$btn_user_save, {
      req(is_admin())
      
      # Validation
      errors <- c()
      
      if (is.null(input$new_user_username) || input$new_user_username == "") {
        errors <- c(errors, "Gebruikersnaam is verplicht")
      }
      
      if (is.null(input$new_user_password) || nchar(input$new_user_password) < 6) {
        errors <- c(errors, "Wachtwoord moet minimaal 6 karakters zijn")
      }
      
      if (input$new_user_password != input$new_user_password_confirm) {
        errors <- c(errors, "Wachtwoorden komen niet overeen")
      }
      
      if (length(errors) > 0) {
        output$user_form_messages <- renderUI({
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            tags$ul(lapply(errors, tags$li))
          )
        })
        return()
      }
      
      # Save user
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        # Check if username exists
        existing <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM gebruikers 
          WHERE gebruikersnaam = ?
        ", list(input$new_user_username))
        
        if (existing$count > 0) {
          output$user_form_messages <- renderUI({
            div(class = "alert alert-warning", "Gebruikersnaam bestaat al")
          })
          return()
        }
        
        # Hash password
        password_hash <- digest::digest(input$new_user_password, algo = "sha256")
        
        # Insert user
        DBI::dbExecute(con, "
          INSERT INTO gebruikers (
            gebruikersnaam, wachtwoord_hash, rol, actief,
            aangemaakt_op
          ) VALUES (?, ?, ?, ?, ?)
        ", list(
          input$new_user_username,
          password_hash,
          input$new_user_role,
          if (input$new_user_active) 1 else 0,
          as.character(Sys.time())
        ))
        
        cli_alert_success("User created: {input$new_user_username}")
        show_notification(paste("Gebruiker toegevoegd:", input$new_user_username), type = "message")
        
        # Refresh users
        users_refresh(users_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error creating user: {e$message}")
        show_notification("Fout bij aanmaken gebruiker", type = "error")
      })
    })
    
    # ========================================================================
    # ADD DROPDOWN VALUE MODAL
    # ========================================================================
    
    # Show add dropdown value modal
    observeEvent(input$btn_add_dropdown_value, {
      cli_alert_info("Add dropdown button clicked. Is admin: {is_admin()}, Selected category: {selected_category()}")
      req(is_admin(), selected_category())
      
      category <- selected_category()
      category_display <- switch(category,
        "type_dienst" = "Type Dienst",
        "rechtsgebied" = "Rechtsgebied", 
        "status_zaak" = "Status Zaak",
        "aanvragende_directie" = "Aanvragende Directie",
        "type_wederpartij" = "Type Wederpartij",
        "reden_inzet" = "Reden Inzet",
        "hoedanigheid_partij" = "Hoedanigheid Partij",
        "Onbekend"
      )
      
      showModal(modalDialog(
        title = paste("Nieuwe", category_display, "Waarde"),
        size = "m",
        easyClose = FALSE,
        
        div(
          # Form validation messages
          div(id = session$ns("dropdown_form_messages")),
          
          # Dropdown form
          div(
            textInput(
              session$ns("new_dropdown_weergave"),
              "Waarde Naam: *",
              placeholder = "Vul een waarde in"
            ),
            
            checkboxInput(
              session$ns("new_dropdown_active"),
              "Actief",
              value = TRUE
            ),
            
            # Kleur picker met "geen kleur" optie
            div(
              colourInput(
                session$ns("new_dropdown_kleur"),
                "Kleur:",
                value = "#FFFFFF",
                palette = "limited",
                allowedCols = c("#FFFFFF", "#17a2b8", "#28a745", "#ffc107", "#fd7e14", "#dc3545", "#6c757d", "#343a40", "#007bff", "#20c997", "#e83e8c"),
                closeOnClick = TRUE
              ),
              div(class = "small text-muted mt-1", "Wit = geen kleur")
            )
            
          )
        ),
        
        footer = div(
          div(class = "text-muted small float-start", "* Verplichte velden"),
          div(
            class = "float-end",
            actionButton(
              session$ns("btn_dropdown_cancel"),
              "Annuleren",
              class = "btn-outline-secondary"
            ),
            actionButton(
              session$ns("btn_dropdown_save"),
              "Opslaan",
              class = "btn-primary ms-2",
              icon = icon("save")
            )
          )
        )
      ))
    })
    
    # Cancel dropdown modal
    observeEvent(input$btn_dropdown_cancel, {
      removeModal()
    })
    
    # Save new dropdown value
    observeEvent(input$btn_dropdown_save, {
      req(is_admin(), selected_category())
      
      category <- selected_category()
      
      # Generate waarde from weergave naam
      if (is.null(input$new_dropdown_weergave) || input$new_dropdown_weergave == "") {
        output$dropdown_form_messages <- renderUI({
          div(class = "alert alert-warning", "Waarde naam is verplicht")
        })
        return()
      }
      
      # Generate database value by replacing spaces with underscores and converting to lowercase
      generated_waarde <- tolower(gsub("[^a-zA-Z0-9\\s]", "", input$new_dropdown_weergave))  # Remove special chars
      generated_waarde <- gsub("\\s+", "_", generated_waarde)  # Replace spaces with underscores
      generated_waarde <- gsub("_+", "_", generated_waarde)    # Replace multiple underscores with single
      generated_waarde <- gsub("^_|_$", "", generated_waarde)  # Remove leading/trailing underscores
      
      # Validation
      errors <- c()
      
      if (generated_waarde == "") {
        errors <- c(errors, "Geen geldige waarde kon worden gegenereerd uit de naam")
      }
      
      if (length(errors) > 0) {
        output$dropdown_form_messages <- renderUI({
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            tags$ul(lapply(errors, tags$li))
          )
        })
        return()
      }
      
      # Save dropdown value
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        # Check if value exists (by waarde)
        existing_waarde <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND waarde = ?
        ", list(category, generated_waarde))
        
        # Check if display name exists (by weergave_naam)  
        existing_weergave <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND weergave_naam = ?
        ", list(category, input$new_dropdown_weergave))
        
        if (existing_waarde$count > 0) {
          output$dropdown_form_messages <- renderUI({
            div(class = "alert alert-warning", "Deze waarde bestaat al voor deze categorie")
          })
          return()
        }
        
        if (existing_weergave$count > 0) {
          output$dropdown_form_messages <- renderUI({
            div(class = "alert alert-warning", "Deze weergave naam bestaat al voor deze categorie")
          })
          return()
        }
        
        # Prepare kleur value (NULL becomes NA for database)
        kleur_value <- if (is.null(input$new_dropdown_kleur) || input$new_dropdown_kleur == "#FFFFFF") {
          NA_character_
        } else {
          input$new_dropdown_kleur
        }
        
        # Insert dropdown value
        DBI::dbExecute(con, "
          INSERT INTO dropdown_opties (
            categorie, waarde, weergave_naam, actief, kleur,
            aangemaakt_door, aangemaakt_op
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ", list(
          category,
          generated_waarde,
          input$new_dropdown_weergave,
          if (input$new_dropdown_active) 1 else 0,
          kleur_value,
          current_user(),
          as.character(Sys.time())
        ))
        
        cli_alert_success("Dropdown value created: {category}/{generated_waarde}")
        show_notification(paste("Waarde toegevoegd:", input$new_dropdown_weergave), type = "message")
        
        # Refresh dropdowns locally and globally
        dropdown_refresh(dropdown_refresh() + 1)
        if (!is.null(global_dropdown_refresh_trigger)) {
          global_dropdown_refresh_trigger(global_dropdown_refresh_trigger() + 1)
        }
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error creating dropdown value: {e$message}")
        show_notification("Fout bij aanmaken waarde", type = "error")
      })
    })
    
    # ========================================================================
    # DELETE HANDLERS
    # ========================================================================
    
    # Delete user handler (soft delete via actief = 0)
    observeEvent(input$delete_user, {
      cli_alert_info("Delete user event triggered: {input$delete_user}")
      req(is_admin(), input$delete_user)
      
      username <- input$delete_user
      cli_alert_info("Delete user processing: {username}")
      
      # Prevent deleting protected users
      if (username %in% c("admin", "system")) {
        show_notification("Deze gebruiker kan niet worden verwijderd", type = "error")
        return()
      }
      
      showModal(modalDialog(
        title = "Gebruiker Verwijderen",
        size = "m",
        easyClose = TRUE,
        
        div(
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            HTML(paste("Weet je zeker dat je gebruiker <strong>", username, "</strong> wilt verwijderen?"))
          ),
          p("De gebruiker wordt gedeactiveerd en kan niet meer inloggen.")
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_delete_user_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_delete_user_confirm"),
            "Verwijderen",
            class = "btn-danger ms-2",
            icon = icon("trash")
          )
        )
      ))
    })
    
    # Cancel delete user
    observeEvent(input$btn_delete_user_cancel, {
      removeModal()
    })
    
    # Force modal close on escape key or outside click
    observeEvent(input$shiny_modal, {
      if (is.null(input$shiny_modal)) {
        removeModal()
      }
    })
    
    # Confirm delete user
    observeEvent(input$btn_delete_user_confirm, {
      username <- input$delete_user
      req(is_admin(), username, !username %in% c("admin", "system"))
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        # Check if user has created or modified cases
        case_count <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM zaken 
          WHERE aangemaakt_door = ? OR gewijzigd_door = ?
        ", list(username, username))$count
        
        if (case_count > 0) {
          # Update case references to system user before deleting
          DBI::dbExecute(con, "
            UPDATE zaken 
            SET aangemaakt_door = 'system'
            WHERE aangemaakt_door = ?
          ", list(username))
          
          DBI::dbExecute(con, "
            UPDATE zaken 
            SET gewijzigd_door = 'system'
            WHERE gewijzigd_door = ?
          ", list(username))
          
          cli_alert_info("Updated {case_count} case reference(s) to system user")
        }
        
        # Hard delete: permanently remove user from database
        DBI::dbExecute(con, "
          DELETE FROM gebruikers 
          WHERE gebruikersnaam = ?
        ", list(username))
        
        cli_alert_success("User permanently deleted: {username}")
        if (case_count > 0) {
          show_notification(paste("Gebruiker", username, "verwijderd.", case_count, "zaak referenties overgedragen aan systeem."), type = "message")
        } else {
          show_notification(paste("Gebruiker", username, "permanent verwijderd."), type = "message")
        }
        
        # Refresh users
        users_refresh(users_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error deleting user: {e$message}")
        show_notification("Fout bij verwijderen gebruiker", type = "error")
      })
    })
    
    # ========================================================================
    # EDIT HANDLERS
    # ========================================================================
    
    
    
    # ========================================================================
    # EDIT MODAL FUNCTIONS
    # ========================================================================
    
    # Show edit user modal
    show_edit_user_modal <- function(user_data) {
      # Store username in reactive for later use
      editing_username(user_data$gebruikersnaam)
      
      showModal(modalDialog(
        title = paste("Gebruiker Bewerken:", user_data$gebruikersnaam),
        size = "m",
        easyClose = FALSE,
        
        div(
          # Form validation messages
          div(id = session$ns("edit_user_form_messages")),
          
          # User form (read-only username)
          div(
            div(
              class = "form-group",
              tags$label(class = "control-label", "Gebruikersnaam:"),
              tags$input(
                type = "text",
                class = "form-control",
                value = user_data$gebruikersnaam,
                readonly = "readonly",
                style = "background-color: #f8f9fa;"
              )
            ),
            
            passwordInput(
              session$ns("edit_user_password"),
              "Nieuw Wachtwoord:",
              placeholder = "Laat leeg om ongewijzigd te laten"
            ),
            
            passwordInput(
              session$ns("edit_user_password_confirm"),
              "Bevestig Nieuw Wachtwoord:",
              placeholder = "Herhaal het nieuwe wachtwoord"
            ),
            
            selectInput(
              session$ns("edit_user_role"),
              "Rol: *",
              choices = list(
                "Gebruiker" = "gebruiker",
                "Administrator" = "admin"
              ),
              selected = user_data$rol
            ),
            
            checkboxInput(
              session$ns("edit_user_active"),
              "Account actief",
              value = (user_data$actief == 1)
            )
          )
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_edit_user_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_edit_user_save"),
            "Bijwerken",
            class = "btn-primary ms-2",
            icon = icon("save")
          )
        )
      ))
    }
    
    # Show edit dropdown modal
    show_edit_dropdown_modal <- function(value_data, category) {
      cli_alert_info("Opening edit modal for {category} - value: {value_data$waarde}, weergave: {value_data$weergave_naam}")
      
      # Store original value in reactive
      editing_original_waarde(value_data$waarde)
      cli_alert_info("Stored original waarde in reactive: '{value_data$waarde}'")
      
      category_display <- switch(category,
        "type_dienst" = "Type Dienst",
        "rechtsgebied" = "Rechtsgebied", 
        "status_zaak" = "Status Zaak",
        "aanvragende_directie" = "Aanvragende Directie",
        "type_wederpartij" = "Type Wederpartij",
        "reden_inzet" = "Reden Inzet",
        "hoedanigheid_partij" = "Hoedanigheid Partij",
        "Onbekend"
      )
      
      showModal(modalDialog(
        title = paste(category_display, "Waarde Bewerken:", value_data$waarde),
        size = "m",
        easyClose = FALSE,
        
        div(
          # Form validation messages
          div(id = session$ns("edit_dropdown_form_messages")),
          
          # Dropdown form
          div(
            textInput(
              session$ns("edit_dropdown_weergave"),
              "Waarde Naam: *",
              value = ifelse(is.na(value_data$weergave_naam), "", value_data$weergave_naam)
            ),
            
            # Check if this is a protected "Niet ingesteld" value
            if (value_data$waarde == "niet_ingesteld" || 
                (!is.na(value_data$weergave_naam) && value_data$weergave_naam == "Niet ingesteld") ||
                value_data$waarde == "Niet ingesteld") {
              # Show disabled checkbox for protected values
              div(
                checkboxInput(
                  session$ns("edit_dropdown_active"),
                  "Actief (automatisch)",
                  value = TRUE
                ),
                tags$script(paste0("$('#", session$ns("edit_dropdown_active"), "').prop('disabled', true);")),
                div(class = "small text-muted", "Systeem waarden kunnen niet worden gedeactiveerd")
              )
            } else {
              # Normal checkbox for non-protected values
              checkboxInput(
                session$ns("edit_dropdown_active"),
                "Actief",
                value = (value_data$actief == 1)
              )
            },
            
            # Kleur picker met "geen kleur" optie
            conditionalPanel(
              condition = "true",  # Altijd tonen voor nu
              colourInput(
                session$ns("edit_dropdown_kleur"),
                "Kleur:",
                value = ifelse(is.na(value_data$kleur) || value_data$kleur == "", "#FFFFFF", value_data$kleur),
                palette = "limited",
                allowedCols = c("#FFFFFF", "#17a2b8", "#28a745", "#ffc107", "#fd7e14", "#dc3545", "#6c757d", "#343a40", "#007bff", "#20c997", "#e83e8c"),
                closeOnClick = TRUE
              ),
              div(class = "small text-muted mt-1", "Wit = geen kleur")
            )
            
          )
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_edit_dropdown_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_edit_dropdown_save"),
            "Bijwerken",
            class = "btn-primary ms-2",
            icon = icon("save")
          )
        )
      ))
    }
    
    # Edit user cancel
    observeEvent(input$btn_edit_user_cancel, {
      removeModal()
      # Reset click tracking so user can click same row again
      last_clicked_user_info(NULL)
    })
    
    # Edit user save
    observeEvent(input$btn_edit_user_save, {
      req(is_admin())
      
      # Validation
      errors <- c()
      
      if (!is.null(input$edit_user_password) && input$edit_user_password != "") {
        if (nchar(input$edit_user_password) < 6) {
          errors <- c(errors, "Wachtwoord moet minimaal 6 karakters zijn")
        }
        
        if (input$edit_user_password != input$edit_user_password_confirm) {
          errors <- c(errors, "Wachtwoorden komen niet overeen")
        }
      }
      
      if (length(errors) > 0) {
        output$edit_user_form_messages <- renderUI({
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            tags$ul(lapply(errors, tags$li))
          )
        })
        return()
      }
      
      # Update user
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        username <- editing_username()
        
        # Build update query
        if (!is.null(input$edit_user_password) && input$edit_user_password != "") {
          # Update with password
          password_hash <- digest::digest(input$edit_user_password, algo = "sha256")
          
          DBI::dbExecute(con, "
            UPDATE gebruikers SET 
              wachtwoord_hash = ?, rol = ?, actief = ?
            WHERE gebruikersnaam = ?
          ", list(
            password_hash, 
            input$edit_user_role, 
            if (input$edit_user_active) 1 else 0, 
            username
          ))
        } else {
          # Update without password
          DBI::dbExecute(con, "
            UPDATE gebruikers SET 
              rol = ?, actief = ?
            WHERE gebruikersnaam = ?
          ", list(
            input$edit_user_role, 
            if (input$edit_user_active) 1 else 0, 
            username
          ))
        }
        
        cli_alert_success("User updated: {username}")
        show_notification(paste("Gebruiker bijgewerkt:", username), type = "message")
        
        # Refresh users
        users_refresh(users_refresh() + 1)
        
        # Close modal
        removeModal()
        
        # Reset click tracking so user can click same row again
        last_clicked_user_info(NULL)
        
      }, error = function(e) {
        cli_alert_danger("Error updating user: {e$message}")
        show_notification("Fout bij bijwerken gebruiker", type = "error")
      })
    })
    
    # Edit dropdown cancel
    observeEvent(input$btn_edit_dropdown_cancel, {
      removeModal()
      # Reset click tracking
      last_clicked_dropdown_info(NULL)
    })
    
    
    # Edit dropdown save
    observeEvent(input$btn_edit_dropdown_save, {
      cli_alert_info("Edit dropdown save button clicked!")
      
      if (!is_admin()) {
        cli_alert_warning("User is not admin, blocking edit")
        return()
      }
      
      if (is.null(selected_category())) {
        cli_alert_warning("No category selected, blocking edit")
        return()
      }
      
      category <- selected_category()
      original_waarde <- editing_original_waarde()
      
      cli_alert_info("Edit dropdown save triggered for category: {category}")
      cli_alert_info("Original waarde from reactive: '{original_waarde}' (length: {length(original_waarde)}, class: {class(original_waarde)})")
      cli_alert_info("New weergave naam: '{input$edit_dropdown_weergave}'")
      
      # Safety check for original waarde
      if (is.null(original_waarde) || length(original_waarde) == 0 || original_waarde == "") {
        output$edit_dropdown_form_messages <- renderUI({
          div(class = "alert alert-danger", "Fout: Originele waarde niet gevonden. Probeer het opnieuw.")
        })
        return()
      }
      
      # Validate weergave naam
      if (is.null(input$edit_dropdown_weergave) || input$edit_dropdown_weergave == "") {
        output$edit_dropdown_form_messages <- renderUI({
          div(class = "alert alert-warning", "Weergave naam is verplicht")
        })
        return()
      }
      
      # Update dropdown value
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        # Debug parameters before executing query (update weergave_naam, actief, and kleur)
        # Note: NULL needs to be converted to NA for database operations to maintain length 1
        kleur_value <- if (is.null(input$edit_dropdown_kleur) || input$edit_dropdown_kleur == "#FFFFFF") {
          NA_character_
        } else {
          as.character(input$edit_dropdown_kleur)
        }
        
        # Check if this is a protected "Niet ingesteld" value - always keep active
        is_protected <- original_waarde == "niet_ingesteld" || 
                       original_waarde == "Niet ingesteld" ||
                       input$edit_dropdown_weergave == "Niet ingesteld"
        
        actief_value <- if (is_protected) {
          1  # Always active for protected values
        } else {
          as.integer(if (input$edit_dropdown_active) 1 else 0)
        }
        
        params <- list(
          weergave_naam = as.character(input$edit_dropdown_weergave),
          actief = actief_value,
          kleur = kleur_value,
          category = as.character(category),
          original_waarde = as.character(original_waarde)
        )
        
        cli_alert_info("Update parameters: weergave_naam='{params$weergave_naam}', actief={params$actief}, kleur='{ifelse(is.na(params$kleur), 'NULL', params$kleur)}', category='{params$category}', original_waarde='{params$original_waarde}'")
        
        # Check parameter lengths
        param_lengths <- sapply(params, length)
        if (any(param_lengths != 1)) {
          cli_alert_danger("Parameter length issue: {paste(names(param_lengths)[param_lengths != 1], '=', param_lengths[param_lengths != 1], collapse=', ')}")
          stop("All parameters must have length 1")
        }
        
        # Check if new weergave_naam already exists for another record in this category
        existing_weergave <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND weergave_naam = ? AND waarde != ?
        ", list(category, input$edit_dropdown_weergave, original_waarde))
        
        if (existing_weergave$count > 0) {
          output$edit_dropdown_form_messages <- renderUI({
            div(class = "alert alert-warning", "Deze weergave naam bestaat al voor deze categorie")
          })
          return()
        }
        
        # Update weergave_naam, actief, and kleur, keep database waarde unchanged
        DBI::dbExecute(con, "
          UPDATE dropdown_opties SET 
            weergave_naam = ?, actief = ?, kleur = ?
          WHERE categorie = ? AND waarde = ?
        ", unname(params))
        
        cli_alert_success("Dropdown display name updated: {category}/{original_waarde} -> '{input$edit_dropdown_weergave}'")
        show_notification(paste("Weergave naam bijgewerkt:", input$edit_dropdown_weergave), type = "message")
        
        # Refresh dropdowns locally and globally
        dropdown_refresh(dropdown_refresh() + 1)
        if (!is.null(global_dropdown_refresh_trigger)) {
          global_dropdown_refresh_trigger(global_dropdown_refresh_trigger() + 1)
        }
        
        # Close modal
        removeModal()
        
        # Reset click tracking so user can click same row again
        last_clicked_dropdown_info(NULL)
        
      }, error = function(e) {
        cli_alert_danger("Error updating dropdown value: {e$message}")
        show_notification("Fout bij bijwerken waarde", type = "error")
      })
    })
    
    # ========================================================================
    # DEADLINE KLEUREN BEHEER
    # ========================================================================
    
    # Deadline kleuren refresh trigger
    deadline_kleuren_refresh <- reactiveVal(0)
    
    # Load deadline kleuren data
    deadline_kleuren_data <- reactive({
      deadline_kleuren_refresh()  # React to refresh trigger
      
      tryCatch({
        get_deadline_kleuren()
      }, error = function(e) {
        cli_alert_danger("Error loading deadline kleuren: {e$message}")
        data.frame()
      })
    })
    
    # Deadline kleuren table output  
    output$deadline_kleuren_table <- DT::renderDataTable({
      
      data <- deadline_kleuren_data()
      
      if (nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen deadline kleuren gevonden"),
          options = list(searching = FALSE, paging = FALSE, info = FALSE),
          rownames = FALSE
        ))
      }
      
      # Format data for display - same style as dropdown values table
      display_data <- data %>%
        mutate(
          Beschrijving = beschrijving,
          Actief = ifelse(actief == 1, "Ja", "Nee"),
          `Van (dagen)` = ifelse(is.na(dagen_voor), "∞", as.character(dagen_voor)),
          `Tot (dagen)` = ifelse(is.na(dagen_tot), "∞", as.character(dagen_tot)),
          Door = ifelse(is.na(aangemaakt_door), "Systeem", aangemaakt_door),
          Aangemaakt = ifelse(is.na(aangemaakt_op), "-", format_date_nl(as.Date(aangemaakt_op))),
          Acties = paste0(
            '<button class="btn btn-sm btn-outline-danger deadline-delete-btn" data-id="', id, '">',
            '<i class="fa fa-trash"></i></button>'
          )
        ) %>%
        select(Beschrijving, Actief, `Van (dagen)`, `Tot (dagen)`, Door, Aangemaakt, Acties)
      
      # Apply colors to the Beschrijving column background - same style as dropdown beheer
      dt <- DT::datatable(
        display_data,
        selection = 'none',
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50),
          searching = TRUE,
          ordering = TRUE,
          columnDefs = list(
            list(className = "dt-center", targets = c(1, 2, 3, 4, 5, 6)),
            list(width = "120px", targets = 6),  # Acties column
            list(orderable = FALSE, targets = 6)  # No sorting on Acties
          ),
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items",
            info = "Toont _START_ tot _END_ van _TOTAL_ items"
          )
        ),
        rownames = FALSE,
        escape = FALSE,
        class = "table table-striped table-hover compact"
      )
      
      # Apply color styling to Beschrijving column using the kleur field
      if (nrow(data) > 0) {
        # Get colors for styling  
        kleuren <- setNames(data$kleur, data$beschrijving)
        
        # Filter out empty/white colors
        kleuren <- kleuren[!is.na(kleuren) & kleuren != "" & kleuren != "#ffffff"]
        
        if (length(kleuren) > 0) {
          dt <- dt %>%
            DT::formatStyle(
              "Beschrijving",
              backgroundColor = DT::styleEqual(names(kleuren), kleuren),
              color = "black",
              fontWeight = "bold"
            )
        }
      }
      
      # Add JavaScript for button handling and row clicks
      dt$dependencies <- append(dt$dependencies, list(
        htmltools::htmlDependency(
          name = "deadline-kleuren-interactions",
          version = "1.0", 
          src = c(href = ""),
          script = NULL,
          head = HTML("
            <script>
            $(document).ready(function() {
              $(document).on('click', '.deadline-delete-btn', function(e) {
                e.stopPropagation();
                var id = $(this).data('id');
                Shiny.setInputValue('instellingen-delete_deadline_kleur_id', id, {priority: 'event'});
              });
            });
            </script>
          ")
        )
      ))
      
      dt
      
    }, server = TRUE)
    
    # Handle deadline kleuren table row clicks for edit
    last_clicked_deadline_info <- reactiveVal(NULL)
    
    observeEvent(input$deadline_kleuren_table_cell_clicked, {
      
      info <- input$deadline_kleuren_table_cell_clicked
      
      if (!is.null(info$row) && info$row > 0) {
        
        # Don't open edit modal if clicked on Actions column (last column)
        data <- deadline_kleuren_data()
        if (is.null(data) || nrow(data) == 0) return()
        
        # Actions column is the last column (index 6)
        if (!is.null(info$col) && info$col >= 6) {
          return()  # Ignore clicks on Actions column
        }
        
        # Simple duplicate prevention
        current_info <- paste0(info$row, "_", info$col)
        if (!is.null(last_clicked_deadline_info()) && current_info == last_clicked_deadline_info()) {
          return()  # Ignore duplicate clicks
        }
        last_clicked_deadline_info(current_info)
        
        if (info$row <= nrow(data)) {
          
          # Get the clicked deadline kleur
          selected_deadline <- data[info$row, ]
          
          cli_alert_info("Deadline kleuren table row clicked for: {selected_deadline$id}")
          show_edit_deadline_kleur_modal(selected_deadline)
        }
      }
    })
    
    # Show edit deadline kleur modal
    show_edit_deadline_kleur_modal <- function(deadline_data) {
      showModal(modalDialog(
        title = paste("Deadline Kleur Bewerken:", deadline_data$beschrijving),
        size = "m",
        easyClose = FALSE,
        
        div(
          textInput(
            session$ns("edit_deadline_beschrijving"),
            "Beschrijving:",
            value = deadline_data$beschrijving
          ),
          
          textInput(
            session$ns("edit_deadline_dagen_voor"),
            "Van (dagen) - laat leeg voor alles ervoor:",
            value = ifelse(is.na(deadline_data$dagen_voor), "", as.character(deadline_data$dagen_voor)),
            placeholder = "bijv. -7 (week voor deadline)"
          ),
          
          textInput(
            session$ns("edit_deadline_dagen_tot"),
            "Tot (dagen) - laat leeg voor alles erna:",
            value = ifelse(is.na(deadline_data$dagen_tot), "", as.character(deadline_data$dagen_tot)),
            placeholder = "bijv. 7 (week na deadline)"
          ),
          
          colourpicker::colourInput(
            session$ns("edit_deadline_kleur"),
            "Kleur:",
            value = deadline_data$kleur,
            showColour = "both"
          ),
          
          
          checkboxInput(
            session$ns("edit_deadline_actief"),
            "Actief",
            value = deadline_data$actief == 1
          ),
          
          div(
            class = "alert alert-info mt-3",
            icon("info-circle"), " ",
            strong("Tip: "), "Ranges mogen niet overlappen.",
            br(),
            "• Negatieve getallen = dagen VÓÓR de deadline (deadline komt nog)",
            br(), 
            "• Positieve getallen = dagen NÁ de deadline (deadline is verstreken)",
            br(),
            "• 0 = vandaag is de deadline",
            br(),
            "• Laat velden leeg voor onbeperkte ranges (∞)"
          ),
          
          # Hidden field to store the ID
          div(style = "display: none;",
              textInput(session$ns("edit_deadline_id"), "", value = deadline_data$id)
          )
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_edit_deadline_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_edit_deadline_save"),
            "Bijwerken",
            class = "btn-primary ms-2"
          )
        )
      ))
    }
    
    # Add new deadline kleur
    observeEvent(input$btn_add_deadline_kleur, {
      req(is_admin())
      
      showModal(modalDialog(
        title = "Nieuwe Deadline Kleurrange",
        size = "m",
        easyClose = FALSE,
        
        div(
          textInput(
            session$ns("new_deadline_beschrijving"),
            "Beschrijving:",
            placeholder = "bijv. 'Kritiek - binnen een week'"
          ),
          
          textInput(
            session$ns("new_deadline_dagen_voor"),
            "Van (dagen) - laat leeg voor alles ervoor:",
            value = "-7",
            placeholder = "bijv. -7 (week voor deadline)"
          ),
          
          textInput(
            session$ns("new_deadline_dagen_tot"),
            "Tot (dagen) - laat leeg voor alles erna:",
            value = "-1",
            placeholder = "bijv. 7 (week na deadline)"
          ),
          
          colourpicker::colourInput(
            session$ns("new_deadline_kleur"),
            "Kleur:",
            value = "#ffc107",
            showColour = "both"
          ),
          
          
          div(
            class = "alert alert-info mt-3",
            icon("info-circle"), " ",
            strong("Tip: "), "Ranges mogen niet overlappen.",
            br(),
            "• Negatieve getallen = dagen VÓÓR de deadline (deadline komt nog)",
            br(), 
            "• Positieve getallen = dagen NÁ de deadline (deadline is verstreken)",
            br(),
            "• 0 = vandaag is de deadline",
            br(),
            "• Laat velden leeg voor onbeperkte ranges (∞)"
          )
        ),
        
        footer = div(
          actionButton(
            session$ns("btn_deadline_kleur_cancel"),
            "Annuleren",
            class = "btn-outline-secondary"
          ),
          actionButton(
            session$ns("btn_deadline_kleur_save"),
            "Opslaan",
            class = "btn-primary ms-2"
          )
        )
      ))
    })
    
    # Save new deadline kleur
    observeEvent(input$btn_deadline_kleur_save, {
      req(is_admin())
      
      tryCatch({
        # Convert text input to appropriate format
        dagen_voor <- input$new_deadline_dagen_voor
        dagen_tot <- input$new_deadline_dagen_tot
        
        # Convert to numeric if not empty (empty = infinite)
        if (trimws(dagen_voor) != "") {
          dagen_voor <- as.numeric(dagen_voor)
          if (is.na(dagen_voor)) {
            show_notification("'Van (dagen)' moet een getal zijn of leeg voor oneindig", type = "warning")
            return()
          }
        }
        
        if (trimws(dagen_tot) != "") {
          dagen_tot <- as.numeric(dagen_tot)
          if (is.na(dagen_tot)) {
            show_notification("'Tot (dagen)' moet een getal zijn of leeg voor oneindig", type = "warning")
            return()
          }
        }
        
        voeg_deadline_kleur_toe(
          dagen_voor = dagen_voor,
          dagen_tot = dagen_tot,
          beschrijving = input$new_deadline_beschrijving,
          kleur = input$new_deadline_kleur,
          gebruiker = current_user()
        )
        
        cli_alert_success("Deadline kleur added successfully")
        show_notification("Deadline kleur toegevoegd", type = "message")
        
        # Refresh table
        deadline_kleuren_refresh(deadline_kleuren_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error adding deadline kleur: {e$message}")
        show_notification(paste("Fout bij toevoegen deadline kleur:", e$message), type = "error")
      })
    })
    
    # Save edited deadline kleur
    observeEvent(input$btn_edit_deadline_save, {
      req(is_admin())
      req(input$edit_deadline_id)
      
      tryCatch({
        # Convert text input to appropriate format
        dagen_voor <- input$edit_deadline_dagen_voor
        dagen_tot <- input$edit_deadline_dagen_tot
        
        # Convert to numeric if not empty (empty = infinite)
        if (trimws(dagen_voor) != "") {
          dagen_voor <- as.numeric(dagen_voor)
          if (is.na(dagen_voor)) {
            show_notification("'Van (dagen)' moet een getal zijn of leeg voor oneindig", type = "warning")
            return()
          }
        }
        
        if (trimws(dagen_tot) != "") {
          dagen_tot <- as.numeric(dagen_tot)
          if (is.na(dagen_tot)) {
            show_notification("'Tot (dagen)' moet een getal zijn of leeg voor oneindig", type = "warning")
            return()
          }
        }
        
        update_deadline_kleur(
          id = as.numeric(input$edit_deadline_id),
          dagen_voor = dagen_voor,
          dagen_tot = dagen_tot,
          beschrijving = input$edit_deadline_beschrijving,
          kleur = input$edit_deadline_kleur,
          gebruiker = current_user()
        )
        
        cli_alert_success("Deadline kleur updated successfully")
        show_notification("Deadline kleur bijgewerkt", type = "message")
        
        # Refresh table
        deadline_kleuren_refresh(deadline_kleuren_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error updating deadline kleur: {e$message}")
        show_notification(paste("Fout bij bijwerken deadline kleur:", e$message), type = "error")
      })
    })
    
    # Cancel edit deadline kleur
    observeEvent(input$btn_edit_deadline_cancel, {
      removeModal()
    })
    
    # Cancel deadline kleur modal
    observeEvent(input$btn_deadline_kleur_cancel, {
      removeModal()
    })
    
    # Delete deadline kleur
    observeEvent(input$delete_deadline_kleur_id, {
      req(is_admin())
      req(input$delete_deadline_kleur_id)
      
      showModal(modalDialog(
        title = "Deadline Kleur Verwijderen",
        "Weet je zeker dat je deze deadline kleur wilt verwijderen?",
        footer = div(
          actionButton(
            session$ns("btn_confirm_delete_deadline_kleur"),
            "Verwijderen",
            class = "btn-danger"
          ),
          actionButton(
            session$ns("btn_cancel_delete_deadline_kleur"),
            "Annuleren",
            class = "btn-outline-secondary ms-2"
          )
        )
      ))
    })
    
    # Confirm delete deadline kleur
    observeEvent(input$btn_confirm_delete_deadline_kleur, {
      req(input$delete_deadline_kleur_id)
      
      tryCatch({
        verwijder_deadline_kleur(input$delete_deadline_kleur_id)
        
        cli_alert_success("Deadline kleur deleted successfully")
        show_notification("Deadline kleur verwijderd", type = "message")
        
        # Refresh table
        deadline_kleuren_refresh(deadline_kleuren_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error deleting deadline kleur: {e$message}")
        show_notification("Fout bij verwijderen deadline kleur", type = "error")
      })
    })
    
    # Cancel delete deadline kleur
    observeEvent(input$btn_cancel_delete_deadline_kleur, {
      removeModal()
    })
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    return(list(
      refresh_users = function() {
        users_refresh(users_refresh() + 1)
      },
      refresh_dropdowns = function() {
        dropdown_refresh(dropdown_refresh() + 1)
      }
    ))
  })
}