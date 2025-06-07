# test_dropdown_values.R
# ======================
# Test if dropdown values are correctly loaded from database

source("global.R")
source("utils/database.R")

cat("🔍 Testing Dropdown Values from Database\n")
cat("========================================\n\n")

# Test get_dropdown_opties function
cat("📋 Testing get_dropdown_opties() output:\n")
cat("---------------------------------------\n")

# Get choices for each category
categories <- c("type_dienst", "rechtsgebied", "status_zaak")

for (cat_name in categories) {
  cat(sprintf("\n🔹 Category: %s\n", cat_name))
  choices <- get_dropdown_opties(cat_name)
  
  if (length(choices) > 0) {
    cat("   Values (database):\n")
    for (i in 1:min(5, length(choices))) {
      cat(sprintf("   - Value: '%s' => Label: '%s'\n", choices[i], names(choices)[i]))
    }
    if (length(choices) > 5) {
      cat(sprintf("   ... and %d more\n", length(choices) - 5))
    }
  } else {
    cat("   ⚠️ NO VALUES FOUND!\n")
  }
}

# Check database directly
cat("\n\n📊 Checking Database Directly:\n")
cat("------------------------------\n")

con <- get_db_connection()
dropdown_data <- dbGetQuery(con, "
  SELECT categorie, waarde, weergave_naam, actief 
  FROM dropdown_opties 
  WHERE categorie IN ('type_dienst', 'rechtsgebied', 'status_zaak') 
    AND actief = 1
  ORDER BY categorie, volgorde
")
dbDisconnect(con)

if (nrow(dropdown_data) > 0) {
  cat(sprintf("Found %d active dropdown values\n\n", nrow(dropdown_data)))
  
  # Group by category
  for (cat_name in unique(dropdown_data$categorie)) {
    cat_data <- dropdown_data[dropdown_data$categorie == cat_name, ]
    cat(sprintf("🔸 %s: %d values\n", cat_name, nrow(cat_data)))
    for (i in 1:min(3, nrow(cat_data))) {
      cat(sprintf("   - '%s' => '%s'\n", cat_data$waarde[i], cat_data$weergave_naam[i]))
    }
    if (nrow(cat_data) > 3) {
      cat(sprintf("   ... and %d more\n", nrow(cat_data) - 3))
    }
  }
} else {
  cat("⚠️ NO DROPDOWN VALUES IN DATABASE!\n")
}

cat("\n\n💡 Expected Behavior:\n")
cat("--------------------\n")
cat("• pickerInput should show weergave_naam as labels\n")
cat("• Selected values should be database waarde values\n")
cat("• If no values show, check if actief = 1 in database\n")

cat("\n✅ Dropdown value test completed!\n")