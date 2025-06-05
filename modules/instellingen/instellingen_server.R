# modules/instellingen/instellingen_server.R
# =============================================

#' Instellingen Module Server
#' 
#' Admin functionality for user and dropdown management
#' 
#' @param id Module namespace ID
#' @param current_user Reactive containing current username
#' @param is_admin Reactive indicating if user is admin
#' @return List with reactive values and functions
instellingen_server <- function(id, current_user, is_admin) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES
    # ========================================================================
    
    # Currently selected dropdown category
    selected_category <- reactiveVal(NULL)
    
    # Data refresh triggers
    users_refresh <- reactiveVal(0)
    dropdown_refresh <- reactiveVal(0)
    
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
                 aangemaakt_op, laatst_ingelogd
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
          `Acties` = paste0(
            '<button class="btn btn-sm btn-outline-primary" onclick="Shiny.setInputValue(\'', 
            session$ns('edit_user'), '\', \'', gebruikersnaam, '\', {priority: \'event\'})">',
            '<i class="fa fa-edit"></i> Bewerken</button>'
          )
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
              next = "Volgende", previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE
      )
      
    }, server = TRUE)
    
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
          SELECT waarde, weergave_naam, volgorde, actief,
                 aangemaakt_door, aangemaakt_op
          FROM dropdown_opties 
          WHERE categorie = ?
          ORDER BY volgorde, waarde
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
          `Aangemaakt` = format_date_nl(as.Date(aangemaakt_op)),
          `Acties` = paste0(
            '<button class="btn btn-sm btn-outline-primary" onclick="Shiny.setInputValue(\'', 
            session$ns('edit_dropdown_value'), '\', \'', waarde, '\', {priority: \'event\'})">',
            '<i class="fa fa-edit"></i> Bewerken</button>'
          )
        ) %>%
        select(
          "Waarde" = waarde,
          "Weergave Naam" = `Weergave Naam`,
          "Volgorde" = volgorde,
          "Actief" = Actief,
          "Door" = aangemaakt_door,
          "Aangemaakt" = Aangemaakt,
          "Acties" = Acties
        )
      
      DT::datatable(
        display_data,
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
              next = "Volgende", previous = "Vorige"
            )
          )
        ),
        rownames = FALSE,
        class = "table table-striped table-hover compact",
        escape = FALSE
      )
      
    }, server = TRUE)
    
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
                  "Gebruiker" = "user",
                  "Administrator" = "admin"
                ),
                selected = "user"
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
            aangemaakt_door, aangemaakt_op
          ) VALUES (?, ?, ?, ?, ?, ?)
        ", list(
          input$new_user_username,
          password_hash,
          input$new_user_role,
          if (input$new_user_active) 1 else 0,
          current_user(),
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
              session$ns("new_dropdown_waarde"),
              "Waarde (database): *",
              placeholder = "bijv. nieuwe_waarde_zonder_spaties"
            ),
            
            textInput(
              session$ns("new_dropdown_weergave"),
              "Weergave Naam: *",
              placeholder = "bijv. Nieuwe Waarde Met Spaties"
            ),
            
            numericInput(
              session$ns("new_dropdown_volgorde"),
              "Volgorde:",
              value = 0,
              min = 0,
              step = 1
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
              "De waarde wordt gebruikt in de database, de weergave naam wordt getoond aan gebruikers."
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
      
      # Validation
      errors <- c()
      
      if (is.null(input$new_dropdown_waarde) || input$new_dropdown_waarde == "") {
        errors <- c(errors, "Waarde is verplicht")
      }
      
      if (is.null(input$new_dropdown_weergave) || input$new_dropdown_weergave == "") {
        errors <- c(errors, "Weergave naam is verplicht")
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
        ", list(category, input$new_dropdown_waarde))
        
        if (existing$count > 0) {
          output$dropdown_form_messages <- renderUI({
            div(class = "alert alert-warning", "Deze waarde bestaat al voor deze categorie")
          })
          return()
        }
        
        # Insert dropdown value
        DBI::dbExecute(con, "
          INSERT INTO dropdown_opties (
            categorie, waarde, weergave_naam, volgorde, actief,
            aangemaakt_door, aangemaakt_op
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ", list(
          category,
          input$new_dropdown_waarde,
          input$new_dropdown_weergave,
          input$new_dropdown_volgorde,
          if (input$new_dropdown_active) 1 else 0,
          current_user(),
          as.character(Sys.time())
        ))
        
        cli_alert_success("Dropdown value created: {category}/{input$new_dropdown_waarde}")
        show_notification(paste("Waarde toegevoegd:", input$new_dropdown_weergave), type = "message")
        
        # Refresh dropdowns
        dropdown_refresh(dropdown_refresh() + 1)
        
        # Close modal
        removeModal()
        
      }, error = function(e) {
        cli_alert_danger("Error creating dropdown value: {e$message}")
        show_notification("Fout bij aanmaken waarde", type = "error")
      })
    })
    
    # ========================================================================
    # EDIT HANDLERS
    # ========================================================================
    
    # Edit user handler
    observeEvent(input$edit_user, {
      req(is_admin(), input$edit_user)
      
      username <- input$edit_user
      cli_alert_info("Edit user requested: {username}")
      
      # Get user data
      all_users <- users_data()
      user_data <- all_users[all_users$gebruikersnaam == username, ]
      
      if (nrow(user_data) > 0) {
        show_edit_user_modal(user_data[1, ])
      }
    })
    
    # Edit dropdown value handler
    observeEvent(input$edit_dropdown_value, {
      req(is_admin(), selected_category(), input$edit_dropdown_value)
      
      category <- selected_category()
      waarde <- input$edit_dropdown_value
      cli_alert_info("Edit dropdown value requested: {category}/{waarde}")
      
      # Get dropdown value data
      all_values <- dropdown_values_data()
      value_data <- all_values[all_values$waarde == waarde, ]
      
      if (nrow(value_data) > 0) {
        show_edit_dropdown_modal(value_data[1, ], category)
      }
    })
    
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
            textInput(
              session$ns("edit_user_username"),
              "Gebruikersnaam:",
              value = user_data$gebruikersnaam,
              readonly = TRUE
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
                "Gebruiker" = "user",
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
              session$ns("edit_dropdown_waarde"),
              "Waarde (database): *",
              value = value_data$waarde
            ),
            
            textInput(
              session$ns("edit_dropdown_weergave"),
              "Weergave Naam: *",
              value = ifelse(is.na(value_data$weergave_naam), "", value_data$weergave_naam)
            ),
            
            numericInput(
              session$ns("edit_dropdown_volgorde"),
              "Volgorde:",
              value = value_data$volgorde,
              min = 0,
              step = 1
            ),
            
            checkboxInput(
              session$ns("edit_dropdown_active"),
              "Actief",
              value = (value_data$actief == 1)
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
          ", list(password_hash, input$edit_user_role, 
                  if (input$edit_user_active) 1 else 0, username))
        } else {
          # Update without password
          DBI::dbExecute(con, "
            UPDATE gebruikers SET 
              rol = ?, actief = ?
            WHERE gebruikersnaam = ?
          ", list(input$edit_user_role, 
                  if (input$edit_user_active) 1 else 0, username))
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
      
      # Validation
      errors <- c()
      
      if (is.null(input$edit_dropdown_waarde) || input$edit_dropdown_waarde == "") {
        errors <- c(errors, "Waarde is verplicht")
      }
      
      if (is.null(input$edit_dropdown_weergave) || input$edit_dropdown_weergave == "") {
        errors <- c(errors, "Weergave naam is verplicht")
      }
      
      # Check if new value already exists (only if changed)
      if (input$edit_dropdown_waarde != original_waarde) {
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        existing <- DBI::dbGetQuery(con, "
          SELECT COUNT(*) as count FROM dropdown_opties 
          WHERE categorie = ? AND waarde = ?
        ", list(category, input$edit_dropdown_waarde))
        
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
            waarde = ?, weergave_naam = ?, volgorde = ?, actief = ?
          WHERE categorie = ? AND waarde = ?
        ", list(
          input$edit_dropdown_waarde,
          input$edit_dropdown_weergave,
          input$edit_dropdown_volgorde,
          if (input$edit_dropdown_active) 1 else 0,
          category,
          original_waarde
        ))
        
        cli_alert_success("Dropdown value updated: {category}/{original_waarde} -> {input$edit_dropdown_waarde}")
        show_notification(paste("Waarde bijgewerkt:", input$edit_dropdown_weergave), type = "message")
        
        # Refresh dropdowns
        dropdown_refresh(dropdown_refresh() + 1)
        
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