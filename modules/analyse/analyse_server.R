# modules/analyse/analyse_server.R
# ======================================

#' Analyse Module Server
#' 
#' Handles analysis calculations, filtering, and chart generation
#' 
#' @param id Module namespace ID
#' @param filtered_data Reactive containing filtered case data from filter module
#' @param raw_data Reactive containing all case data
#' @param data_refresh_trigger Reactive value to trigger data refresh
#' @param current_user Reactive containing current username
#' @param main_navbar_input Reactive value with current active navbar tab for lazy loading
#' @param global_dropdown_refresh_trigger Reactive trigger for dropdown changes
#' @return List with reactive values and functions
analyse_server <- function(id, filtered_data, raw_data, data_refresh_trigger, current_user, main_navbar_input = reactive(""), global_dropdown_refresh_trigger = NULL) {
  
  moduleServer(id, function(input, output, session) {
    
    # ========================================================================
    # REACTIVE VALUES & DROPDOWN CHOICES
    # ========================================================================
    
    # Clear dropdown cache when settings change for real-time updates  
    observeEvent(global_dropdown_refresh_trigger(), {
      if (!is.null(global_dropdown_refresh_trigger)) {
        # Clear the dropdown cache to force fresh display names in analysis
        clear_dropdown_cache()
        cli_alert_info("Dropdown cache cleared due to settings change - analyse module will show updated display names")
        
        # Update dropdown choices when settings change
        update_analyse_dropdown_choices()
      }
    }, ignoreInit = TRUE)
    
    # Function to update analyse dropdown choices
    update_analyse_dropdown_choices <- function() {
      # Get available dropdown categories from database
      con <- get_db_connection()
      on.exit(close_db_connection(con))
      
      # Get categories with readable names
      category_choices <- list(
        "Type Dienst" = "type_dienst",
        "Rechtsgebied" = "rechtsgebied",
        "Status" = "status_zaak",
        "Aanvragende Directie" = "aanvragende_directie",
        "Type Procedure" = "type_procedure",
        "Hoedanigheid Partij" = "hoedanigheid_partij",
        "Type Wederpartij" = "type_wederpartij",
        "Reden Inzet" = "reden_inzet",
        "Aansprakelijkheid" = "aansprakelijkheid"
      )
      
      updateSelectInput(
        session,
        "analyse_split_var",
        choices = category_choices,
        selected = "type_dienst"
      )
    }
    
    # Initialize dropdown choices on module load
    observe({
      # Only load when analyse tab is active (lazy loading)
      req(main_navbar_input() == "tab_analyse")
      update_analyse_dropdown_choices()
    })
    
    # Data is already filtered by the filter module, just ensure deleted cases are excluded
    # Add debouncing + lazy loading for better performance + react to dropdown changes
    analysis_data <- reactive({
      # Only load data when analyse tab is active (lazy loading)
      req(main_navbar_input() == "tab_analyse")
      
      # React to dropdown changes to refresh display names
      if (!is.null(global_dropdown_refresh_trigger)) {
        global_dropdown_refresh_trigger()
      }
      
      data <- filtered_data()
      
      if (is.null(data) || nrow(data) == 0) return(data)
      
      # Exclude deleted cases (if not already done by filter module)
      data %>%
        filter(is.na(status_zaak) | status_zaak != "Verwijderd")
    }) %>% debounce(300)
    
    # ========================================================================
    # LOOPTIJD BEREKENINGEN
    # ========================================================================
    
    # Calculate case durations with optimized bulk conversions
    looptijd_data <- reactive({
      data <- analysis_data()
      
      if (is.null(data) || nrow(data) == 0) return(NULL)
      
      # Bulk convert database values to display names for better performance
      type_dienst_names <- bulk_get_weergave_namen("type_dienst", data$type_dienst)
      rechtsgebied_names <- bulk_get_weergave_namen("rechtsgebied", data$rechtsgebied)
      status_zaak_names <- bulk_get_weergave_namen("status_zaak", data$status_zaak)
      reden_inzet_names <- bulk_get_weergave_namen("reden_inzet", data$reden_inzet)
      
      data %>%
        mutate(
          # Calculate duration in days
          looptijd_dagen = as.numeric(Sys.Date() - as.Date(datum_aanmaak)),
          
          # Use pre-computed display names (much faster than individual sapply calls)
          type_dienst_display = ifelse(is.na(type_dienst), "Onbekend", type_dienst_names),
          rechtsgebied_display = ifelse(is.na(rechtsgebied), "Onbekend", rechtsgebied_names),
          status_zaak_display = ifelse(is.na(status_zaak), "Onbekend", status_zaak_names),
          reden_inzet_display = ifelse(is.na(reden_inzet), "Onbekend", reden_inzet_names),
          aanvragende_directie_display = ifelse(is.na(directies) | directies == "" | directies == "Niet ingesteld", "Onbekend", directies),
          adv_kantoor_display = ifelse(is.na(adv_kantoor) | adv_kantoor == "", "Onbekend", adv_kantoor)
        ) %>%
        filter(!is.na(looptijd_dagen) & looptijd_dagen >= 0)
    })
    
    # ========================================================================
    # KPI CALCULATIONS
    # ========================================================================
    
    # Total cases KPI
    output$kpi_total_cases <- renderText({
      data <- analysis_data()
      if (is.null(data)) return("0")
      format(nrow(data), big.mark = " ")
    })
    
    output$kpi_total_subtitle <- renderText({
      data <- analysis_data()
      raw <- raw_data()
      if (is.null(data) || is.null(raw)) return("")
      
      percentage <- round((nrow(data) / nrow(raw)) * 100, 1)
      paste0("(", percentage, "% van totaal)")
    })
    
    # Average duration KPI
    output$kpi_avg_duration <- renderText({
      data <- looptijd_data()
      if (is.null(data) || nrow(data) == 0) return("0")
      
      avg_duration <- round(mean(data$looptijd_dagen, na.rm = TRUE), 0)
      format(avg_duration, big.mark = " ")
    })
    
    # Lopende cases KPI
    output$kpi_open_cases <- renderText({
      data <- analysis_data()
      if (is.null(data)) return("0")
      
      open_count <- sum(data$status_zaak == "Lopend", na.rm = TRUE)
      format(open_count, big.mark = " ")
    })
    
    output$kpi_open_percentage <- renderText({
      data <- analysis_data()
      if (is.null(data) || nrow(data) == 0) return("(0%)")
      
      open_count <- sum(data$status_zaak == "Lopend", na.rm = TRUE)
      percentage <- round((open_count / nrow(data)) * 100, 1)
      paste0("(", percentage, "%)")
    })
    
    # Total risk KPI
    output$kpi_total_risk <- renderText({
      data <- analysis_data()
      if (is.null(data)) return("€ 0")
      
      total_risk <- sum(as.numeric(data$financieel_risico), na.rm = TRUE)
      format_currency(total_risk)
    })
    
    # ========================================================================
    # LOOPTIJD VISUALISATIE
    # ========================================================================
    
    output$looptijd_plot <- renderPlotly({
      data <- looptijd_data()
      split_var <- input$analyse_split_var
      
      if (is.null(data) || nrow(data) == 0 || is.null(split_var)) {
        # Empty plot
        p <- ggplot() + 
          geom_text(aes(x = 1, y = 1, label = "Geen data beschikbaar"), size = 5) +
          theme_void() +
          theme(panel.background = element_rect(fill = "white"))
        return(ggplotly(p))
      }
      
      # Get display column name
      display_col <- paste0(split_var, "_display")
      if (!display_col %in% names(data)) {
        display_col <- split_var
      }
      
      # Create summary data
      summary_data <- data %>%
        group_by(categorie = !!sym(display_col)) %>%
        summarise(
          gem_looptijd = round(mean(looptijd_dagen, na.rm = TRUE), 1),
          aantal_zaken = n(),
          mediaan = round(median(looptijd_dagen, na.rm = TRUE), 1),
          .groups = "drop"
        ) %>%
        arrange(desc(gem_looptijd))
      
      # Create bar plot with custom tooltip
      p <- ggplot(summary_data, aes(x = reorder(categorie, gem_looptijd), y = gem_looptijd,
                                    # Custom tooltip text
                                    text = paste("Categorie:", categorie,
                                                 "<br>Gem. looptijd:", gem_looptijd, "dagen",
                                                 "<br>Aantal zaken:", aantal_zaken,
                                                 "<br>Mediaan:", mediaan, "dagen"))) +
        geom_col(fill = "#154273", alpha = 0.8) +
        geom_text(aes(label = paste0(gem_looptijd, " dagen\n(", aantal_zaken, " zaken)")), 
                  hjust = -0.1, size = 3) +
        coord_flip() +
        labs(
          title = "Gemiddelde Looptijd per Categorie",
          x = "",
          y = "Gemiddelde looptijd (dagen)"
        ) +
        theme_minimal() +
        theme(
          plot.title = element_text(size = 14, face = "bold"),
          axis.text = element_text(size = 10),
          panel.grid.minor = element_blank()
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(showlegend = FALSE)
    })
    
    # ========================================================================
    # VERDELING VISUALISATIE
    # ========================================================================
    
    output$verdeling_plot <- renderPlotly({
      data <- analysis_data()
      split_var <- input$analyse_split_var
      
      if (is.null(data) || nrow(data) == 0 || is.null(split_var)) {
        # Empty plot
        p <- ggplot() + 
          geom_text(aes(x = 1, y = 1, label = "Geen data beschikbaar"), size = 5) +
          theme_void() +
          theme(panel.background = element_rect(fill = "white"))
        return(ggplotly(p))
      }
      
      # Convert database values to display names using bulk operations for better performance
      data_with_display <- data %>%
        mutate(
          categorie_display = case_when(
            split_var == "type_dienst" ~ {
              names <- bulk_get_weergave_namen("type_dienst", type_dienst)
              ifelse(is.na(type_dienst), "Onbekend", names)
            },
            split_var == "rechtsgebied" ~ {
              names <- bulk_get_weergave_namen("rechtsgebied", rechtsgebied)
              ifelse(is.na(rechtsgebied), "Onbekend", names)
            },
            split_var == "status_zaak" ~ {
              names <- bulk_get_weergave_namen("status_zaak", status_zaak)
              ifelse(is.na(status_zaak), "Onbekend", names)
            },
            split_var == "aanvragende_directie" ~ ifelse(is.na(directies) | directies == "" | directies == "Niet ingesteld", "Onbekend", directies),
            split_var == "type_wederpartij" ~ {
              names <- bulk_get_weergave_namen("type_wederpartij", type_wederpartij)
              ifelse(is.na(type_wederpartij), "Onbekend", names)
            },
            split_var == "hoedanigheid_partij" ~ {
              names <- bulk_get_weergave_namen("hoedanigheid_partij", hoedanigheid_partij)
              ifelse(is.na(hoedanigheid_partij), "Onbekend", names)
            },
            split_var == "reden_inzet" ~ {
              names <- bulk_get_weergave_namen("reden_inzet", reden_inzet)
              ifelse(is.na(reden_inzet), "Onbekend", names)
            },
            split_var == "type_procedure" ~ {
              names <- bulk_get_weergave_namen("type_procedure", type_procedure)
              ifelse(is.na(type_procedure), "Onbekend", names)
            },
            split_var == "aansprakelijkheid" ~ {
              names <- bulk_get_weergave_namen("aansprakelijkheid", aansprakelijkheid)
              ifelse(is.na(aansprakelijkheid), "Onbekend", names)
            },
            TRUE ~ as.character(!!sym(split_var))
          )
        )
      
      # Create summary data
      summary_data <- data_with_display %>%
        count(categorie_display, name = "aantal") %>%
        mutate(
          percentage = round((aantal / sum(aantal)) * 100, 1),
          label = paste0(categorie_display, "\n", aantal, " (", percentage, "%)")
        ) %>%
        arrange(desc(aantal))
      
      # Create pie chart
      p <- plot_ly(
        summary_data,
        labels = ~categorie_display,
        values = ~aantal,
        type = "pie",
        textinfo = "label+percent",
        textposition = "outside",
        hovertemplate = "<b>%{label}</b><br>Aantal: %{value}<br>Percentage: %{percent}<extra></extra>",
        marker = list(
          colors = RColorBrewer::brewer.pal(min(nrow(summary_data), 11), "Spectral"),
          line = list(color = "white", width = 2)
        )
      ) %>%
        layout(
          title = list(text = "Verdeling van Zaken", font = list(size = 16)),
          showlegend = FALSE
        )
      
      return(p)
    })
    
    # ========================================================================
    # DETAIL TABLES
    # ========================================================================
    
    # Looptijd detail table
    output$looptijd_table <- DT::renderDataTable({
      data <- looptijd_data()
      split_var <- input$analyse_split_var
      
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen data beschikbaar"),
          options = list(searching = FALSE, paging = FALSE, info = FALSE),
          rownames = FALSE
        ))
      }
      
      # Get display column
      display_col <- paste0(split_var, "_display")
      if (!display_col %in% names(data)) display_col <- split_var
      
      # Create summary table
      summary_table <- data %>%
        group_by(Categorie = !!sym(display_col)) %>%
        summarise(
          `Aantal Zaken` = n(),
          `Gem. Looptijd (dagen)` = round(mean(looptijd_dagen, na.rm = TRUE), 1),
          `Mediaan (dagen)` = round(median(looptijd_dagen, na.rm = TRUE), 1),
          `Min (dagen)` = round(min(looptijd_dagen, na.rm = TRUE), 1),
          `Max (dagen)` = round(max(looptijd_dagen, na.rm = TRUE), 1),
          .groups = "drop"
        ) %>%
        arrange(desc(`Gem. Looptijd (dagen)`))
      
      DT::datatable(
        summary_table,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ items"
          )
        ),
        rownames = FALSE
      )
    })
    
    # Verdeling detail table
    output$verdeling_table <- DT::renderDataTable({
      data <- analysis_data()
      split_var <- input$analyse_split_var
      
      if (is.null(data) || nrow(data) == 0) {
        return(DT::datatable(
          data.frame("Bericht" = "Geen data beschikbaar"),
          options = list(searching = FALSE, paging = FALSE, info = FALSE),
          rownames = FALSE
        ))
      }
      
      # Convert values to display names using bulk operations
      data_with_display <- data %>%
        mutate(
          categorie_display = case_when(
            split_var == "type_dienst" ~ {
              names <- bulk_get_weergave_namen("type_dienst", type_dienst)
              ifelse(is.na(type_dienst), "Onbekend", names)
            },
            split_var == "rechtsgebied" ~ {
              names <- bulk_get_weergave_namen("rechtsgebied", rechtsgebied)
              ifelse(is.na(rechtsgebied), "Onbekend", names)
            },
            split_var == "status_zaak" ~ {
              names <- bulk_get_weergave_namen("status_zaak", status_zaak)
              ifelse(is.na(status_zaak), "Onbekend", names)
            },
            split_var == "aanvragende_directie" ~ ifelse(is.na(directies) | directies == "" | directies == "Niet ingesteld", "Onbekend", directies),
            split_var == "type_wederpartij" ~ {
              names <- bulk_get_weergave_namen("type_wederpartij", type_wederpartij)
              ifelse(is.na(type_wederpartij), "Onbekend", names)
            },
            split_var == "hoedanigheid_partij" ~ {
              names <- bulk_get_weergave_namen("hoedanigheid_partij", hoedanigheid_partij)
              ifelse(is.na(hoedanigheid_partij), "Onbekend", names)
            },
            split_var == "reden_inzet" ~ {
              names <- bulk_get_weergave_namen("reden_inzet", reden_inzet)
              ifelse(is.na(reden_inzet), "Onbekend", names)
            },
            split_var == "type_procedure" ~ {
              names <- bulk_get_weergave_namen("type_procedure", type_procedure)
              ifelse(is.na(type_procedure), "Onbekend", names)
            },
            split_var == "aansprakelijkheid" ~ {
              names <- bulk_get_weergave_namen("aansprakelijkheid", aansprakelijkheid)
              ifelse(is.na(aansprakelijkheid), "Onbekend", names)
            },
            TRUE ~ as.character(!!sym(split_var))
          )
        )
      
      # Create summary table
      summary_table <- data_with_display %>%
        count(categorie_display, name = "Aantal") %>%
        mutate(
          Percentage = round((Aantal / sum(Aantal)) * 100, 1)
        ) %>%
        arrange(desc(Aantal)) %>%
        rename(Categorie = categorie_display)
      
      DT::datatable(
        summary_table,
        options = list(
          pageLength = 15,
          scrollX = TRUE,
          language = list(
            search = "Zoeken:",
            lengthMenu = "Toon _MENU_ items per pagina",
            info = "Toont _START_ tot _END_ van _TOTAL_ items"
          )
        ),
        rownames = FALSE
      ) %>%
        DT::formatStyle("Percentage", backgroundColor = DT::styleInterval(c(10, 20, 30), c("#f8f9fa", "#e9ecef", "#dee2e6", "#ced4da")))
    })
    
    # ========================================================================
    # EVENT HANDLERS
    # ========================================================================
    
    # Refresh data
    observeEvent(input$btn_refresh, {
      data_refresh_trigger(data_refresh_trigger() + 1)
      show_notification("Analyse data ververst", type = "message")
    })
    
    # Excel export with multiple tabs
    output$download_excel <- downloadHandler(
      filename = function() {
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        paste0("Analyse_Export_", timestamp, ".xlsx")
      },
      content = function(file) {
        cli_alert_info("Analyse Excel export requested by user: {current_user()}")
        
        tryCatch({
          # Get current data
          data <- analysis_data()
          looptijd_data_export <- looptijd_data()
          
          if (is.null(data) || nrow(data) == 0) {
            # Create empty file with message
            empty_data <- data.frame("Bericht" = "Geen data beschikbaar om te exporteren")
            writexl::write_xlsx(list("Bericht" = empty_data), path = file)
            return()
          }
          
          # =====================================================================
          # TAB 1: KPI OVERZICHT
          # =====================================================================
          
          kpi_data <- data.frame(
            KPI = c(
              "Totaal Aantal Zaken",
              "Percentage van Totaal",
              "Gemiddelde Looptijd (dagen)",
              "Aantal Open Zaken", 
              "Percentage Open Zaken",
              "Totaal Financieel Risico (€)"
            ),
            Waarde = c(
              format(nrow(data), big.mark = " "),
              paste0(round((nrow(data) / nrow(raw_data())) * 100, 1), "%"),
              if(is.null(looptijd_data_export) || nrow(looptijd_data_export) == 0) "0" else format(round(mean(looptijd_data_export$looptijd_dagen, na.rm = TRUE), 0), big.mark = " "),
              format(sum(data$status_zaak == "Lopend", na.rm = TRUE), big.mark = " "),
              paste0(round((sum(data$status_zaak == "Lopend", na.rm = TRUE) / nrow(data)) * 100, 1), "%"),
              format_currency(sum(as.numeric(data$financieel_risico), na.rm = TRUE))
            ),
            Datum_Export = format(Sys.time(), "%d-%m-%Y %H:%M:%S"),
            stringsAsFactors = FALSE
          )
          
          # =====================================================================
          # TAB 2: LOOPTIJD ANALYSE DATA
          # =====================================================================
          
          if (!is.null(looptijd_data_export) && nrow(looptijd_data_export) > 0) {
            
            # Get current split variable from shared analyse dropdown
            split_var <- if(is.null(input$analyse_split_var)) "type_dienst" else input$analyse_split_var
            display_col <- paste0(split_var, "_display")
            
            if (!display_col %in% names(looptijd_data_export)) {
              display_col <- split_var
            }
            
            looptijd_summary <- looptijd_data_export %>%
              group_by(Categorie = !!sym(display_col)) %>%
              summarise(
                `Aantal Zaken` = n(),
                `Gemiddelde Looptijd (dagen)` = round(mean(looptijd_dagen, na.rm = TRUE), 1),
                `Mediaan Looptijd (dagen)` = round(median(looptijd_dagen, na.rm = TRUE), 1),
                `Minimum Looptijd (dagen)` = round(min(looptijd_dagen, na.rm = TRUE), 1),
                `Maximum Looptijd (dagen)` = round(max(looptijd_dagen, na.rm = TRUE), 1),
                `Standaarddeviatie (dagen)` = round(sd(looptijd_dagen, na.rm = TRUE), 1),
                .groups = "drop"
              ) %>%
              arrange(desc(`Gemiddelde Looptijd (dagen)`))
            
          } else {
            looptijd_summary <- data.frame("Bericht" = "Geen looptijd data beschikbaar")
          }
          
          # =====================================================================
          # TAB 3: VERDELING ANALYSE DATA  
          # =====================================================================
          
          # Get current split variable from shared analyse dropdown
          verdeling_split_var <- if(is.null(input$analyse_split_var)) "type_dienst" else input$analyse_split_var
          
          # Convert database values to display names using bulk operations
          data_with_display <- data %>%
            mutate(
              categorie_display = case_when(
                verdeling_split_var == "type_dienst" ~ {
                  names <- bulk_get_weergave_namen("type_dienst", type_dienst)
                  ifelse(is.na(type_dienst), "Onbekend", names)
                },
                verdeling_split_var == "rechtsgebied" ~ {
                  names <- bulk_get_weergave_namen("rechtsgebied", rechtsgebied)
                  ifelse(is.na(rechtsgebied), "Onbekend", names)
                },
                verdeling_split_var == "status_zaak" ~ {
                  names <- bulk_get_weergave_namen("status_zaak", status_zaak)
                  ifelse(is.na(status_zaak), "Onbekend", names)
                },
                verdeling_split_var == "aanvragende_directie" ~ ifelse(is.na(directies) | directies == "" | directies == "Niet ingesteld", "Onbekend", directies),
                verdeling_split_var == "type_wederpartij" ~ {
                  names <- bulk_get_weergave_namen("type_wederpartij", type_wederpartij)
                  ifelse(is.na(type_wederpartij), "Onbekend", names)
                },
                verdeling_split_var == "hoedanigheid_partij" ~ {
                  names <- bulk_get_weergave_namen("hoedanigheid_partij", hoedanigheid_partij)
                  ifelse(is.na(hoedanigheid_partij), "Onbekend", names)
                },
                verdeling_split_var == "reden_inzet" ~ {
                  names <- bulk_get_weergave_namen("reden_inzet", reden_inzet)
                  ifelse(is.na(reden_inzet), "Onbekend", names)
                },
                verdeling_split_var == "type_procedure" ~ {
                  names <- bulk_get_weergave_namen("type_procedure", type_procedure)
                  ifelse(is.na(type_procedure), "Onbekend", names)
                },
                verdeling_split_var == "aansprakelijkheid" ~ {
                  names <- bulk_get_weergave_namen("aansprakelijkheid", aansprakelijkheid)
                  ifelse(is.na(aansprakelijkheid), "Onbekend", names)
                },
                TRUE ~ as.character(!!sym(verdeling_split_var))
              )
            )
          
          verdeling_summary <- data_with_display %>%
            count(categorie_display, name = "Aantal") %>%
            mutate(
              Percentage = round((Aantal / sum(Aantal)) * 100, 1)
            ) %>%
            arrange(desc(Aantal)) %>%
            rename(Categorie = categorie_display)
          
          # =====================================================================
          # TAB 4: RUWE GEFILTERDE DATA
          # =====================================================================
          
          # Prepare clean export data with bulk conversions
          # Pre-compute all display names for better performance
          type_dienst_export <- bulk_get_weergave_namen("type_dienst", data$type_dienst)
          rechtsgebied_export <- bulk_get_weergave_namen("rechtsgebied", data$rechtsgebied)
          status_export <- bulk_get_weergave_namen("status_zaak", data$status_zaak)
          
          ruwe_data <- data %>%
            select(
              "Zaak ID" = zaak_id,
              "Datum Aanmaak" = datum_aanmaak,
              "Zaakaanduiding" = zaakaanduiding,
              "Type Dienst" = type_dienst,
              "Rechtsgebied" = rechtsgebied,
              "Status" = status_zaak,
              "Aanvragende Directie" = directies,
              "Advocaat" = advocaat,
              "Advocatenkantoor" = adv_kantoor,
              "Budget WJZ (€)" = la_budget_wjz,
              "Budget Andere Directie (€)" = budget_andere_directie,
              "Financieel Risico (€)" = financieel_risico,
              "Opmerkingen" = opmerkingen
            ) %>%
            mutate(
              # Format dates
              `Datum Aanmaak` = format_date_nl(`Datum Aanmaak`),
              
              # Use pre-computed display names (much faster than individual sapply calls)
              `Type Dienst` = ifelse(is.na(`Type Dienst`), "", type_dienst_export),
              Rechtsgebied = ifelse(is.na(Rechtsgebied), "", rechtsgebied_export),
              Status = ifelse(is.na(Status), "", status_export),
              `Aanvragende Directie` = ifelse(is.na(`Aanvragende Directie`) | `Aanvragende Directie` == "" | `Aanvragende Directie` == "Niet ingesteld", "", `Aanvragende Directie`),
              
              # Clean up fields
              Advocaat = ifelse(is.na(Advocaat), "", Advocaat),
              Advocatenkantoor = ifelse(is.na(Advocatenkantoor), "", Advocatenkantoor),
              Opmerkingen = ifelse(is.na(Opmerkingen), "", Opmerkingen),
              
              # Format currency as numbers for Excel
              `Budget WJZ (€)` = ifelse(is.na(`Budget WJZ (€)`) | `Budget WJZ (€)` == 0, 0, as.numeric(`Budget WJZ (€)`)),
              `Budget Andere Directie (€)` = ifelse(is.na(`Budget Andere Directie (€)`) | `Budget Andere Directie (€)` == 0, 0, as.numeric(`Budget Andere Directie (€)`)),
              `Financieel Risico (€)` = ifelse(is.na(`Financieel Risico (€)`) | `Financieel Risico (€)` == 0, 0, as.numeric(`Financieel Risico (€)`))
            )
          
          # =====================================================================
          # WRITE EXCEL FILE WITH MULTIPLE TABS
          # =====================================================================
          
          excel_data <- list(
            "KPI Overzicht" = kpi_data,
            "Looptijd Analyse" = looptijd_summary,
            "Verdeling Analyse" = verdeling_summary,
            "Gefilterde Data" = ruwe_data
          )
          
          writexl::write_xlsx(
            excel_data,
            path = file,
            col_names = TRUE,
            format_headers = TRUE
          )
          
          cli_alert_success("Analyse Excel export created with {length(excel_data)} tabs ({nrow(data)} zaken)")
          
        }, error = function(e) {
          cli_alert_danger("Error generating analyse Excel export: {e$message}")
          # Create error file
          error_data <- data.frame("Fout" = paste("Er is een fout opgetreden bij het exporteren:", e$message))
          writexl::write_xlsx(list("Fout" = error_data), path = file)
        })
      },
      contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
    
    # ========================================================================
    # RETURN VALUES
    # ========================================================================
    
    return(list(
      get_analysis_data = reactive({ analysis_data() }),
      refresh_analysis = function() {
        data_refresh_trigger(data_refresh_trigger() + 1)
      }
    ))
  })
}