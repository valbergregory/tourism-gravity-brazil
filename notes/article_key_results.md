# Article Key Results

Working memory for writing the study. Every number below is copied from an
official pipeline output, and each entry names its source file and column. This
file is versioned but is **not** included in the article PDF.

Generated against the pipeline state of 2026-09-10, with `targets::tar_outdated()`
empty and no target in error. Column numbers refer to the published tables:
`main_models.tex` columns (1)–(7) and `robustness_models.tex` columns (1)–(6).

---

## 1. Sample and coverage

| Quantity | Value | Source |
|---|---|---|
| Full panel period | 2000-01 to 2025-12 | `output/tables/data_coverage.csv` |
| Full panel origins | 199 | `data_coverage.csv` |
| Full panel origin-month cells | 21,752 | `data_coverage.csv` |
| Observed cells | 21,089 (96.95%) | `data_coverage.csv` |
| Unobserved completed cells | 663 (3.05%), across 37 origins | `data_coverage.csv`; `panels$total` |
| Full panel arrivals (observed cells) | 135,255,668 | `data_coverage.csv` |
| Zero share among observed cells | 1.024% (216 zeros) | `data_coverage.csv` |
| Estimation sample rows | 19,108 | `output/audit/econometric_sample_summary.csv` |
| Estimation sample origins | 87 | same |
| Estimation sample arrivals | 134,240,120 | same |
| Coverage of full-panel arrivals | 99.25% | same, `full_panel_arrival_coverage` |
| Zero rows in estimation sample | 144 (0.754%) | same |
| Sample criterion | `sample_broad_5y` | `config.yml`; `econometric_sample$contract` |
| Contract check | expected 19,108 rows / 87 origins, `contract_ok = TRUE` | same |

Largest unobserved-cell origins: Puerto Rico 224, Iraq 216, Saudi Arabia 96,
French Guiana 21 (`panels$total`, `observation_status`).

**Concentration** (`output/tables/market_concentration_top20.csv`):
Argentina 29.343%, United States 11.482%, Paraguay 5.394%, Uruguay 5.268%,
Chile 5.250%. Cumulative share of the five largest: 56.74%. Fifteen largest:
84.45% (`output/tables/origin_summary.csv`).

**Annual arrivals, estimation sample** (`econometric_sample$data`):
2019 = 6,282,755; 2020 = 2,127,167; 2021 = 737,376; 2022 = 3,603,836;
2024 = 6,723,598; 2025 = 9,071,062. Change 2019→2021 = −88.3%;
2025 vs 2019 = +44.4%. Mean annual arrivals over 26 years = 5,163,082.

**Why N differs across columns** (`output/tables/model_specifications.csv`,
`input_rows` / `estimation_rows`):

| Specification | N | Reason |
|---|---|---|
| baseline_gdp_pli (1), gravity_distw_cre (7) | 19,108 | no lagged connectivity term |
| direct_l1 (2), seats_l1 (3), flights_l1 (4), connectivity_combined_l1 (6) | 19,023 | one-month lag not defined at the start of each origin series |
| seats_ma3_l1 (5) | 18,853 | three-month moving average |
| pre_covid | 13,221 (87 origins) | months before 2020-03 |
| post_reopening | 3,976 (85 origins) | months after 2021-12 |
| exclude_pandemic | 17,197 | pandemic window removed |
| balanced_core_2000 | 11,973 (39 origins) | `sample_core_2000` |
| cpi_price | 18,652 (85 origins) | CPI/FX coverage |
| household_pli_price | 18,702 (86 origins) | household PLI coverage |
| exclude_argentina | 18,712 (86 origins) | ARG removed |
| exclude_top_markets | 17,468 (82 origins) | five largest removed |
| quarterly | 6,371 | quarterly aggregation |
| air_access_mode | 19,021 | air arrivals only |
| modal_panel | 72,729 of 73,109 | 380 rows and 5 FE levels dropped by separation |

---

## 2. Baseline economic determinants

Source: `output/tables/coefficient_estimates.csv`, model `baseline_gdp_pli`;
displayed in `main_models.tex` column (1). N = 19,108, 87 clusters.

| Variable | Coef. | SE | p | 95% CI | Sig. | Reading |
|---|---|---|---|---|---|---|
| ln GDP per capita, t−1 | 0.4591 | 0.3265 | 0.160 | [−0.181, 1.099] | ns | Positive sign, not identified in the full sample. **Do not report as an effect.** |
| ln population, t−1 | 2.3842 | 0.7182 | 0.0009 | [0.977, 3.792] | *** | Elasticity far above one; identified from slow within-origin variation, likely absorbing long-run trends |
| ln relative GDP-PLI price | −0.5700 | 0.2103 | 0.0067 | [−0.982, −0.158] | ** | A loss of price competitiveness is associated with fewer arrivals |

