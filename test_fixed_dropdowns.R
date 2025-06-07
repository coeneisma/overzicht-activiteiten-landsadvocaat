# test_fixed_dropdowns.R
# =======================
# Test the fixed dropdown loading and alphabetical sorting

source("global.R")

cat("🔧 Testing Fixed Dropdown Loading\n")
cat("=================================\n\n")

# Test all dropdown categories that use pickerInput
categories <- c("type_dienst", "rechtsgebied", "status_zaak")

for (cat_name in categories) {
  cat(sprintf("📋 Testing category: %s\n", cat_name))
  cat("--------------------------------\n")
  
  choices <- get_dropdown_opties(cat_name)
  
  if (length(choices) > 0) {
    cat(sprintf("✅ Found %d choices (alphabetically sorted):\n", length(choices)))
    for (i in 1:length(choices)) {
      cat(sprintf("   %d. '%s' => '%s'\n", i, names(choices)[i], choices[i]))
    }
    
    # Check for specific values
    if (cat_name == "status_zaak") {
      has_on_hold <- "On_hold" %in% choices
      has_testwaarde <- "testwaarde" %in% choices
      cat(sprintf("\n🔍 Specific checks:\n"))
      cat(sprintf("   - 'On hold' present: %s\n", ifelse(has_on_hold, "✅ YES", "❌ NO")))
      cat(sprintf("   - 'testwaarde' present: %s\n", ifelse(has_testwaarde, "✅ YES", "❌ NO")))
    }
  } else {
    cat("❌ NO CHOICES FOUND!\n")
  }
  cat("\n")
}

cat("💡 Expected Behavior in App:\n")
cat("----------------------------\n")
cat("• All values should appear in pickerInput dropdowns\n")
cat("• Values sorted alphabetically by display name\n")
cat("• 'On hold' should be visible in Status dropdown\n")
cat("• 'testwaarde' should be visible in Status dropdown\n")
cat("• Debug logging will show in console when app starts\n")

cat("\n🧪 To Test:\n")
cat("-----------\n")
cat("1. Start app: runApp()\n")
cat("2. Check console for debug messages\n")
cat("3. Open Status dropdown - should see all 5 options\n")
cat("4. Verify alphabetical order: Afgerond, In behandeling, Lopend, On hold, testwaarde\n")

cat("\n✅ Fixed dropdown test completed!\n")