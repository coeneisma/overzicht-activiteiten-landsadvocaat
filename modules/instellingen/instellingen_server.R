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
          `Acties` = ifelse(gebruikersnaam == "admin", 
                           "", # No delete button for admin
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
    
    # Category count outputs
    output$count_type_dienst <- renderText({
      counts <- dropdown_counts()
      count <- counts[["type_dienst"]]
      as.character(if(is.null(count)) 0 else count)
    })
    
    output$count_rechtsgebied <- renderText({
      counts <- dropdown_counts()
      count <- counts[["rechtsgebied"]]
      as.character(if(is.null(count)) 0 else count)
    })
    
    output$count_status_zaak <- renderText({
      counts <- dropdown_counts()
      count <- counts[["status_zaak"]]
      as.character(if(is.null(count)) 0 else count)
    })
    
    output$count_aanvragende_directie <- renderText({
      counts <- dropdown_counts()
      count <- counts[["aanvragende_directie"]]
      as.character(if(is.null(count)) 0 else count)
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
          SELECT waarde, weergave_naam, actief,
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
      
      # Format data for display
      display_data <- data %>%
        mutate(
          `Weergave Naam` = ifelse(is.na(weergave_naam) | weergave_naam == "", 
                                 waarde, weergave_naam),
          `Actief` = ifelse(actief == 1, "Ja", "Nee"),
          `Aangemaakt` = format_date_nl(as.Date(aangemaakt_op))
        ) %>%
        select(
          "Waarde" = `Weergave Naam`,
          "Actief" = Actief,
          "Door" = aangemaakt_door,
          "Aangemaakt" = Aangemaakt
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
        escape = FALSE
      )
      
    }, server = TRUE)
    
    # Handle dropdown table row clicks for edit
    observeEvent(input$dropdown_values_table_cell_clicked, {
      
      info <- input$dropdown_values_table_cell_clicked
      
      if (!is.null(info$row) && info$row > 0 && !is.null(selected_category())) {
        
        # Simple duplicate prevention
        current_info <- paste0(info$row, "_", info$col)
        if (!is.null(last_clicked_dropdown_info()) && current_info == last_clicked_dropdown_info()) {
          return()  # Ignore duplicate clicks
        }
        last_clicked_dropdown_info(current_info)
        
        data <- dropdown_values_data()
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
              placeholder = "bijv. Nieuwe Waarde Met Spaties"
            ),
            
            checkboxInput(
              session$ns("new_dropdown_active"),
              "Actief",
              value = TRUE
            ),
            
            # Help text
            div(
              class = "text-muted small mt-2",
              icon("info-circle"), " ",
              "De waarde wordt automatisch opgeslagen met underscores voor spaties."
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
        
        # Check if value exists
        existing <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND waarde = ?
        ", list(category, generated_waarde))
        
        if (existing$count > 0) {
          output$dropdown_form_messages <- renderUI({
            div(class = "alert alert-warning", "Deze waarde bestaat al voor deze categorie")
          })
          return()
        }
        
        # Insert dropdown value
        DBI::dbExecute(con, "
          INSERT INTO dropdown_opties (
            categorie, waarde, weergave_naam, actief,
            aangemaakt_door, aangemaakt_op
          ) VALUES (?, ?, ?, ?, ?, ?)
        ", list(
          category,
          generated_waarde,
          input$new_dropdown_weergave,
          if (input$new_dropdown_active) 1 else 0,
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
      
      # Prevent deleting admin user
      if (username == "admin") {
        show_notification("Admin gebruiker kan niet worden verwijderd", type = "error")
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
            paste("Weet je zeker dat je gebruiker", strong(username), "wilt verwijderen?")
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
      req(is_admin(), username, username != "admin")
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        # Hard delete: permanently remove user from database
        DBI::dbExecute(con, "
          DELETE FROM gebruikers 
          WHERE gebruikersnaam = ?
        ", list(username))
        
        cli_alert_success("User permanently deleted: {username}")
        show_notification(paste("Gebruiker permanent verwijderd:", username), type = "message")
        
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
      category_display <- switch(category,
        "type_dienst" = "Type Dienst",
        "rechtsgebied" = "Rechtsgebied", 
        "status_zaak" = "Status Zaak",
        "aanvragende_directie" = "Aanvragende Directie",
        "Onbekend"
      )
      
      showModal(modalDialog(
        title = paste(category_display, "Waarde Bewerken:", value_data$waarde),
        size = "m",
        easyClose = FALSE,
        
        div(
          # Form validation messages
          div(id = session$ns("edit_dropdown_form_messages")),
          
          # Store original value for update WHERE clause
          tags$input(
            type = "hidden",
            id = session$ns("edit_original_waarde"),
            value = value_data$waarde
          ),
          
          # Dropdown form
          div(
            textInput(
              session$ns("edit_dropdown_weergave"),
              "Waarde Naam: *",
              value = ifelse(is.na(value_data$weergave_naam), "", value_data$weergave_naam)
            ),
            
            checkboxInput(
              session$ns("edit_dropdown_active"),
              "Actief",
              value = (value_data$actief == 1)
            ),
            
            # Help text
            div(
              class = "text-muted small mt-2",
              icon("info-circle"), " ",
              "Huidige database waarde: ", tags$code(value_data$waarde)
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
        
        username <- input$edit_user_username
        
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
        
      }, error = function(e) {
        cli_alert_danger("Error updating user: {e$message}")
        show_notification("Fout bij bijwerken gebruiker", type = "error")
      })
    })
    
    # Edit dropdown cancel
    observeEvent(input$btn_edit_dropdown_cancel, {
      removeModal()
    })
    
    # Edit dropdown save
    observeEvent(input$btn_edit_dropdown_save, {
      req(is_admin(), selected_category())
      
      category <- selected_category()
      original_waarde <- input$edit_original_waarde
      
      # Generate new waarde from weergave naam
      if (is.null(input$edit_dropdown_weergave) || input$edit_dropdown_weergave == "") {
        output$edit_dropdown_form_messages <- renderUI({
          div(class = "alert alert-warning", "Waarde naam is verplicht")
        })
        return()
      }
      
      # Generate database value by replacing spaces with underscores and converting to lowercase
      generated_waarde <- tolower(gsub("[^a-zA-Z0-9\\s]", "", input$edit_dropdown_weergave))  # Remove special chars
      generated_waarde <- gsub("\\s+", "_", generated_waarde)  # Replace spaces with underscores
      generated_waarde <- gsub("_+", "_", generated_waarde)    # Replace multiple underscores with single
      generated_waarde <- gsub("^_|_$", "", generated_waarde)  # Remove leading/trailing underscores
      
      # Validation
      errors <- c()
      
      if (generated_waarde == "") {
        errors <- c(errors, "Geen geldige waarde kon worden gegenereerd uit de naam")
      }
      
      # Check if new value already exists (only if changed)
      if (!is.null(generated_waarde) && !is.null(original_waarde) && 
          length(generated_waarde) > 0 && length(original_waarde) > 0 &&
          generated_waarde != original_waarde) {
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        existing <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND waarde = ?
        ", list(category, generated_waarde))
        
        if (existing$count > 0) {
          errors <- c(errors, "Deze waarde bestaat al voor deze categorie")
        }
      }
      
      if (length(errors) > 0) {
        output$edit_dropdown_form_messages <- renderUI({
          div(
            class = "alert alert-warning",
            icon("exclamation-triangle"), " ",
            tags$ul(lapply(errors, tags$li))
          )
        })
        return()
      }
      
      # Update dropdown value
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        DBI::dbExecute(con, "
          UPDATE dropdown_opties SET 
            waarde = ?, weergave_naam = ?, actief = ?
          WHERE categorie = ? AND waarde = ?
        ", list(
          generated_waarde,
          input$edit_dropdown_weergave,
          if (input$edit_dropdown_active) 1 else 0,
          category,
          original_waarde
        ))
        
        cli_alert_success("Dropdown value updated: {category}/{original_waarde} -> {generated_waarde}")
        show_notification(paste("Waarde bijgewerkt:", input$edit_dropdown_weergave), type = "message")
        
        # Refresh dropdowns locally and globally
        dropdown_refresh(dropdown_refresh() + 1)
        if (!is.null(global_dropdown_refresh_trigger)) {
          global_dropdown_refresh_trigger(global_dropdown_refresh_trigger() + 1)
        }
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error updating dropdown value: {e$message}")
        show_notification("Fout bij bijwerken waarde", type = "error")
      })
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