Stability of the price coefficient across the main columns: −0.5700 (1),
−0.5674 (2), −0.5694 (3), −0.5913 (4), −0.5654 (5), −0.5730 (6), −0.6185 (7).

Joint test that income and population are both zero:
χ²(2) = 16.47, p = 0.00027, rejected (`formal_specification_tests.csv`).

---

## 3. Air connectivity

Source: `coefficient_estimates.csv`; columns of `main_models.tex` in brackets.

| Measure | Coef. | SE | p | Sig. | Column |
|---|---|---|---|---|---|
| Direct service, t−1 (alone) | −0.0479 | 0.0883 | 0.588 | ns | (2) |
| ln seats, t−1 | 0.0615 | 0.0224 | 0.0061 | ** | (3) |
| ln flights, t−1 | 0.1983 | 0.0660 | 0.0027 | ** | (4) |
| ln seats, prior three-month mean | 0.0539 | 0.0230 | 0.0194 | * | (5) |
| Direct service, t−1 (combined) | −0.2591 | 0.2018 | 0.199 | ns | (6) |
| ln seats, t−1 (combined) | 0.0873 | 0.0332 | 0.0085 | ** | (6) |
| Centred distance × direct, t−1 | −0.1140 | 0.1150 | 0.322 | ns | (6) |

Joint test that the lagged connectivity block is zero: χ²(3) = 12.15,
p = 0.0069, rejected.

**Marginal association of direct service by distance**
(`output/tables/direct_service_marginal_effects.csv`, model
`connectivity_combined_l1`, reference 5,000 km):

| Distance | Percent effect | 95% CI | Reading |
|---|---|---|---|
| 1,500 km | −11.47% | [−52.80, 66.04] | not distinguishable from zero |
| 5,000 km | −22.82% | [−48.03, 14.62] | not distinguishable from zero |
| 10,000 km | −28.69% | [−46.77, −4.45] | excludes zero, wrong sign for the hypothesis |

Interpretation to use: **conditional association**, not effect. The negative
long-haul value is treated as inconclusive and is most plausibly route
composition, not a causal statement about direct service.

Distribution used for conversions (`econometric_sample$data`): 58.7% of cells
have zero lagged seats; among positive cells P25 = 6,541, median = 15,832,
P75 = 35,094 seats. Direct service present in 46.8% of cells.

---

## 4. Gravity and distance

Source: `coefficient_estimates.csv`, model `gravity_distw_cre`; column (7).
N = 19,108. Origin-region and month-year effects plus Mundlak means.

| Variable | Coef. | SE | Sig. |
|---|---|---|---|
| ln distance (population weighted) | −3.4935 | 0.1469 | *** |
| Contiguity | 0.0247 | 0.1057 | ns |
| Common official language | 1.9704 | 0.7360 | ** |
| Colonial link | −0.0303 | 0.7442 | ns |
| Mean ln GDP p.c. (Mundlak) | 0.6158 | 0.3062 | * |
| Mean ln population (Mundlak) | −1.3198 | 0.7079 | + |
| Mean ln relative price (Mundlak) | −0.1873 | 0.3676 | ns |
| ln relative price | −0.6185 | 0.1942 | ** |
| ln population | 2.2729 | 0.7094 | ** |
| ln GDP p.c. | 0.3435 | 0.3009 | ns |

Alternative distances: `gravity_distcap_cre` ln distcap = −3.4788 (0.2028)***;
`gravity_simple_cre` ln dist = −2.5951 (0.1272)***.

Joint tests: gravity block χ²(4) = 1951.85, p < 0.001, rejected;
Mundlak means χ²(3) = 10.44, p = 0.0152, rejected.

**Identification note.** In the principal specification (columns 1–6), distance,
contiguity, language and colonial link are absorbed by the origin fixed effects
and are not estimated. Column (7) identifies them **between origins** under the
correlated-random-effects assumptions. Never present column (7) coefficients as
within-origin effects.

---

## 5. Robustness

Source: `coefficient_estimates.csv`; price row unless stated otherwise.

