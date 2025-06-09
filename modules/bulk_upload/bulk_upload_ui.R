# modules/bulk_upload/bulk_upload_ui.R
# ===================================

bulk_upload_ui <- function(id) {
  ns <- NS(id)
  
  div(
    class = "container-fluid",
    
    # Header 
    div(
      class = "d-flex justify-content-between align-items-center mb-4",
      h3("Bulk Upload Zaken", class = "mb-0")
    ),
    
    # Progress wizard (visual indicator) - will be updated dynamically
    div(
      class = "row mb-4",
      div(
        class = "col-12",
        card(
          card_body(
            uiOutput(ns("wizard_progress"))
          )
        )
      )
    ),
    
    # Main tabset for wizard steps
    div(
      class = "row",
      div(
        class = "col-12",
        
        tabsetPanel(
          id = ns("wizard_tabs"),
          type = "tabs",
          
          # Tab 1: Template Download
          tabPanel(
            title = div(icon("download"), " Sjabloon"),
            value = "tab_template",
            
            card(
              card_header("Stap 1: Download Excel Sjabloon"),
              card_body(
                div(
                  class = "row",
                  div(
                    class = "col-md-8",
                    h5("Instructies:"),
                    tags$ol(
                      tags$li("Download het Excel sjabloon met de knop rechtsboven"),
                      tags$li("Vul het sjabloon in met uw zaakgegevens"),
                      tags$li(strong("Verplichte velden:"), " Zaak ID en Datum Aanmaak"),
                      tags$li("Voor dropdown velden, gebruik de voorgestelde waarden uit het sjabloon"),
                      tags$li("Voor meerdere directies, scheid ze met komma's (bijv: \"DIR1, DIR2\")")
                    ),
                    
                    br(),
                    
                    div(
                      class = "alert alert-info",
                      icon("info-circle"),
                      " Het sjabloon bevat alle beschikbare dropdown waarden als validatie in Excel."
                    ),
                    
                    br(),
                    
                    div(
                      class = "d-grid gap-2 d-md-flex",
                      actionButton(
                        ns("btn_next_upload"),
                        "Naar Upload Stap",
                        class = "btn-success",
                        icon = icon("arrow-right")
                      )
                    )
                  ),
                  
                  div(
                    class = "col-md-4",
                    div(
                      class = "text-center p-4 border rounded bg-light",
                      icon("file-excel", class = "fa-3x text-success mb-3"),
                      br(),
                      
                      # Checkbox voor bestaande data opnemen
                      div(
                        class = "mb-3 text-center",
                        checkboxInput(
                          ns("include_existing_data"),
                          HTML('<i class="fas fa-database"></i> Huidige gefilterde zaken opnemen in sjabloon'),
                          value = FALSE
                        ),
                        uiOutput(ns("available_data_info")),
                        conditionalPanel(
                          condition = paste0("input['", ns("include_existing_data"), "']"),
                          div(
                            class = "alert alert-warning alert-sm mt-2",
                            style = "font-size: 0.85em; padding: 0.5rem;",
                            icon("exclamation-triangle", class = "fa-sm"),
                            " Alle zaken die momenteel zichtbaar zijn in Zaakbeheer worden toegevoegd aan het sjabloon."
                          )
                        )
                      ),
                      
                      downloadButton(
                        ns("download_template"), 
                        "Download Sjabloon", 
                        class = "btn-success btn-lg",
                        icon = icon("download")
                      ),
                      br(), br(),
                      span("Klik om het Excel sjabloon te downloaden", class = "text-muted small")
                    )
                  )
                )
              )
            )
          ),
          
          # Tab 2: File Upload
          tabPanel(
            title = div(icon("upload"), " Upload"),
            value = "tab_upload",
            
            card(
              card_header("Stap 2: Upload Excel Bestand"),
              card_body(
                div(
                  class = "row",
                  div(
                    class = "col-md-8",
                    
                    # Upload instructions (like step 1)
                    h5("Instructies:"),
                    tags$ol(
                      tags$li("Upload het ingevulde Excel sjabloon"),
                      tags$li("Zorg dat verplichte velden zijn ingevuld"),
                      tags$li("Maximale bestandsgrootte: 10MB")
                    ),
                    
                    br(),
                    
                    div(
                      class = "alert alert-info",
                      icon("info-circle"),
                      " Controleer de preview onderaan voordat u doorgaat naar de validatie stap."
                    ),
                    
                    br(),
                    
                    # Navigation buttons
                    div(
                      class = "d-grid gap-2 d-md-flex",
                      actionButton(
                        ns("btn_back_template"),
                        "Terug naar Sjabloon",
                        class = "btn-outline-secondary",
                        icon = icon("arrow-left")
                      ),
                      actionButton(
                        ns("btn_next_validation"),
                        "Naar Validatie",
                        class = "btn-success",
                        icon = icon("arrow-right"),
                        disabled = TRUE
                      )
                    )
                  ),
                  
                  div(
                    class = "col-md-4",
                    
                    # File upload area (like step 1 download area)
                    div(
                      class = "text-center p-4 border rounded bg-light",
                      icon("cloud-upload-alt", class = "fa-3x text-primary mb-3"),
                      br(),
                      
                      # File input with custom styling
                      fileInput(
                        ns("upload_file"),
                        label = NULL,
                        accept = c(".xlsx", ".xls"),
                        width = "100%",
                        buttonLabel = "Selecteer Excel bestand",
                        placeholder = "Geen bestand geselecteerd"
                      ),
                      
                      br(),
                      span("Sleep bestand hierheen of klik om te selecteren", class = "text-muted small"),
                      br(),
                      span("Ondersteunde formaten: .xlsx, .xls", class = "text-muted small")
                    )
                  )
                ),
                
                # Upload status (full width)
                conditionalPanel(
                  condition = paste0("output['", ns("upload_status"), "'] != ''"),
                  div(
                    class = "row mt-4",
                    div(
                      class = "col-12",
                      uiOutput(ns("upload_status"))
                    )
                  )
                ),
                
                # Preview section (full width)
                conditionalPanel(
                  condition = paste0("output['", ns("show_preview"), "'] == true"),
                  div(
                    class = "row mt-4",
                    div(
                      class = "col-12",
                      h5("Bestand Preview:"),
                      div(
                        class = "border rounded p-3 bg-light",
                        style = "max-height: 400px; overflow-y: auto;",
                        DT::dataTableOutput(ns("preview_table"))
                      )
                    )
                  )
                )
              )
            )
          ),
          
          # Tab 3: Data Validation
          tabPanel(
            title = div(icon("check-circle"), " Validatie"),
            value = "tab_validation",
            
            card(
              card_header("Stap 3: Data Validatie"),
              card_body(
                div(
                  class = "row",
                  div(
                    class = "col-md-8",
                    
                    # Validation instructions (like previous steps)
                    h5("Instructies:"),
                    tags$ol(
                      tags$li("Controleer alle dropdown waarden op correctheid"),
                      tags$li(HTML("<span style='color: #28a745;'><strong>Groene</strong></span> items zijn exact gematcht en correct")),
                      tags$li(HTML("<span style='color: #ffc107;'><strong>Gele</strong></span> items zijn suggesties - controleer en pas aan indien nodig")),
                      tags$li(HTML("<span style='color: #dc3545;'><strong>Rode</strong></span> items vereisen handmatige invoer")),
                      tags$li("Directies worden automatisch gesplitst op komma's")
                    ),
                    
                    br(),
                    
                    div(
                      class = "alert alert-info",
                      icon("info-circle"),
                      " Controleer de validatie resultaten onderaan voordat u doorgaat."
                    ),
                    
                    br(),
                    
                    # Navigation buttons
                    div(
                      class = "d-grid gap-2 d-md-flex",
                      actionButton(
                        ns("btn_back_upload"),
                        "Terug naar Upload",
                        class = "btn-outline-secondary",
                        icon = icon("arrow-left")
                      ),
                      actionButton(
                        ns("btn_next_corrections"),
                        "Naar Aanpassingen",
                        class = "btn-success",
                        icon = icon("arrow-right"),
                        disabled = TRUE
                      )
                    )
                  ),
                  
                  div(
                    class = "col-md-4",
                    
                    # Validation status area (like previous steps)
                    div(
                      class = "text-center p-4 border rounded bg-light",
                      icon("check-circle", class = "fa-3x text-success mb-3"),
                      br(),
                      
                      # Validation summary
                      div(
                        id = ns("validation_summary"),
                        uiOutput(ns("validation_status"))
                      ),
                      
                      br(),
                      span("Validatie wordt automatisch uitgevoerd", class = "text-muted small")
                    )
                  )
                ),
                
                # Validation results (full width)
                conditionalPanel(
                  condition = paste0("output['", ns("show_validation"), "'] == true"),
                  div(
                    class = "row mt-4",
                    div(
                      class = "col-12",
                      h5("Validatie Resultaten:"),
                      p("Overzicht van alle gevalideerde gegevens. Aanpassingen kunt u in de volgende stap maken.", class = "text-muted small"),
                      div(
                        class = "border rounded p-3 bg-light",
                        style = "max-height: 500px; overflow-y: auto;",
                        DT::dataTableOutput(ns("validation_table"))
                      )
                    )
                  )
                )
              )
            )
          ),
          
          # Tab 4: Corrections/Adjustments
          tabPanel(
            title = div(icon("edit"), " Aanpassingen"),
            value = "tab_corrections",
            
            card(
              card_header("Stap 4: Validatie Problemen Oplossen"),
              card_body(
                div(
                  class = "row",
                  div(
                    class = "col-md-8",
                    
                    # Corrections instructions
                    h5("Instructies:"),
                    tags$ol(
                      tags$li("Hieronder staan alle items die uw aandacht vereisen"),
                      tags$li("Kies per item de suggestie of een handmatige optie"),
                      tags$li(HTML("<span style='color: #ffc107;'><strong>Gele items</strong></span> hebben een goede suggestie")),
                      tags$li(HTML("<span style='color: #dc3545;'><strong>Rode items</strong></span> vereisen handmatige keuze")),
                      tags$li("Voor Aanvragende Directie kunt u meerdere opties kiezen"),
                      tags$li("Gebruik 'Accepteer alle suggesties' om sneller te werken")
                    ),
                    
                    br(),
                    
                    div(
                      class = "alert alert-info",
                      icon("info-circle"),
                      " Los alle problemen op voordat u naar de import gaat."
                    ),
                    
                    br(),
                    
                    # Navigation buttons
                    div(
                      class = "d-grid gap-2 d-md-flex",
                      actionButton(
                        ns("btn_back_validation"),
                        "Terug naar Validatie",
                        class = "btn-outline-secondary",
                        icon = icon("arrow-left")
                      ),
                      actionButton(
                        ns("btn_next_import"),
                        "Naar Import",
                        class = "btn-success",
                        icon = icon("arrow-right"),
                        disabled = TRUE
                      )
                    )
                  ),
                  
                  div(
                    class = "col-md-4",
                    
                    # Corrections status area
                    div(
                      class = "text-center p-4 border rounded bg-light",
                      icon("edit", class = "fa-3x text-warning mb-3"),
                      br(),
                      
                      # Corrections summary
                      div(
                        id = ns("corrections_summary"),
                        uiOutput(ns("corrections_status"))
                      )
                    )
                  )
                ),
                
                # Corrections list (full width)
                conditionalPanel(
                  condition = paste0("output['", ns("show_corrections"), "'] == true"),
                  div(
                    class = "row mt-4",
                    div(
                      class = "col-12",
                      h5("Problemen oplossen:"),
                      div(
                        class = "border rounded p-3 bg-light corrections-container",
                        style = "position: relative;",
                        uiOutput(ns("corrections_list"))
                      )
                    )
                  )
                )
              )
            )
          ),
          
          # Tab 5: Final Import
          tabPanel(
            title = div(icon("database"), " Import"),
            value = "tab_import",
            
            card(
              card_header("Stap 5: Import Uitvoeren"),
              card_body(
                div(
                  class = "row",
                  div(
                    class = "col-md-8",
                    
                    # Import instructions
                    h5("Instructies:"),
                    tags$ol(
                      tags$li("Controleer onderstaand overzicht van alle zaken die geïmporteerd worden"),
                      tags$li("Zaken met bestaande Zaak ID's worden bijgewerkt"),
                      tags$li("Nieuwe Zaak ID's worden toegevoegd aan de database"),
                      tags$li("Klik op 'Start Import' om de zaken definitief toe te voegen")
                    ),
                    
                    br(),
                    
                    div(
                      class = "alert alert-info",
                      icon("info-circle"),
                      " Deze actie kan niet ongedaan worden gemaakt. Controleer de gegevens goed."
                    ),
                    
                    br(),
                    
                    # Navigation buttons
                    div(
                      class = "d-grid gap-2 d-md-flex",
                      actionButton(
                        ns("btn_back_corrections"),
                        "Terug naar Aanpassingen",
                        class = "btn-outline-secondary",
                        icon = icon("arrow-left")
                      ),
                      actionButton(
                        ns("btn_start_import"),
                        "Start Import",
                        class = "btn-success btn-lg",
                        icon = icon("play"),
                        disabled = FALSE
                      )
                    )
                  ),
                  
                  div(
                    class = "col-md-4",
                    
                    # Import status area
                    div(
                      class = "text-center p-4 border rounded bg-light",
                      icon("database", class = "fa-3x text-success mb-3"),
                      br(),
                      
                      # Import summary
                      div(
                        id = ns("import_summary"),
                        uiOutput(ns("import_status"))
                      )
                    )
                  )
                ),
                
                # Import preview section (full width)
                div(
                  class = "row mt-4",
                  div(
                    class = "col-12",
                    h5("Import Overzicht:"),
                    p("Onderstaande zaken worden geïmporteerd met de gekozen correcties:", class = "text-muted small"),
                    div(
                      class = "border rounded p-3 bg-light",
                      style = "position: relative;",
                      uiOutput(ns("import_preview"))
                    )
                  )
                ),
                
                # Import results section (shown after import)
                conditionalPanel(
                  condition = paste0("output['", ns("show_results"), "'] == true"),
                  div(
                    class = "row mt-4",
                    div(
                      class = "col-12",
                      h5("Import Resultaten:"),
                      div(
                        class = "border rounded p-3",
                        uiOutput(ns("import_results"))
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
}