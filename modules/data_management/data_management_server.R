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
    
    # Lopende cases (from filtered data)
    output$stat_open <- renderText({
      data <- filtered_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      open_count <- sum(data$status_zaak == "Lopend", na.rm = TRUE)
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
    
    # Cached display data with debouncing for performance
    # Also react to dropdown changes for real-time updates
    display_data_cached <- reactive({
      # React to dropdown changes to update display names
      if (!is.null(global_dropdown_refresh_trigger)) {
        global_dropdown_refresh_trigger()
      }
      
      data <- filtered_data()
      
      if (is.null(data) || nrow(data) == 0) {
        return(data.frame())
      }
      
      # Haal zichtbare kolommen voor huidige gebruiker op
      req(current_user())
      
      tryCatch({
        con <- get_db_connection()
        on.exit(close_db_connection(con))
        
        gebruiker <- DBI::dbGetQuery(con, "
          SELECT gebruiker_id FROM gebruikers WHERE gebruikersnaam = ?
        ", params = list(current_user()))
        
        if (nrow(gebruiker) == 0) {
          # Fallback naar alle kolommen als gebruiker niet gevonden
          zichtbare_kolommen <- NULL
        } else {
          zichtbare_kolommen <- get_zichtbare_kolommen(gebruiker$gebruiker_id[1])
        }
        
      }, error = function(e) {
        # Fallback naar alle kolommen bij error
        zichtbare_kolommen <- NULL
      })
      
      # Prepare display data with many-to-many directies (OPTIMIZED)
      prepared_data <- data %>%
        rowwise() %>%
        mutate(
          # Get directies for each zaak via many-to-many table (plain text for formatStyle)
          directies = {
            dirs <- get_zaak_directies(zaak_id)
            if (length(dirs) == 0 || all(is.na(dirs))) {
              NA_character_  # Gebruik NA net als andere dropdown velden
            } else {
              # Filter out NA and empty values
              dirs <- dirs[!is.na(dirs) & dirs != ""]
              if (length(dirs) == 0) {
                NA_character_  # Gebruik NA net als andere dropdown velden
              } else {
                # Convert each directie to display name
                weergave_namen <- sapply(dirs, function(d) {
                  get_weergave_naam_cached("aanvragende_directie", d)
                })
                paste(weergave_namen, collapse = ", ")
              }
            }
          },
          # Bereken looptijd (dagen vanaf aanmaak tot nu)
          looptijd = as.numeric(difftime(Sys.Date(), datum_aanmaak, units = "days")),
          # Bereken dagen relatief tot deadline (negatief = voor deadline, positief = na deadline)
          tijd_tot_deadline = ifelse(!is.na(deadline), 
            as.numeric(difftime(as.Date(deadline), Sys.Date(), units = "days")), 
            NA_real_
          )
        ) %>%
        ungroup()
      
      # Als geen kolom instellingen, gebruik alle kolommen
      if (is.null(zichtbare_kolommen)) {
        zichtbare_kolommen <- c("zaak_id", "status_zaak", "type_dienst", "rechtsgebied", 
                                "omschrijving", "directies", "datum_aanmaak", "looptijd", 
                                "deadline", "tijd_tot_deadline", "advocaat", "adv_kantoor",
                                "laatst_gewijzigd", "gewijzigd_door")
      }
      
      # Mapping van database kolomnamen naar display names
      kolom_mapping <- list(
        "zaak_id" = c(col = "zaak_id", display = "Zaak ID"),
        "status_zaak" = c(col = "status_zaak", display = "Status"),
        "type_dienst" = c(col = "type_dienst", display = "Type Dienst"),
        "rechtsgebied" = c(col = "rechtsgebied", display = "Rechtsgebied"),
        "zaakaanduiding" = c(col = "zaakaanduiding", display = "Zaakaanduiding"),
        "directies" = c(col = "directies", display = "Aanvragende Directies"),
        "type_procedure" = c(col = "type_procedure", display = "Type Procedure"),
        "hoedanigheid_partij" = c(col = "hoedanigheid_partij", display = "Hoedanigheid Partij"),
        "type_wederpartij" = c(col = "type_wederpartij", display = "Type Wederpartij"),
        "reden_inzet" = c(col = "reden_inzet", display = "Reden Inzet"),
        "advocaat" = c(col = "advocaat", display = "Advocaat"),
        "adv_kantoor" = c(col = "adv_kantoor", display = "Advocatenkantoor"),
        "la_budget_wjz" = c(col = "la_budget_wjz", display = "LA Budget WJZ"),
        "budget_andere_directie" = c(col = "budget_andere_directie", display = "Budget Andere Directie"),
        "financieel_risico" = c(col = "financieel_risico", display = "Financieel Risico"),
        "kostenplaats" = c(col = "kostenplaats", display = "Kostenplaats"),
        "intern_ordernummer" = c(col = "intern_ordernummer", display = "Intern Ordernummer"),
        "grootboekrekening" = c(col = "grootboekrekening", display = "Grootboekrekening"),
        "budgetcode" = c(col = "budgetcode", display = "Budgetcode"),
        "proza_link" = c(col = "proza_link", display = "ProZa Link"),
        "locatie_formulier" = c(col = "locatie_formulier", display = "Locatie Formulier"),
        "budget_beleid" = c(col = "budget_beleid", display = "Budget Beleid"),
        "datum_aanmaak" = c(col = "datum_aanmaak", display = "Datum Aanmaak"),
        "looptijd" = c(col = "looptijd", display = "Looptijd (dagen)"),
        "deadline" = c(col = "deadline", display = "Deadline"),
        "tijd_tot_deadline" = c(col = "tijd_tot_deadline", display = "Tijd tot Deadline"),
        "laatst_gewijzigd" = c(col = "laatst_gewijzigd", display = "Laatst Gewijzigd"),
        "gewijzigd_door" = c(col = "gewijzigd_door", display = "Gewijzigd Door")
      )
      
      # Selecteer alleen zichtbare kolommen die beschikbaar zijn
      beschikbare_kolommen <- names(prepared_data)
      select_list <- list()
      
      for (visible_col in zichtbare_kolommen) {
        if (visible_col %in% names(kolom_mapping)) {
          mapping <- kolom_mapping[[visible_col]]
          col_name <- mapping[["col"]]
          display_name <- mapping[["display"]]
          
          if (col_name %in% beschikbare_kolommen) {
            select_list[[display_name]] <- col_name
          }
        }
      }
      
      # Selecteer de kolommen
      result_data <- prepared_data %>%
        select(!!!select_list)
      
      # Dynamisch formatteren van zichtbare kolommen
      if (nrow(result_data) > 0) {
        kolom_namen <- names(result_data)
        
        # Datum formatting
        if ("Datum Aanmaak" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Datum Aanmaak` = format_date_nl(`Datum Aanmaak`))
        }
        
        # Deadline formatting
        if ("Deadline" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(Deadline = ifelse(is.na(Deadline), "-", format_date_nl(as.Date(Deadline))))
        }
        
        # Looptijd formatting
        if ("Looptijd (dagen)" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Looptijd (dagen)` = paste0(`Looptijd (dagen)`, " dagen"))
        }
        
        # Tijd tot deadline formatting
        if ("Tijd tot Deadline" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Tijd tot Deadline` = ifelse(
              is.na(`Tijd tot Deadline`), "-", 
              ifelse(`Tijd tot Deadline` < 0, paste0(abs(`Tijd tot Deadline`), " dagen te laat"),
                ifelse(`Tijd tot Deadline` == 0, "Vandaag", 
                  ifelse(`Tijd tot Deadline` > 0, paste0(`Tijd tot Deadline`, " dagen"), "-")
                )
              )
            ))
        }
        
        # Convert database values to display names (OPTIMIZED - bulk conversion)
        if ("Type Dienst" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Type Dienst` = {
              converted <- bulk_get_weergave_namen("type_dienst", `Type Dienst`)
              ifelse(is.na(converted), "", converted)
            })
        }
        
        if ("Rechtsgebied" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(Rechtsgebied = {
              converted <- bulk_get_weergave_namen("rechtsgebied", Rechtsgebied)
              ifelse(is.na(converted), "", converted)
            })
        }
        
        if ("Status" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(Status = {
              converted <- bulk_get_weergave_namen("status_zaak", Status)
              ifelse(is.na(converted), "", converted)
            })
        }
        
        # Convert NA directies to empty string for display
        if ("Aanvragende Directies" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Aanvragende Directies` = ifelse(is.na(`Aanvragende Directies`), "", `Aanvragende Directies`))
        }
        
        # Truncate long descriptions
        if ("Zaakaanduiding" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(Zaakaanduiding = ifelse(
              nchar(Zaakaanduiding) > 60, 
              paste0(substr(Zaakaanduiding, 1, 57), "..."), 
              Zaakaanduiding
            ))
        }
        
        # Format laatst_gewijzigd
        if ("Laatst Gewijzigd" %in% kolom_namen) {
          result_data <- result_data %>%
            mutate(`Laatst Gewijzigd` = format(`Laatst Gewijzigd`, "%d-%m-%Y %H:%M"))
        }
      }
      
      return(result_data)
    }) %>% 
      debounce(300)  # Debounce for performance

    output$zaken_table <- DT::renderDataTable({
      
      display_data <- display_data_cached()
      
      # Show message if no data
      if (is.null(display_data) || nrow(display_data) == 0) {
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
      
      # Get colors for all dropdown categories
      alle_kleuren <- get_dropdown_kleuren()
      
      # Create DataTable with background colors
      dt <- DT::datatable(
        display_data,
        selection = 'none',  # Disable row selection highlighting
        options = list(
          pageLength = 25,
          lengthMenu = c(10, 25, 50, 100),
          scrollX = TRUE,
          autoWidth = FALSE,
          dom = 'frtip',  # Simple layout: filter, table, info, pagination
          columnDefs = list(
            list(className = "dt-left", targets = "_all")  # Left align all columns
          ),
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
      )
      
      # Apply background colors using formatStyle - alleen voor zichtbare kolommen
      kolom_namen <- names(display_data)
      
      # Status column styling
      if ("Status" %in% kolom_namen && "status_zaak" %in% names(alle_kleuren)) {
        status_kleuren <- alle_kleuren[["status_zaak"]]
        
        # Get all unique weergave values and their colors
        weergave_values <- character()
        color_values <- character()
        text_colors <- character()
        
        for (waarde in names(status_kleuren)) {
          if (!is.na(status_kleuren[[waarde]]) && status_kleuren[[waarde]] != "") {
            weergave <- get_weergave_naam_cached("status_zaak", waarde)
            weergave_values <- c(weergave_values, weergave)
            color_values <- c(color_values, status_kleuren[[waarde]])
            text_colors <- c(text_colors, ifelse(waarde == "Lopend", "black", "white"))
          }
        }
        
        if (length(weergave_values) > 0) {
          dt <- dt %>% 
            DT::formatStyle(
              "Status",
              backgroundColor = DT::styleEqual(weergave_values, color_values),
              color = "black",
              fontWeight = "bold"
            )
        }
      }
      
      # Type Dienst column styling
      if ("Type Dienst" %in% kolom_namen && "type_dienst" %in% names(alle_kleuren)) {
        type_kleuren <- alle_kleuren[["type_dienst"]]
        
        weergave_values <- character()
        color_values <- character()
        text_colors <- character()
        
        for (waarde in names(type_kleuren)) {
          if (!is.na(type_kleuren[[waarde]]) && type_kleuren[[waarde]] != "") {
            weergave <- get_weergave_naam_cached("type_dienst", waarde)
            weergave_values <- c(weergave_values, weergave)
            color_values <- c(color_values, type_kleuren[[waarde]])
            text_colors <- c(text_colors, "white")
          }
        }
        
        if (length(weergave_values) > 0) {
          dt <- dt %>% 
            DT::formatStyle(
              "Type Dienst",
              backgroundColor = DT::styleEqual(weergave_values, color_values),
              color = "black"
            )
        }
      }
      
      # Rechtsgebied column styling
      if ("Rechtsgebied" %in% kolom_namen && "rechtsgebied" %in% names(alle_kleuren)) {
        rechts_kleuren <- alle_kleuren[["rechtsgebied"]]
        
        weergave_values <- character()
        color_values <- character()
        text_colors <- character()
        
        for (waarde in names(rechts_kleuren)) {
          if (!is.na(rechts_kleuren[[waarde]]) && rechts_kleuren[[waarde]] != "") {
            weergave <- get_weergave_naam_cached("rechtsgebied", waarde)
            weergave_values <- c(weergave_values, weergave)
            color_values <- c(color_values, rechts_kleuren[[waarde]])
            text_colors <- c(text_colors, "white")
          }
        }
        
        if (length(weergave_values) > 0) {
          dt <- dt %>% 
            DT::formatStyle(
              "Rechtsgebied",
              backgroundColor = DT::styleEqual(weergave_values, color_values),
              color = "black"
            )
        }
      }
      
      # Directie column styling (more complex due to comma-separated values)
      if ("Aanvragende Directies" %in% kolom_namen && "aanvragende_directie" %in% names(alle_kleuren)) {
        directie_kleuren <- alle_kleuren[["aanvragende_directie"]]
        
        # For directies, we need to check if any of the comma-separated values has a color
        # We'll use a simple approach: if the cell contains exactly one directie that has a color, apply it
        weergave_values <- character()
        color_values <- character()
        text_colors <- character()
        
        for (waarde in names(directie_kleuren)) {
          if (!is.na(directie_kleuren[[waarde]]) && directie_kleuren[[waarde]] != "") {
            weergave <- get_weergave_naam_cached("aanvragende_directie", waarde)
            weergave_values <- c(weergave_values, weergave)
            color_values <- c(color_values, directie_kleuren[[waarde]])
            text_colors <- c(text_colors, "white")
          }
        }
        
        if (length(weergave_values) > 0) {
          dt <- dt %>% 
            DT::formatStyle(
              "Aanvragende Directies",
              backgroundColor = DT::styleEqual(weergave_values, color_values),
              color = "black"
            )
        }
      }
      
      # Deadline styling using configurable colors from database
      if ("Tijd tot Deadline" %in% kolom_namen) {
        deadline_values <- unique(display_data$`Tijd tot Deadline`)
        deadline_values <- deadline_values[!is.na(deadline_values) & deadline_values != "-"]
        
        if (length(deadline_values) > 0) {
        # Get deadline color configuration from database
        deadline_kleuren_config <- tryCatch({
          get_deadline_kleuren()
        }, error = function(e) {
          data.frame()  # Fallback to empty config
        })
        
        # Create color mappings for deadline values based on configuration
        bg_colors <- character(length(deadline_values))
        text_colors <- character(length(deadline_values))
        font_weights <- character(length(deadline_values))
        
        for (i in seq_along(deadline_values)) {
          value <- deadline_values[i]
          
          # Extract numeric days from the display text
          dagen_tot_deadline <- NA
          
          if (value == "Vandaag") {
            dagen_tot_deadline <- 0
          } else if (value == "-") {
            dagen_tot_deadline <- NA
          } else if (grepl("dagen te laat", value)) {
            # Extract number - negative means after deadline (days past)
            nums <- as.numeric(gsub("([0-9]+).*", "\\1", value))
            if (!is.na(nums)) dagen_tot_deadline <- -nums
          } else if (grepl("^[0-9]+ dagen$", value)) {
            # Extract number - positive means before deadline (days remaining)
            nums <- as.numeric(gsub("([0-9]+).*", "\\1", value))
            if (!is.na(nums)) dagen_tot_deadline <- nums
          }
          
          # Find matching color configuration
          kleur <- "transparent"
          text_kleur <- "inherit"
          font_weight <- "normal"
          
          if (!is.na(dagen_tot_deadline) && nrow(deadline_kleuren_config) > 0) {
            for (j in 1:nrow(deadline_kleuren_config)) {
              config_row <- deadline_kleuren_config[j, ]
              
              # Handle infinite ranges (NULL values)
              dagen_voor <- ifelse(is.na(config_row$dagen_voor), -Inf, config_row$dagen_voor)
              dagen_tot <- ifelse(is.na(config_row$dagen_tot), Inf, config_row$dagen_tot)
              
              if (dagen_tot_deadline >= dagen_voor && dagen_tot_deadline <= dagen_tot) {
                kleur <- config_row$kleur
                # Determine text color based on background brightness
                if (kleur %in% c("#dc3545", "#fd7e14")) {
                  text_kleur <- "white"
                } else {
                  text_kleur <- "black"
                }
                font_weight <- "bold"
                break
              }
            }
          }
          
          bg_colors[i] <- kleur
          text_colors[i] <- text_kleur
          font_weights[i] <- font_weight
        }
        
        # Apply styling using styleEqual like the Status column
        dt <- dt %>%
          DT::formatStyle(
            "Tijd tot Deadline",
            backgroundColor = DT::styleEqual(deadline_values, bg_colors),
            color = DT::styleEqual(deadline_values, text_colors),
            fontWeight = DT::styleEqual(deadline_values, font_weights)
          )
        }
      }
      
      dt
      
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
    
    # Clear dropdown cache when settings change for real-time updates
    observeEvent(global_dropdown_refresh_trigger(), {
      if (!is.null(global_dropdown_refresh_trigger)) {
        # Clear the dropdown cache to force fresh display names
        clear_dropdown_cache()
        cli_alert_info("Dropdown cache cleared due to settings change - zaakbeheer will show updated display names")
      }
    }, ignoreInit = TRUE)
    
    observe({
      # React to global dropdown refresh trigger
      if (!is.null(global_dropdown_refresh_trigger)) {
        global_dropdown_refresh_trigger()
      }
      
      tryCatch({
        dropdown_choices$type_dienst <- get_dropdown_opties("type_dienst", exclude_fallback = TRUE)
        dropdown_choices$rechtsgebied <- get_dropdown_opties("rechtsgebied", exclude_fallback = TRUE)
        dropdown_choices$status_zaak <- get_dropdown_opties("status_zaak", exclude_fallback = TRUE)
        dropdown_choices$aanvragende_directie <- get_dropdown_opties("aanvragende_directie", exclude_fallback = TRUE)
        
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
                strong("Deadline: "), ifelse(is.na(zaak_data$deadline), "-", format_date_nl(as.Date(zaak_data$deadline))), br(),
                strong("WJZ MT-lid: "), ifelse(is.na(zaak_data$wjz_mt_lid), "-", zaak_data$wjz_mt_lid), br(),
                strong("Status: "), ifelse(is.na(zaak_data$status_zaak), "-", get_weergave_naam("status_zaak", zaak_data$status_zaak)), br(),
                strong("Type Dienst: "), ifelse(is.na(zaak_data$type_dienst), "-", get_weergave_naam("type_dienst", zaak_data$type_dienst)), br(),
                strong("Aanvragende Directie: "), {
                  dirs <- get_zaak_directies(zaak_data$zaak_id)
                  if (length(dirs) == 0) {
                    "-"
                  } else {
                    weergave_namen <- sapply(dirs, function(d) get_weergave_naam("aanvragende_directie", d))
                    paste(weergave_namen, collapse = ", ")
                  }
                }, br(),
                strong("Contactpersoon: "), ifelse(is.na(zaak_data$contactpersoon), "-", zaak_data$contactpersoon)
            ),
            div(class = "col-md-6",
                strong("Rechtsgebied: "), ifelse(is.na(zaak_data$rechtsgebied), "-", get_weergave_naam("rechtsgebied", zaak_data$rechtsgebied)), br(),
                strong("Advocaat: "), ifelse(is.na(zaak_data$advocaat), "-", zaak_data$advocaat), br(),
                strong("Kantoor: "), ifelse(is.na(zaak_data$adv_kantoor), "-", zaak_data$adv_kantoor)
            )
          ),
          
          h5("Zaakaanduiding", class = "border-bottom pb-2 mb-3"),
          p(ifelse(is.na(zaak_data$zaakaanduiding), "Geen zaakaanduiding", zaak_data$zaakaanduiding)),
          
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
          
          h5("Administratieve Gegevens", class = "border-bottom pb-2 mb-3"),
          
          div(
            class = "row mb-2",
            div(class = "col-md-6",
                strong("Kostenplaats: "), ifelse(is.na(zaak_data$kostenplaats), "-", zaak_data$kostenplaats), br(),
                strong("Intern Ordernummer: "), ifelse(is.na(zaak_data$intern_ordernummer), "-", zaak_data$intern_ordernummer), br(),
                strong("Grootboekrekening: "), ifelse(is.na(zaak_data$grootboekrekening), "-", zaak_data$grootboekrekening)
            ),
            div(class = "col-md-6",
                strong("Budgetcode: "), ifelse(is.na(zaak_data$budgetcode), "-", zaak_data$budgetcode), br(),
                strong("ProZa-link: "), ifelse(is.na(zaak_data$proza_link), "-", zaak_data$proza_link), br(),
                strong("Locatie Formulier: "), ifelse(is.na(zaak_data$locatie_formulier), "-", zaak_data$locatie_formulier)
            )
          ),
          
          if (!is.na(zaak_data$budget_beleid) && zaak_data$budget_beleid != "") {
            div(
              h5("Advocaat Budget Beleid", class = "border-bottom pb-2 mb-3"),
              p(zaak_data$budget_beleid)
            )
          },
          
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
      # Reset deadline cleared state when opening modal
      edit_deadline_cleared(FALSE)
      
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
              
              div(
                class = "mb-3",
                dateInput(
                  session$ns("edit_form_deadline"),
                  "Deadline:",
                  value = if (!is.na(zaak_data$deadline)) as.Date(zaak_data$deadline) else NA,
                  format = "dd-mm-yyyy",
                  language = "nl"
                ),
                div(
                  class = "mt-2",
                  actionButton(
                    session$ns("btn_clear_edit_deadline"),
                    "Deadline wissen",
                    class = "btn-outline-secondary btn-sm",
                    icon = icon("times")
                  )
                )
              ),
              
              textInput(
                session$ns("edit_form_wjz_mt_lid"),
                "WJZ MT-lid:",
                value = ifelse(is.na(zaak_data$wjz_mt_lid), "", zaak_data$wjz_mt_lid)
              ),
              
              selectizeInput(
                session$ns("edit_form_aanvragende_directie"),
                "Aanvragende Directie:",
                choices = NULL,
                selected = NULL,
                multiple = TRUE,
                options = list(
                  placeholder = "Selecteer één of meer directies",
                  maxItems = 5
                )
              ),
              
              textInput(
                session$ns("edit_form_contactpersoon"),
                "Contactpersoon:",
                value = ifelse(is.na(zaak_data$contactpersoon), "", zaak_data$contactpersoon)
              )
            ),
            
            # Right column
            div(
              class = "col-md-6",
              
              selectInput(
                session$ns("edit_form_type_dienst"),
                "Type Dienst:",
                choices = c("Selecteer..." = "", dropdown_choices$type_dienst),
                selected = ifelse(is.na(zaak_data$type_dienst), "", zaak_data$type_dienst),
                multiple = FALSE
              ),
              
              selectInput(
                session$ns("edit_form_rechtsgebied"),
                "Rechtsgebied:",
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
                value = ifelse(is.na(zaak_data$advocaat), "", zaak_data$advocaat),
                placeholder = "Naam van de advocaat"
              ),
              
              textInput(
                session$ns("edit_form_adv_kantoor"),
                "Advocatenkantoor:",
                value = ifelse(is.na(zaak_data$adv_kantoor), "", zaak_data$adv_kantoor),
                placeholder = "Naam van het kantoor"
              )
            )
          ),
          
          # Omschrijving - formulier-breed
          div(
            class = "row mt-3",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("edit_form_zaakaanduiding"),
                "Zaakaanduiding:",
                value = ifelse(is.na(zaak_data$zaakaanduiding), "", zaak_data$zaakaanduiding),
                rows = 3
              )
            )
          ),
          
          # Optional fields section
          hr(),
          h6("Optionele Velden", class = "text-muted"),
          
          # Financiële velden
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
          
          # Administratieve velden
          h6("Administratieve Gegevens", class = "text-muted mt-3"),
          
          div(
            class = "row",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_kostenplaats"),
                "Kostenplaats:",
                value = ifelse(is.na(zaak_data$kostenplaats), "", zaak_data$kostenplaats),
                placeholder = "bijv. 72200"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_intern_ordernummer"),
                "Intern Ordernummer:",
                value = ifelse(is.na(zaak_data$intern_ordernummer), "", zaak_data$intern_ordernummer),
                placeholder = "bijv. 9070205"
              )
            )
          ),
          
          div(
            class = "row mt-2",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_grootboekrekening"),
                "Grootboekrekening:",
                value = ifelse(is.na(zaak_data$grootboekrekening), "", zaak_data$grootboekrekening),
                placeholder = "bijv. 440170"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_budgetcode"),
                "Budgetcode:",
                value = ifelse(is.na(zaak_data$budgetcode), "", zaak_data$budgetcode),
                placeholder = "Budgetcode indien van toepassing"
              )
            )
          ),
          
          div(
            class = "row mt-2",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_proza_link"),
                "ProZa-link:",
                value = ifelse(is.na(zaak_data$proza_link), "", zaak_data$proza_link),
                placeholder = "Link naar ProZa systeem"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("edit_form_locatie_formulier"),
                "Locatie Formulier:",
                value = ifelse(is.na(zaak_data$locatie_formulier), "", zaak_data$locatie_formulier),
                placeholder = "Waar bevindt zich het formulier?"
              )
            )
          ),
          
          # Budget beleid tekstveld
          div(
            class = "row mt-2",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("edit_form_budget_beleid"),
                "Advocaat Budget Beleid:",
                value = ifelse(is.na(zaak_data$budget_beleid), "", zaak_data$budget_beleid),
                rows = 2,
                placeholder = "Beleidsinformatie over budget en advocaat inzet..."
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
      
      # Update dropdown choices and selected values for the edit form
      updateSelectizeInput(session, "edit_form_aanvragende_directie",
                          choices = dropdown_choices$aanvragende_directie,
                          selected = get_zaak_directies(zaak_data$zaak_id))
    }
    
    # ========================================================================
    # NIEUWE ZAAK MODAL
    # ========================================================================
    
    # Show new case modal
    show_nieuwe_zaak_modal <- function() {
      # Reset deadline cleared state when opening modal
      new_deadline_cleared(FALSE)
      
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
              
              div(
                class = "mb-3",
                dateInput(
                  session$ns("form_deadline"),
                  "Deadline:",
                  value = NA,
                  format = "dd-mm-yyyy",
                  language = "nl"
                ),
                div(
                  class = "mt-2",
                  actionButton(
                    session$ns("btn_clear_new_deadline"),
                    "Deadline wissen",
                    class = "btn-outline-secondary btn-sm",
                    icon = icon("times")
                  )
                )
              ),
              
              textInput(
                session$ns("form_wjz_mt_lid"),
                "WJZ MT-lid:",
                placeholder = "Naam van het WJZ MT-lid"
              ),
              
              selectizeInput(
                session$ns("form_aanvragende_directie"),
                "Aanvragende Directie:",
                choices = NULL,
                multiple = TRUE,
                options = list(
                  placeholder = "Selecteer één of meer directies",
                  maxItems = 5
                )
              ),
              
              textInput(
                session$ns("form_contactpersoon"),
                "Contactpersoon:",
                placeholder = "Naam van de contactpersoon"
              )
            ),
            
            # Right column
            div(
              class = "col-md-6",
              
              selectInput(
                session$ns("form_type_dienst"),
                "Type Dienst:",
                choices = c("Selecteer..." = "", dropdown_choices$type_dienst),
                multiple = FALSE
              ),
              
              selectInput(
                session$ns("form_rechtsgebied"),
                "Rechtsgebied:",
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
              ),
              
              textInput(
                session$ns("form_adv_kantoor"),
                "Advocatenkantoor:",
                placeholder = "Naam van het kantoor"
              )
            )
          ),
          
          # Omschrijving - formulier-breed
          div(
            class = "row mt-3",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("form_zaakaanduiding"),
                "Zaakaanduiding:",
                rows = 3,
                placeholder = "Korte aanduiding van de zaak..."
              )
            )
          ),
          
          # Optional fields section
          hr(),
          h6("Optionele Velden", class = "text-muted"),
          
          # Financiële velden
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
          
          # Administratieve velden
          h6("Administratieve Gegevens", class = "text-muted mt-3"),
          
          div(
            class = "row",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_kostenplaats"),
                "Kostenplaats:",
                placeholder = "bijv. 72200"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_intern_ordernummer"),
                "Intern Ordernummer:",
                placeholder = "bijv. 9070205"
              )
            )
          ),
          
          div(
            class = "row mt-2",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_grootboekrekening"),
                "Grootboekrekening:",
                placeholder = "bijv. 440170"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_budgetcode"),
                "Budgetcode:",
                placeholder = "Budgetcode indien van toepassing"
              )
            )
          ),
          
          div(
            class = "row mt-2",
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_proza_link"),
                "ProZa-link:",
                placeholder = "Link naar ProZa systeem"
              )
            ),
            
            div(
              class = "col-md-6",
              textInput(
                session$ns("form_locatie_formulier"),
                "Locatie Formulier:",
                placeholder = "Waar bevindt zich het formulier?"
              )
            )
          ),
          
          # Budget beleid tekstveld
          div(
            class = "row mt-2",
            
            div(
              class = "col-12",
              textAreaInput(
                session$ns("form_budget_beleid"),
                "Advocaat Budget Beleid:",
                rows = 2,
                placeholder = "Beleidsinformatie over budget en advocaat inzet..."
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
      
      # Update dropdown choices for the form
      updateSelectizeInput(session, "form_aanvragende_directie",
                          choices = dropdown_choices$aanvragende_directie)
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
    
    # Download handler for Excel export
    output$download_excel <- downloadHandler(
      filename = function() {
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        paste0("Zaken_Export_", timestamp, ".xlsx")
      },
      content = function(file) {
        cli_alert_info("Excel download requested by user: {current_user()}")
        
        data <- filtered_data()
        
        if (is.null(data) || nrow(data) == 0) {
          # Create an empty file with a message
          empty_data <- data.frame("Bericht" = "Geen data beschikbaar om te exporteren")
          writexl::write_xlsx(list("Bericht" = empty_data), path = file)
          return()
        }
        
        tryCatch({
          # Prepare export data with proper formatting
          export_data <- data %>%
            rowwise() %>%
            mutate(
              # Get directies for each zaak via many-to-many table for export
              `Aanvragende Directie` = {
                dirs <- get_zaak_directies(zaak_id)
                if (length(dirs) == 0 || all(is.na(dirs))) {
                  ""
                } else {
                  # Filter out NA and empty values
                  dirs <- dirs[!is.na(dirs) & dirs != ""]
                  if (length(dirs) == 0) {
                    ""
                  } else {
                    # Convert each directie to display name
                    weergave_namen <- character(length(dirs))
                    for (i in seq_along(dirs)) {
                      weergave_namen[i] <- get_weergave_naam("aanvragende_directie", dirs[i])
                    }
                    paste(weergave_namen, collapse = ", ")
                  }
                }
              }
            ) %>%
            ungroup() %>%
            mutate(
              # Bereken looptijd voor export
              Looptijd = as.numeric(difftime(Sys.Date(), datum_aanmaak, units = "days"))
            ) %>%
            select(
              "Zaak ID" = zaak_id,
              "Datum Aanmaak" = datum_aanmaak,
              "Deadline" = deadline,
              "Looptijd (dagen)" = Looptijd,
              "Zaakaanduiding" = zaakaanduiding,
              "Type Dienst" = type_dienst,
              "Rechtsgebied" = rechtsgebied,
              "Status" = status_zaak,
              "Aanvragende Directie" = `Aanvragende Directie`,
              "Advocaat" = advocaat,
              "Advocatenkantoor" = adv_kantoor,
              "Budget WJZ (€)" = la_budget_wjz,
              "Budget Andere Directie (€)" = budget_andere_directie,
              "Financieel Risico (€)" = financieel_risico,
              "Opmerkingen" = opmerkingen,
              "Aangemaakt Door" = aangemaakt_door,
              "Laatst Gewijzigd" = laatst_gewijzigd,
              "Gewijzigd Door" = gewijzigd_door
            ) %>%
            mutate(
              # Format dates
              `Datum Aanmaak` = format_date_nl(`Datum Aanmaak`),
              `Deadline` = ifelse(is.na(`Deadline`), "", format_date_nl(as.Date(`Deadline`))),
              `Laatst Gewijzigd` = ifelse(
                is.na(`Laatst Gewijzigd`), 
                "", 
                format(as.POSIXct(`Laatst Gewijzigd`), "%d-%m-%Y %H:%M")
              ),
              
              # Convert database values to display names for readability
              `Type Dienst` = sapply(`Type Dienst`, function(x) if(is.na(x)) "" else get_weergave_naam("type_dienst", x)),
              Rechtsgebied = sapply(Rechtsgebied, function(x) if(is.na(x)) "" else get_weergave_naam("rechtsgebied", x)),
              Status = sapply(Status, function(x) if(is.na(x)) "" else get_weergave_naam("status_zaak", x)),
              
              # Format currency values
              `Budget WJZ (€)` = ifelse(is.na(`Budget WJZ (€)`) | `Budget WJZ (€)` == 0, "", as.numeric(`Budget WJZ (€)`)),
              `Budget Andere Directie (€)` = ifelse(is.na(`Budget Andere Directie (€)`) | `Budget Andere Directie (€)` == 0, "", as.numeric(`Budget Andere Directie (€)`)),
              `Financieel Risico (€)` = ifelse(is.na(`Financieel Risico (€)`) | `Financieel Risico (€)` == 0, "", as.numeric(`Financieel Risico (€)`)),
              
              # Clean up other fields
              Advocaat = ifelse(is.na(Advocaat), "", Advocaat),
              Advocatenkantoor = ifelse(is.na(Advocatenkantoor), "", Advocatenkantoor),
              Opmerkingen = ifelse(is.na(Opmerkingen), "", Opmerkingen),
              `Aangemaakt Door` = ifelse(is.na(`Aangemaakt Door`), "", `Aangemaakt Door`),
              `Gewijzigd Door` = ifelse(is.na(`Gewijzigd Door`), "", `Gewijzigd Door`)
            )
          
          # Write to Excel with formatting
          writexl::write_xlsx(
            list("Zaken" = export_data), 
            path = file,
            col_names = TRUE,
            format_headers = TRUE
          )
          
          cli_alert_success("Excel file generated for download ({nrow(export_data)} zaken)")
          
        }, error = function(e) {
          cli_alert_danger("Error generating Excel file: {e$message}")
          # Create error file
          error_data <- data.frame("Fout" = paste("Er is een fout opgetreden bij het exporteren:", e$message))
          writexl::write_xlsx(list("Fout" = error_data), path = file)
        })
      },
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
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
            p(strong("Zaakaanduiding: "), zaak_data$zaakaanduiding[1]),
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
      
      # Omschrijving, aanvragende_directie, type_dienst en rechtsgebied zijn nu optioneel
      # Alleen zaak_id, datum_aanmaak en status_zaak zijn verplicht
      
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
    
    # Reactive values to track deadline state
    edit_deadline_cleared <- reactiveVal(FALSE)
    new_deadline_cleared <- reactiveVal(FALSE)
    
    # Cancel edit button
    observeEvent(input$btn_edit_form_cancel, {
      edit_deadline_cleared(FALSE)
      removeModal()
    })
    
    # Handle deadline wissen button (edit form)
    observeEvent(input$btn_clear_edit_deadline, {
      edit_deadline_cleared(TRUE)
      # Clear the deadline field (same logic as checkbox worked)
      updateDateInput(session, "edit_form_deadline", value = NA)
      show_notification("Deadline gewist. Sla op om te bevestigen.", type = "message")
    })
    
    # Handle deadline wissen button (new form)  
    observeEvent(input$btn_clear_new_deadline, {
      new_deadline_cleared(TRUE)
      # Clear the deadline field (same logic as checkbox worked)
      updateDateInput(session, "form_deadline", value = NA)
      show_notification("Deadline gewist. Sla op om te bevestigen.", type = "message")
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
        # Extract directies for separate handling
        selected_directies <- input$edit_form_aanvragende_directie
        
        updated_data <- data.frame(
          zaak_id = input$edit_form_zaak_id,
          datum_aanmaak = tryCatch({
            if(!is.null(input$edit_form_datum_aanmaak) && !is.na(input$edit_form_datum_aanmaak)) {
              as.character(as.Date(input$edit_form_datum_aanmaak))
            } else {
              as.character(Sys.Date())
            }
          }, error = function(e) as.character(Sys.Date())),
          deadline = tryCatch({
            if(edit_deadline_cleared() || is.null(input$edit_form_deadline)) {
              NA_character_
            } else if(is.na(input$edit_form_deadline)) {
              NA_character_
            } else {
              as.character(as.Date(input$edit_form_deadline))
            }
          }, error = function(e) NA_character_),
          zaakaanduiding = if(is.null(input$edit_form_zaakaanduiding) || input$edit_form_zaakaanduiding == "") NA else input$edit_form_zaakaanduiding,
          wjz_mt_lid = if(is.null(input$edit_form_wjz_mt_lid) || input$edit_form_wjz_mt_lid == "") NA else input$edit_form_wjz_mt_lid,
          contactpersoon = if(is.null(input$edit_form_contactpersoon) || input$edit_form_contactpersoon == "") NA else input$edit_form_contactpersoon,
          type_dienst = if(is.null(input$edit_form_type_dienst) || input$edit_form_type_dienst == "") NA else input$edit_form_type_dienst,
          rechtsgebied = if(is.null(input$edit_form_rechtsgebied) || input$edit_form_rechtsgebied == "") NA else input$edit_form_rechtsgebied,
          status_zaak = input$edit_form_status_zaak,
          advocaat = if(is.null(input$edit_form_advocaat) || input$edit_form_advocaat == "" || trimws(input$edit_form_advocaat) == "") NA else trimws(input$edit_form_advocaat),
          adv_kantoor = if(is.null(input$edit_form_adv_kantoor) || input$edit_form_adv_kantoor == "" || trimws(input$edit_form_adv_kantoor) == "") NA else trimws(input$edit_form_adv_kantoor),
          la_budget_wjz = if(is.null(input$edit_form_la_budget_wjz)) 0 else input$edit_form_la_budget_wjz,
          budget_andere_directie = if(is.null(input$edit_form_budget_andere_directie)) 0 else input$edit_form_budget_andere_directie,
          financieel_risico = if(is.null(input$edit_form_financieel_risico)) 0 else input$edit_form_financieel_risico,
          
          # Nieuwe administratieve velden
          kostenplaats = if(is.null(input$edit_form_kostenplaats) || input$edit_form_kostenplaats == "") NA else input$edit_form_kostenplaats,
          intern_ordernummer = if(is.null(input$edit_form_intern_ordernummer) || input$edit_form_intern_ordernummer == "") NA else input$edit_form_intern_ordernummer,
          grootboekrekening = if(is.null(input$edit_form_grootboekrekening) || input$edit_form_grootboekrekening == "") NA else input$edit_form_grootboekrekening,
          budgetcode = if(is.null(input$edit_form_budgetcode) || input$edit_form_budgetcode == "") NA else input$edit_form_budgetcode,
          proza_link = if(is.null(input$edit_form_proza_link) || input$edit_form_proza_link == "") NA else input$edit_form_proza_link,
          locatie_formulier = if(is.null(input$edit_form_locatie_formulier) || input$edit_form_locatie_formulier == "") NA else input$edit_form_locatie_formulier,
          budget_beleid = if(is.null(input$edit_form_budget_beleid) || input$edit_form_budget_beleid == "") NA else input$edit_form_budget_beleid,
          
          opmerkingen = if(is.null(input$edit_form_opmerkingen) || input$edit_form_opmerkingen == "") NA else input$edit_form_opmerkingen,
          stringsAsFactors = FALSE
        )
        
        # Update in database using original zaak_id
        original_id <- original_zaak_id()
        
        # Use the new update_zaak function with many-to-many support
        update_zaak(original_id, updated_data, current_user(), directies = selected_directies)
        
        cli_alert_success("Case updated: {original_id} -> {updated_data$zaak_id}")
        show_notification(paste("Zaak bijgewerkt:", updated_data$zaak_id), type = "message")
        
        # Trigger data refresh
        data_refresh_trigger(data_refresh_trigger() + 1)
        
        # Reset deadline cleared state
        edit_deadline_cleared(FALSE)
        
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
      
      # Omschrijving, aanvragende_directie, type_dienst en rechtsgebied zijn nu optioneel
      # Alleen zaak_id, datum_aanmaak en status_zaak zijn verplicht
      
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
      new_deadline_cleared(FALSE)
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
        # Extract directies for separate handling
        selected_directies <- input$form_aanvragende_directie
        
        form_data <- data.frame(
          zaak_id = input$form_zaak_id,
          datum_aanmaak = tryCatch({
            if(!is.null(input$form_datum_aanmaak) && !is.na(input$form_datum_aanmaak)) {
              as.character(as.Date(input$form_datum_aanmaak))
            } else {
              as.character(Sys.Date())
            }
          }, error = function(e) as.character(Sys.Date())),
          deadline = tryCatch({
            if(new_deadline_cleared() || is.null(input$form_deadline)) {
              NA_character_
            } else if(is.na(input$form_deadline)) {
              NA_character_
            } else {
              as.character(as.Date(input$form_deadline))
            }
          }, error = function(e) NA_character_),
          zaakaanduiding = if(is.null(input$form_zaakaanduiding) || input$form_zaakaanduiding == "") NA else input$form_zaakaanduiding,
          wjz_mt_lid = if(is.null(input$form_wjz_mt_lid) || input$form_wjz_mt_lid == "") NA else input$form_wjz_mt_lid,
          contactpersoon = if(is.null(input$form_contactpersoon) || input$form_contactpersoon == "") NA else input$form_contactpersoon,
          type_dienst = if(is.null(input$form_type_dienst) || input$form_type_dienst == "") NA else input$form_type_dienst,
          rechtsgebied = if(is.null(input$form_rechtsgebied) || input$form_rechtsgebied == "") NA else input$form_rechtsgebied,
          status_zaak = input$form_status_zaak,
          advocaat = if(is.null(input$form_advocaat) || input$form_advocaat == "" || trimws(input$form_advocaat) == "") NA else trimws(input$form_advocaat),
          adv_kantoor = if(is.null(input$form_adv_kantoor) || input$form_adv_kantoor == "" || trimws(input$form_adv_kantoor) == "") NA else trimws(input$form_adv_kantoor),
          la_budget_wjz = if(is.null(input$form_la_budget_wjz)) 0 else input$form_la_budget_wjz,
          budget_andere_directie = if(is.null(input$form_budget_andere_directie)) 0 else input$form_budget_andere_directie,
          financieel_risico = if(is.null(input$form_financieel_risico)) 0 else input$form_financieel_risico,
          
          # Nieuwe administratieve velden
          kostenplaats = if(is.null(input$form_kostenplaats) || input$form_kostenplaats == "") NA else input$form_kostenplaats,
          intern_ordernummer = if(is.null(input$form_intern_ordernummer) || input$form_intern_ordernummer == "") NA else input$form_intern_ordernummer,
          grootboekrekening = if(is.null(input$form_grootboekrekening) || input$form_grootboekrekening == "") NA else input$form_grootboekrekening,
          budgetcode = if(is.null(input$form_budgetcode) || input$form_budgetcode == "") NA else input$form_budgetcode,
          proza_link = if(is.null(input$form_proza_link) || input$form_proza_link == "") NA else input$form_proza_link,
          locatie_formulier = if(is.null(input$form_locatie_formulier) || input$form_locatie_formulier == "") NA else input$form_locatie_formulier,
          budget_beleid = if(is.null(input$form_budget_beleid) || input$form_budget_beleid == "") NA else input$form_budget_beleid,
          
          opmerkingen = if(is.null(input$form_opmerkingen) || input$form_opmerkingen == "") NA else input$form_opmerkingen,
          stringsAsFactors = FALSE
        )
        
        # Save to database using the new voeg_zaak_toe function with many-to-many support
        voeg_zaak_toe(form_data, current_user(), directies = selected_directies)
        
        cli_alert_success("New case created: {form_data$zaak_id}")
        show_notification(paste("Nieuwe zaak toegevoegd:", form_data$zaak_id), type = "message")
        
        # Trigger data refresh
        data_refresh_trigger(data_refresh_trigger() + 1)
        
        # Reset deadline cleared state
        new_deadline_cleared(FALSE)
        
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