| Exercise | Price coef. | SE | Sig. | N | Note |
|---|---|---|---|---|---|
| Baseline | −0.5700 | 0.2103 | ** | 19,108 | reference |
| Pre-pandemic | −0.5299 | 0.1951 | ** | 13,221 | seats 0.0380 (0.0205) + |
| Post-reopening | −0.0084 | 0.2714 | ns | 3,976 | seats 0.0912 (0.0288)**; population −8.7775*** is not interpretable |
| Excluding pandemic | −0.5691 | 0.1937 | ** | 17,197 | seats 0.0844 (0.0334)* |
| Balanced core 2000 | −0.5825 | 0.2015 | ** | 11,973 | only 39 clusters |
| **Excluding Argentina** | **−0.1288** | 0.1211 | **ns** | 18,712 | income jumps to 1.0714 (0.2193)*** |
| Excluding five largest | −0.2591 | 0.1684 | ns | 17,468 | income 0.9525 (0.1636)*** |
| CPI price measure | −0.0567 | 0.0541 | ns | 18,652 | different regressor |
| Household PLI measure | −0.3198 | 0.1324 | * | 18,702 | different regressor |
| Contemporaneous connectivity | −0.5781 | 0.1968 | ** | 19,108 | seats 0.1123 (0.0459)* |
| Two-way cluster | −0.5700 | 0.2197 | ** | 19,108 | same point estimate |
| Heteroskedastic only | −0.5700 | 0.0650 | *** | 19,108 | lower bound on SE |
| Quarterly | −0.5698 | 0.2103 | ** | 6,371 | |
| Air arrivals only | −0.5858 | 0.1731 | *** | 19,021 | interaction −0.3097 (0.0899)*** |
| Modal panel | −0.5002 | 0.1626 | ** | 72,729 | 380 rows removed by separation |

**Leave-one-origin-out** (`output/tables/origin_leave_one_out_influence.csv`),
price elasticity, full estimate −0.57:

| Excluded | New estimate | Relative change |
|---|---|---|
| Argentina | −0.1054 (0.1357), ns | +81.5% |
| Paraguay | −0.6791 (0.1786) | −19.1% |
| Chile | −0.6337 (0.1937) | −11.2% |
| Uruguay | −0.6102 (0.2081) | −7.1% |
| Angola | −0.5411 | +5.1% |

**Functional form and regime**
(`coefficient_estimates.csv`, `formal_specification_tests.csv`):
squared centred price 0.0794 (0.0991), test of local linearity χ²(1) = 0.64,
p = 0.423, not rejected. Price × post-reopening 0.3591 (0.0794)***;
seats × post-reopening 0.0304 (0.0088)***; joint χ²(2) = 29.66, p < 0.001.
Post-reopening total price slope −0.1833 (0.1833), χ²(1) = 1.00, p = 0.317,
**not** distinguishable from zero. Post-reopening total seats slope 0.0736
(0.0237), χ²(1) = 9.61, p = 0.0019, significant.

---

## 6. Economic magnitudes

Source: `output/tables/economic_magnitudes.csv` (implied change for a 10%
increase) plus arithmetic on the sample mean annual arrivals of 5,163,082.

| Driver, +10% | Coef. | Implied change | 95% CI | Arrivals per year at sample mean |
|---|---|---|---|---|
| Relative GDP-PLI price | −0.5700 | −5.288% | [−8.936, −1.493] | −273,006 (range −461,367 to −77,085) |
| Lagged seats | 0.0615 | +0.588% | [0.168, 1.010] | +30,362 |
| Lagged flights | 0.1983 | +1.908% | [0.659, 3.172] | +98,500 |
| Lagged three-month mean seats | 0.0539 | +0.515% | [0.083, 0.948] | +26,573 |
| Population-weighted distance | −3.4935 | −28.320% | [−30.261, −26.326] | comparison between origins only |

Smaller price scenarios computed as `100[(1+g/100)^β − 1]` with β = −0.56999:
+1% → −0.566% ≈ −29,200 arrivals per year; +5% → −2.743% ≈ −141,606.

**Separate the concepts.** Elasticity (−0.570) ≠ percentage effect (−5.29% for
a 10% change) ≠ arrivals (−273,006 per year) ≠ revenue. **No monetary
conversion is available.** The project holds no expenditure-per-visitor series,
base year, currency convention, or exchange-rate assumption, so any revenue
figure would be an external assumption, not a result. Do not multiply arrivals
by an average spend without stating all of those.

The capacity conversions are evaluated at the median positive offer of 15,832
seats because the regressor is `log1p`, not a constant elasticity.

---

## 7. Model diagnostics and formal tests

