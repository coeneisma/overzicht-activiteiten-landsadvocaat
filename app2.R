# Minimale Shiny App Test voor SelectInput Dropdown Layering
# ==========================================================

library(shiny)
library(bslib)
library(DT)

# UI
ui <- page_sidebar(
  title = "SelectInput Dropdown Test",
  theme = bs_theme(version = 5),
  
  sidebar = sidebar(
    width = 300,
    
    h4("Test Filters"),
    p("Test of selectInput dropdowns boven elkaar verschijnen"),
    
    # Filter 1: Cylinders
    selectInput(
      "cyl_filter",
      "Number of Cylinders:",
      choices = c("All" = "", sort(unique(mtcars$cyl))),
      selected = "",
      multiple = TRUE,
      width = "100%"
    ),
    
    # Filter 2: Gear  
    selectInput(
      "gear_filter", 
      "Number of Gears:",
      choices = c("All" = "", sort(unique(mtcars$gear))),
      selected = "",
      multiple = TRUE,
      width = "100%"
    ),
    
    # Filter 3: Transmission
    selectInput(
      "am_filter",
      "Transmission:",
      choices = c("All" = "", "Automatic" = "0", "Manual" = "1"),
      selected = "",
      multiple = TRUE,
      width = "100%"
    ),
    
    # Reset button
    br(),
    actionButton("reset_filters", "Reset Filters", class = "btn-secondary"),
    
    # Test instructions
    div(
      class = "mt-4 p-3 bg-light border rounded",
      h5("🧪 Test Instructies:"),
      tags$ol(
        tags$li("Klik op 'Number of Cylinders' dropdown"),
        tags$li("Check of dropdown VOOR 'Number of Gears' verschijnt"),
        tags$li("Test alle drie dropdowns"),
        tags$li("Probleem = dropdown verdwijnt achter volgende element")
      )
    )
  ),
  
  # Main content
  div(
    class = "p-4",
    
    h2("🚗 MTCars Dataset"),
    
    div(
      class = "row mb-3",
      div(
        class = "col-md-3",
        div(
          class = "card text-center",
          div(
            class = "card-body",
            h4(textOutput("total_cars"), class = "text-primary"),
            p("Total Cars", class = "mb-0")
          )
        )
      ),
      div(
        class = "col-md-3", 
        div(
          class = "card text-center",
          div(
            class = "card-body",
            h4(textOutput("filtered_cars"), class = "text-success"),
            p("Filtered Cars", class = "mb-0")
          )
        )
      )
    ),
    
    # Data table
    DTOutput("cars_table")
  )
)

# Server
server <- function(input, output, session) {
  
  # Reactive filtered data
  filtered_data <- reactive({
    data <- mtcars
    data$car_name <- rownames(data)
    data <- data[, c("car_name", names(data)[1:(ncol(data)-1)])]
    
    # Apply filters
    if (!is.null(input$cyl_filter) && length(input$cyl_filter) > 0 && input$cyl_filter != "") {
      data <- data[data$cyl %in% input$cyl_filter, ]
    }
    
    if (!is.null(input$gear_filter) && length(input$gear_filter) > 0 && input$gear_filter != "") {
      data <- data[data$gear %in% input$gear_filter, ]
    }
    
    if (!is.null(input$am_filter) && length(input$am_filter) > 0 && input$am_filter != "") {
      data <- data[data$am %in% input$am_filter, ]
    }
    
    return(data)
  })
  
  # Statistics
  output$total_cars <- renderText({
    nrow(mtcars)
  })
  
  output$filtered_cars <- renderText({
    nrow(filtered_data())
  })
  
  # Data table
  output$cars_table <- renderDT({
    datatable(
      filtered_data(),
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        autoWidth = TRUE
      ),
      rownames = FALSE
    )
  })
  
  # Reset filters
  observeEvent(input$reset_filters, {
    updateSelectInput(session, "cyl_filter", selected = "")
    updateSelectInput(session, "gear_filter", selected = "")
    updateSelectInput(session, "am_filter", selected = "")
  })
}

# Run app
shinyApp(ui = ui, server = server)