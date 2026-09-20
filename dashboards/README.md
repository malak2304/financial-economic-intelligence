# 📊 Macroeconomic Intelligence & FinTech Strategy Cockpit 

## 🏗️ Architecture & Data Lineage
This Power BI reporting tier directly consumes analytics-ready marts modeled in **PostgreSQL** via **dbt (data build tool)**:

---

## 📑 Cockpit Navigation & Page Breakdown

### 1️⃣ Page 1: Macroeconomic Intelligence & FinTech Cockpit (Executive Overview)
* **Target Audience:** C-Suite, Chief Risk Officers (CRO), Chief Investment Officers (CIO).
* **Core Functionality:** Provides a single-pane-of-glass overview of systemic monetary tightening, yield spreads, and cross-border banking depth.
* **Key Visuals & Metrics:**
  * **KPI Scorecards:** Latest US Fed Policy Rate (3.63%), US Inflation YoY (3.35%), 10Y-Fed Spread (1.05%), Egypt Credit Penetration (27.57%).
  * **US Tightening Cycle (Line Chart):** Historical trajectory comparing Effective Federal Funds Rate vs. Consumer Price Index YoY across 2000–2024.
  * **Advanced vs. Emerging Growth Engines (Scatter/Bubble Chart):** Evaluates credit depth (Private Credit as % of GDP) against annual inflation rates, sized by remittance significance.
  * **Strategic State Indicator Badges:** Real-time visual flags summarizing policy regime (Restrictive), emerging market opportunity (High), and yield curve status.

---

### 2️⃣ Page 2: US Monetary Policy Transmission & Yield Curve Trajectory
* **Target Audience:** Head of Credit Risk, ALM (Asset-Liability Management) Desks, Underwriting Teams.
* **Core Functionality:** Unpacks the historical relationship between short-term benchmark rates, long-term sovereign bond yields, and consumer price cycles.
* **Key Visuals & Metrics:**
  * **KPI Scorecards:** Fed Funds Rate, 10Y Treasury Yield, Yield Curve Spread, Long-term Inversion Incident Ratio.
  * **Treasury Yield Curve & Fed Funds Dynamics (Multi-Line Chart):** Highlights inversion regimes ($10Y - FedFunds < 0$) signaling recession risks.
  * **Lead-Lag Cross-Correlation Analysis:** Visually verifies the empirical 9-to-12-month lag between monetary tightening and maximum inflation cooling.
  * **Actionable Playbook Panel:** Rules for adjusting Debt-to-Income (DTI) thresholds and credit limits during restrictive monetary cycles.

---

### 3️⃣ Page 3: Monetary Velocity, Liquidity & Statistical Shocks
* **Target Audience:** Quantitative Economists, Liquidity Managers, Treasury Officers.
* **Core Functionality:** Analyzes the expansion and contraction of the $M_2$ Money Supply, outlier inflation shocks, and structural distribution shifts.
* **Key Visuals & Metrics:**
  * **$M_2$ vs. CPI Expansion Tracks (Dual-Axis Chart):** Pinpoints the 12–18 month lead time from pandemic liquidity injections to the historical 8.98% inflation peak.
  * **Distribution & Outlier Analysis:** Validates right-skewed rate distributions and extreme labor market outlier behavior ($3.40\%$ min to $14.80\%$ max unemployment).
  * **Strategic Playbook Panel:** Capital cost management, deposit attrition mitigation, and ALM duration rebalancing.

---

### 4️⃣ Page 4: Global Macro Divergence & Cross-Border FinTech Strategy
* **Target Audience:** Chief Strategy Officer (CSO), Head of Global Expansion, Product Leads.
* **Core Functionality:** Contrasts developed Western financial systems against emerging Middle East and North Africa (MENA) economies to identify high-margin FinTech opportunities.
* **Key Visuals & Metrics:**
  * **Banking Depth Disparity (Horizontal Bar Chart):** Compares private credit penetration:
    * **United States:** ~195.88% (Deeply saturated credit market).
    * **United Kingdom:** ~143%.
    * **United Arab Emirates:** ~77%.
    * **Saudi Arabia:** ~38%.
    * **Egypt:** **27.57%** (Massive underserved credit vacuum).
  * **Egypt Macro Stability & Remittance Bulwark (Line & Stacked Column Combined Chart):** Tracks Egyptian foreign remittances as a % of GDP (peaking at ~9.96%, stabilizing at ~7.60%) coupled with domestic real GDP growth trajectories against persistent inflation waves.
  * **FinTech Playbook Panel:** Structured operational guides for:
    * **Remittance-Backed Lending:** Utilizing cross-border inward remittances as quasi-collateral for BNPL/nano-loans.
    * **Inflation-Hedge WealthTech:** High-yield synthetic USD and gold-denominated digital retail savings products.
    * **GCC B2B Embedded Finance:** Capitalizing on GCC credit expansion for vendor financing and working capital digitization.

---

## 🧮 Data Modeling & DAX Core Metrics

The data model is built on an enterprise **Galaxy Schema** consisting of two fact tables (`fct_us_macro_monthly` and `fct_global_macro_annual`) unified by shared dimensions (`dim_date`, `dim_country`, `dim_indicator`).