Source: `output/tables/model_fit_diagnostics.csv`,
`output/tables/formal_specification_tests.csv`.

- Pearson dispersion, baseline ≈ 995.8; range 270.5 (excluding top markets) to
  2,283.8 (quarterly). Strong overdispersion; PPML is used as a
  pseudo-likelihood with robust standard errors, not as a literal Poisson model.
- Aggregate prediction ratio = 1.000 in every specification. This is a property
  of PPML with saturated fixed effects, **not** evidence of fit.
- MAE 2,003.4 and RMSE 9,112 in the baseline, against a mean of 7,025.3 arrivals
  per origin-month.
- Observed zero share 0.7536% vs Poisson-expected 0.6854% in the baseline.
- R² 0.955, R² within 0.148 in the baseline. The high global R² is largely the
  fixed effects. **Never cite R² as evidence of causality.**
- Separation: only `modal_panel` loses observations, 380 rows and 5 fixed-effect
  levels. Every other specification reports `converged = TRUE`, 0 removed rows,
  0 separation levels (`model_specifications.csv`).
- Documented warnings that remain: `geodist` reports 8 origins without a GeoDist
  match; `diagnostic_files` reports 11 rows dropped by `geom_line` (the first
  eleven months of a 12-month rolling mean); `model_files` reports the tinytable
  preamble notice. None affects an estimate.

---

## 8. Main findings for the abstract

1. Monthly panel of 19,108 origin-month observations, 87 source markets,
   January 2000 to December 2025, 134.2 million arrivals.
2. Relative price elasticity −0.570 (0.210); a 10% loss of competitiveness is
   associated with 5.29% fewer arrivals, about 273,000 per year.
3. That price association is identified almost entirely by Argentina, which
   supplies 29.3% of arrivals; excluding it leaves −0.105 and no significance.
4. Lagged air capacity is positive and significant but small: +0.59% for 10%
   more seats, +1.91% for 10% more flights.
5. Direct service yields no interpretable association once capacity is
   controlled; the distance interaction is not significant.
6. Structural distance gradient of −28.3% for 10% greater distance, identified
   between origins.
7. Price sensitivity present before the pandemic cannot be detected after the
   2022 reopening; the capacity association survives.

## 9. Main findings for the conclusion

- **Economic result.** Market size dominates the origin side (elasticity 2.384);
  income is not separately identified in the full sample.
- **Price competitiveness.** Negative and economically meaningful, but
  concentrated in one neighbouring market and dependent on the price measure:
  −0.570 with GDP-PLI, −0.320 with household PLI, −0.057 and insignificant with
  the CPI-based index.
- **Connectivity.** Positive and significant for capacity, small in magnitude,
  associational rather than causal, and null for the direct-service margin.
- **Distance.** Large and robust across three definitions (−3.493, −3.479,
  −2.595), but a between-origin comparison.
- **Regional concentration.** Five markets supply 56.7% of arrivals; the
  estimated aggregate elasticities inherit that concentration.
- **Pandemic and reopening.** The aggregate shock is absorbed by month-year
  effects and is not estimated; what changed is the slopes, and the change is
  statistically significant.
- **Policy.** Competitiveness policy concerns the price level facing the
  visitor, not domestic inflation alone; capacity is a supporting instrument,
  not a demand lever; market diversification is itself a risk-management
  objective.
- **Limitations.** Entries rather than expenditure; endogenous capacity; a
  single destination; no subnational detail.

---

## 10. Claims that must not be made

1. Do **not** claim a causal effect of air connectivity. Capacity responds to
   expected demand and the design has no instrument or route experiment.
2. Do **not** describe the model as having three-dimensional or three-way fixed
   effects. It is a two-way design in origins and months.
3. Do **not** refer to origin-destination or dyad fixed effects, or to
   multilateral resistance being estimated. There is one destination.
4. Do **not** claim a multidestination or structural-gravity estimation. The
   corresponding option is disabled in the configuration and the input file
   contains only a header.
5. Do **not** convert unobserved cells into zeros, and do not quote a zero share
   computed over the full rectangular panel.
6. Do **not** report the income coefficient of the baseline as an effect; it is
   not significant (p = 0.160).
7. Do **not** describe H5 or H7 as supported. Both estimates carry the opposite
   sign and are insignificant.
8. Do **not** generalise the Brazilian elasticities to other destinations.
9. Do **not** claim anything about the region, state, municipality, expenditure,
   length of stay, or internal movement of visitors. The data are entries by
   country of residence.
