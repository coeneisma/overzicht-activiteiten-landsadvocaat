# Directie Afkortingen Mapping Voorstel

## Excel Afkortingen → Database Waarden

| Excel Afkorting | Voorgestelde Database Waarde | Volledige Naam |
|----|----|----|
| **Basis Directies** |  |  |
| PO | onderwijspersoneelenprimaironderwijs | Onderwijspersoneel en Primair Onderwijs |
| VO | onderwijsprestatiesenvoortgezetonderwijs | Onderwijsprestaties en Voortgezet Onderwijs |
| BVE / MBO | middelbaarberoepsonderwijs | Middelbaar Beroepsonderwijs |
| HO&S / HOenS | hogeronderwijsenstudiefinanciering | Hoger Onderwijs en Studiefinanciering |
| DUO-G / DUO (G) | dienstuitvoeringonderwijs | Dienst Uitvoering Onderwijs |
| FEZ | financieeleconomischezaken | Financieel- Economische Zaken |
| WJZ | wetgevingenjuridischezaken | Wetgeving en Juridische Zaken |
| BOA | bestuursondersteuningenadvies | Bestuursondersteuning en Advies |
| MenC / communicatie | mediaencreatieveindustrie | Media en Creatieve Industrie |
| EK / EGI | erfgoedenkunsten | Erfgoed en Kunsten |
| Kennis | kennisstrategie | Kennis & Strategie |
| Onderwijsinspectie / IvhO | inspectievanhetonderwijs | Inspectie van het Onderwijs |
| **Mogelijk Nieuwe/Aangepaste** |  |  |
| DCE | *NIEUW?* - Directie Centrale Eenheid? | \- |
| DEK | *NIEUW?* - Directie Externe Kwaliteit? | \- |
| DK | *NIEUW?* - Directie Kwaliteit? | \- |
| DL | *NIEUW?* - Directie Leraren? | \- |
| DPO | *NIEUW?* - Directie Primair Onderwijs? | \- |
| FM | *NIEUW?* - Facilitair Management? | \- |
| MLB | *NIEUW?* - ? | \- |
| RCE | *NIEUW?* - Rijksdienst Cultureel Erfgoed? | \- |
| SG | *NIEUW?* - Secretaris-Generaal? | \- |
| **Combinaties/Specifiek** |  |  |
| PO/VO | onderwijspersoneelenprimaironderwijs | (Combinatie, gebruik PO als primair) |
| BVE en Onderwijsinspec | middelbaarberoepsonderwijs | (Combinatie, gebruik BVE als primair) |
| HO&S + PE CN | hogeronderwijsenstudiefinanciering | (Combinatie, gebruik HO&S als primair) |
| DCE/EGI | erfgoedenkunsten | (Combinatie, gebruik EGI als primair) |
| **Persoonsnamen** |  |  |
| PO/Bond | onderwijspersoneelenprimaironderwijs | (PO met persoonsnaam) |
| PO/Floor Dinant | onderwijspersoneelenprimaironderwijs | (PO met persoonsnaam) |
| PO/Poland-Oordt | onderwijspersoneelenprimaironderwijs | (PO met persoonsnaam) |
| VO/Peter van Putten | onderwijsprestatiesenvoortgezetonderwijs | (VO met persoonsnaam) |
| DK/Kooij | *NIEUW?* | (DK met persoonsnaam) |
| WJZ/Jan V | wetgevingenjuridischezaken | (WJZ met persoonsnaam) |
| **Speciale Gevallen** |  |  |
| Cie Amarantis/Lex de lange | *NIEUW?* | Commissie/externe partij? |
| Inspectie, VO | inspectievanhetonderwijs | Inspectie met VO specificatie |
| NA | NIET_INGESTELD | Niet beschikbaar |
| vo (lowercase) | onderwijsprestatiesenvoortgezetonderwijs | Zelfde als VO |

## Aanbevelingen

1.  **Nieuwe directies toevoegen** waar geen match bestaat
2.  **Combinaties** → gebruik primaire directie
3.  **Persoonsnamen** → negeer en gebruik directie afkorting
4.  **Case-insensitive** matching implementeren
5.  **Fallback** naar "NIET_INGESTELD" voor onbekende afkortingen
