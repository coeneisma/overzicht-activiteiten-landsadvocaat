# Test script om een Excel bestand te maken voor bulk upload testing
library(writexl)

# Maak test data die typische problemen kan aantonen
test_data <- data.frame(
  "Zaak ID" = c("TEST-001", "TEST-002", "TEST-003"),
  "Datum Aanmaak" = c("15-01-2024", "01-02-2024", "45850"),  # Mix van formaten + Excel numeric
  "Deadline" = c("", "15-06-2024", "45900"),
  "Zaakaanduiding" = c("Test zaak 1 voor debug", "Test zaak 2", "Test zaak 3"),
  "Type Dienst" = c("Advies", "Advi", "Advies en vertegenwoordiging"),  # Exacte match, getrunceerd, volledige match
  "Rechtsgebied" = c("Arbeidsrecht", "Arbeids recht", "Bestuursrecht"),  # Met/zonder spatie
  "Status" = c("Lopend", "Afge", "Open"),  # Volledige, getrunceerd, andere waarde
  "Aanvragende Directie" = c("Financieel-Economische Zaken", "FEZ, HO", "Hoger Onderwijs, Wetenschapsbeleid"),  # Mix formaten
  "Advocaat" = c("Test Advocaat 1", "Test Advocaat 2", ""),
  "Advocatenkantoor" = c("Test Kantoor A", "", "Test Kantoor B"),
  "Budget WJZ (€)" = c("50000", "25000", ""),
  "Budget Andere Directie (€)" = c("", "10000", "15000"),
  "Financieel Risico (€)" = c("100000", "", "75000"),
  "Opmerkingen" = c("Test opmerking 1", "", "Test opmerking 3"),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# Schrijf naar Excel bestand
writexl::write_xlsx(test_data, "test_bulk_upload.xlsx")

cat("Test Excel bestand gemaakt: test_bulk_upload.xlsx\n")
cat("Bevat 3 test zaken met verschillende data problemen voor debugging\n")