10. Do **not** quote a tourism-revenue figure. No expenditure series is in the
    project.
11. Do **not** present the visa channel or event studies as estimated. Both are
    disabled in the configuration.
12. Do **not** cite the price result without the Argentina caveat.

---

## 11. Traceability of every quantitative claim

| Claim | Exact value | Statistical evidence | Source file | Model / column | Interpretation | Limitation |
|---|---|---|---|---|---|---|
| Sample size | 19,108 obs, 87 origins | contract check passed | `econometric_sample_summary.csv` | `sample_broad_5y` | Panel used in every main column | Excludes 112 low-coverage origins |
| Arrivals covered | 134,240,120 (99.25%) | — | same | — | Sample loses origins, not volume | — |
| Price elasticity | −0.5700 | SE 0.2103, p = 0.0067 | `coefficient_estimates.csv` | `baseline_gdp_pli`, col (1) | Conditional association | Driven by Argentina |
| Price, 10% scenario | −5.288% | CI [−8.936, −1.493] | `economic_magnitudes.csv` | same | Scenario, not forecast | Inherits the caveat above |
| Price in arrivals | −273,006 per year | derived from CI: −461,367 to −77,085 | `economic_magnitudes.csv` × 5,163,082 | same | Illustrative scale | Arithmetic on a sample mean |
| Price without Argentina | −0.1288 | SE 0.1211, ns | `coefficient_estimates.csv` | `exclude_argentina` | Association disappears | 86 origins |
| Price, leave-one-out ARG | −0.1054 | +81.5% change | `origin_leave_one_out_influence.csv` | `baseline_gdp_pli` | Single-market dependence | — |
| Population elasticity | 2.3842 | SE 0.7182, p = 0.0009 | `coefficient_estimates.csv` | col (1) | Market size | Magnitude likely absorbs trends |
| Income elasticity | 0.4591 | SE 0.3265, ns | `coefficient_estimates.csv` | col (1) | Not identified | Becomes 1.071*** without ARG |
| Seats | 0.0615 | SE 0.0224, p = 0.0061 | `coefficient_estimates.csv` | col (3) | Conditional association | `log1p`, not an elasticity |
| Seats, 10% scenario | +0.588% | CI [0.168, 1.010] | `economic_magnitudes.csv` | col (3) | At median positive offer | Endogenous capacity |
| Flights, 10% scenario | +1.908% | CI [0.659, 3.172] | `economic_magnitudes.csv` | col (4) | Conditional association | Same |
| Direct service | −0.0479 | SE 0.0883, ns | `coefficient_estimates.csv` | col (2) | Inconclusive | Opposite sign to H5 |
| Distance × direct | −0.1140 | SE 0.1150, ns | `coefficient_estimates.csv` | col (6) | Inconclusive | Opposite sign to H7 |
| Direct at 10,000 km | −28.69% | CI [−46.77, −4.45] | `direct_service_marginal_effects.csv` | col (6) | Not causal | Likely route composition |
| Distance elasticity | −3.4935 | SE 0.1469, p < 0.001 | `coefficient_estimates.csv` | col (7) | Between origins | CRE assumptions |
| Distance, 10% scenario | −28.320% | CI [−30.261, −26.326] | `economic_magnitudes.csv` | col (7) | Cross-sectional | Not a policy margin |
| Common language | 1.9704 | SE 0.7360, p = 0.0074 | `coefficient_estimates.csv` | col (7) | Between origins | Same |
| Post-reopening price slope | −0.1833 | SE 0.1833, p = 0.317 | `formal_specification_tests.csv` | `post_reopening_interactions` | Not distinguishable from zero | 4-year window |
| Post-reopening seats slope | 0.0736 | SE 0.0237, p = 0.0019 | same | same | Survives the regime change | Same |
| Argentina share | 29.343% | — | `market_concentration_top20.csv` | — | Concentration | — |
| Top-5 share | 56.74% | — | same, cumulative | — | Concentration | — |
| Dispersion | 995.8 | — | `model_fit_diagnostics.csv` | col (1) | Justifies PPML with robust SE | Not a fit statistic |
| 2019→2021 change | −88.3% | — | `econometric_sample$data` | — | Pandemic collapse | Descriptive |
| 2025 vs 2019 | +44.4% | — | same | — | Recovery above pre-pandemic | Descriptive |
| Origins without distance | 9 territories, 2,118 arrivals (0.0016%) | — | `geodist_missing_origins.csv`; `panels$total` | — | Exclusion is not binding | All 2025-only |
