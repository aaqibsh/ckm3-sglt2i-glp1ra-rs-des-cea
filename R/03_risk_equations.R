# =============================================================================
# File: 03_risk_equations.R
# Purpose: PREVENT risk equations (Khan et al. Circulation 2024), CV and non-CV
#          mortality, and CKD staging helpers
# Author: CKM-HEOR Team
# Date: 2026-11-09 (revised — PREVENT full model with UACR)
# =============================================================================
# Coefficients are the published 10-year PREVENT coefficients, verified to be
# identical to the preventr CRAN package tables (see validate_prevent_equations()
# in 10_validation.R). Each model list holds the ASCVD, HF, CHD and stroke
# equations; CHD and stroke are used only to apportion the ASCVD hazard.
# =============================================================================

# PREVENT Model Coefficients
PREVENT_COEF <- list(
  hba1c = list(
    female_ascvd = c(
      age = 0.7111831, non_hdl = 0.1067970, hdl = -0.1425745, sbp_lt_110 = -0.0736824, sbp_gte_110 = 0.3480844,
      dm = 0.5112951, smoking = 0.4880292, bmi_lt_30 = 0.0, bmi_gte_30 = 0.0, egfr_lt_60 = 0.4754997,
      egfr_gte_60 = 0.0438132, bp_tx = 0.2259093, statin = -0.0648872, bp_tx_sbp_gte_110 = -0.0437645,
      statin_non_hdl = 0.0697082, age_non_hdl = -0.0506382, age_hdl = 0.0327475, age_sbp_gte_110 = -0.0996442,
      age_dm = -0.1924338, age_smoking = -0.0803539, age_bmi_gte_30 = 0.0, age_egfr_lt_60 = -0.1682586,
      hba1c_dm = 0.1339055, hba1c_nodm = 0.1596461, hba1c_missing = 0.0015678, intercept = -3.8387460
    ),
    male_ascvd = c(
      age = 0.7064146, non_hdl = 0.1532267, hdl = -0.1082166, sbp_lt_110 = -0.2675288, sbp_gte_110 = 0.3173809,
      dm = 0.4326040, smoking = 0.3958842, bmi_lt_30 = 0.0, bmi_gte_30 = 0.0, egfr_lt_60 = 0.3665014,
      egfr_gte_60 = 0.0250243, bp_tx = 0.2061158, statin = -0.0899988, bp_tx_sbp_gte_110 = -0.0334959,
      statin_non_hdl = 0.1034168, age_non_hdl = -0.0255406, age_hdl = 0.0247538, age_sbp_gte_110 = -0.0917441,
      age_dm = -0.1499195, age_smoking = -0.0980890, age_bmi_gte_30 = 0.0, age_egfr_lt_60 = -0.1305231,
      hba1c_dm = 0.1157161, hba1c_nodm = 0.1288303, hba1c_missing = -0.0010001, intercept = -3.5183500
    ),
    female_hf = c(
      age = 0.8997391, non_hdl = 0.0, hdl = 0.0, sbp_lt_110 = -0.4422749, sbp_gte_110 = 0.3378691,
      dm = 0.6812840, smoking = 0.5886005, bmi_lt_30 = -0.0148657, bmi_gte_30 = 0.2958374, egfr_lt_60 = 0.7344700,
      egfr_gte_60 = 0.0592600, bp_tx = 0.3543475, statin = 0.0, bp_tx_sbp_gte_110 = -0.1002139,
      statin_non_hdl = 0.0, age_non_hdl = 0.0, age_hdl = 0.0, age_sbp_gte_110 = -0.0878765,
      age_dm = -0.3036840, age_smoking = -0.1178943, age_bmi_gte_30 = -0.0083450, age_egfr_lt_60 = -0.1912183,
      hba1c_dm = 0.1856442, hba1c_nodm = 0.1833083, hba1c_missing = -0.0143112, intercept = -4.2882250
    ),
    male_hf = c(
      age = 0.9117870, non_hdl = 0.0, hdl = 0.0, sbp_lt_110 = -0.6568071, sbp_gte_110 = 0.3524645,
      dm = 0.5849752, smoking = 0.5014014, bmi_lt_30 = -0.0512352, bmi_gte_30 = 0.3652940, egfr_lt_60 = 0.6892219,
      egfr_gte_60 = 0.0292377, bp_tx = 0.3038296, statin = 0.0, bp_tx_sbp_gte_110 = -0.0515032,
      statin_non_hdl = 0.0, age_non_hdl = 0.0, age_hdl = 0.0, age_sbp_gte_110 = -0.1262343,
      age_dm = -0.2449514, age_smoking = -0.1392217, age_bmi_gte_30 = 0.0009592, age_egfr_lt_60 = -0.1917105,
      hba1c_dm = 0.1652857, hba1c_nodm = 0.1505859, hba1c_missing = -0.0113444, intercept = -3.9619540
    ),
    # CHD and stroke sub-models: used only to split the ASCVD hazard into MI vs stroke
    female_chd = c(
      age = 0.7559415, non_hdl = 0.1663933, hdl = -0.1905004, sbp_lt_110 = -0.0768509, sbp_gte_110 = 0.3396470,
      dm = 0.5632228, smoking = 0.5478000, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.5105085,
      egfr_gte_60 = 0.0381344, bp_tx = 0.2023093, statin = -0.0425927, bp_tx_sbp_gte_110 = -0.0953791, statin_non_hdl = 0.0587372,
      age_non_hdl = -0.0607664, age_hdl = 0.0485765, age_sbp_gte_110 = -0.0841698, age_dm = -0.1986967, age_smoking = -0.0807069,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1610913, hba1c_dm = 0.1832739, hba1c_nodm = 0.1755465, hba1c_missing = 0.0268381,
      intercept = -4.6674570
    ),
    female_stroke = c(
      age = 0.6854957, non_hdl = 0.0432610, hdl = -0.0983793, sbp_lt_110 = -0.1017197, sbp_gte_110 = 0.3565955,
      dm = 0.4609555, smoking = 0.4198301, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.4436518,
      egfr_gte_60 = 0.0544989, bp_tx = 0.2493831, statin = -0.0859775, bp_tx_sbp_gte_110 = -0.0114564, statin_non_hdl = 0.0689079,
      age_non_hdl = -0.0360130, age_hdl = 0.0171809, age_sbp_gte_110 = -0.1156790, age_dm = -0.2025816, age_smoking = -0.1003882,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1760082, hba1c_dm = 0.0929695, hba1c_nodm = 0.1545054, hba1c_missing = -0.0255090,
      intercept = -4.3964480
    ),
    male_chd = c(
      age = 0.7223642, non_hdl = 0.2443591, hdl = -0.1755236, sbp_lt_110 = -0.3025745, sbp_gte_110 = 0.3056892,
      dm = 0.4874841, smoking = 0.3942456, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3748008,
      egfr_gte_60 = 0.0250407, bp_tx = 0.1616182, statin = -0.0513733, bp_tx_sbp_gte_110 = -0.0591310, statin_non_hdl = 0.0710909,
      age_non_hdl = -0.0476587, age_hdl = 0.0502694, age_sbp_gte_110 = -0.0838455, age_dm = -0.1630679, age_smoking = -0.1220691,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.0859505, hba1c_dm = 0.1251064, hba1c_nodm = 0.1177006, hba1c_missing = 0.0285438,
      intercept = -4.2196540
    ),
    male_stroke = c(
      age = 0.7244468, non_hdl = 0.0134286, hdl = -0.0204357, sbp_lt_110 = -0.2506963, sbp_gte_110 = 0.3408562,
      dm = 0.3535500, smoking = 0.3854904, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3869787,
      egfr_gte_60 = 0.0237663, bp_tx = 0.2361590, statin = -0.1241976, bp_tx_sbp_gte_110 = 0.0095878, statin_non_hdl = 0.1424174,
      age_non_hdl = 0.0189220, age_hdl = -0.0093452, age_sbp_gte_110 = -0.1143576, age_dm = -0.1559808, age_smoking = -0.0824194,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1890904, hba1c_dm = 0.1076023, hba1c_nodm = 0.1408596, hba1c_missing = -0.0470943,
      intercept = -4.1793460
    )
  ),
  base = list(
    female_ascvd = c(
      age = 0.7198830, non_hdl = 0.1176967, hdl = -0.1511850, sbp_lt_110 = -0.0835358, sbp_gte_110 = 0.3592852,
      dm = 0.8348585, smoking = 0.4831078, bmi_lt_30 = 0.0, bmi_gte_30 = 0.0, egfr_lt_60 = 0.4864619,
      egfr_gte_60 = 0.0397779, bp_tx = 0.2265309, statin = -0.0592374, bp_tx_sbp_gte_110 = -0.0395762,
      statin_non_hdl = 0.0844423, age_non_hdl = -0.0567839, age_hdl = 0.0325692, age_sbp_gte_110 = -0.1035985,
      age_dm = -0.2417542, age_smoking = -0.0791142, age_bmi_gte_30 = 0.0, age_egfr_lt_60 = -0.1671492,
      intercept = -3.8199750
    ),
    male_ascvd = c(
      age = 0.7099847, non_hdl = 0.1658663, hdl = -0.1144285, sbp_lt_110 = -0.2837212, sbp_gte_110 = 0.3239977,
      dm = 0.7189597, smoking = 0.3956973, bmi_lt_30 = 0.0, bmi_gte_30 = 0.0, egfr_lt_60 = 0.3690075,
      egfr_gte_60 = 0.0203619, bp_tx = 0.2036522, statin = -0.0865581, bp_tx_sbp_gte_110 = -0.0322916,
      statin_non_hdl = 0.1145630, age_non_hdl = -0.0300005, age_hdl = 0.0232747, age_sbp_gte_110 = -0.0927024,
      age_dm = -0.2018525, age_smoking = -0.0970527, age_bmi_gte_30 = 0.0, age_egfr_lt_60 = -0.1217081,
      intercept = -3.5006550
    ),
    female_hf = c(
      age = 0.8998235, non_hdl = 0.0, hdl = 0.0, sbp_lt_110 = -0.4559771, sbp_gte_110 = 0.3576505,
      dm = 1.0383460, smoking = 0.5839160, bmi_lt_30 = -0.0072294, bmi_gte_30 = 0.2997706, egfr_lt_60 = 0.7451638,
      egfr_gte_60 = 0.0557087, bp_tx = 0.3534442, statin = 0.0, bp_tx_sbp_gte_110 = -0.0981511,
      statin_non_hdl = 0.0, age_non_hdl = 0.0, age_hdl = 0.0, age_sbp_gte_110 = -0.0946663,
      age_dm = -0.3581041, age_smoking = -0.1159453, age_bmi_gte_30 = -0.0038780, age_egfr_lt_60 = -0.1884289,
      intercept = -4.3104090
    ),
    male_hf = c(
      age = 0.8972642, non_hdl = 0.0, hdl = 0.0, sbp_lt_110 = -0.6811466, sbp_gte_110 = 0.3634461,
      dm = 0.9237760, smoking = 0.5023736, bmi_lt_30 = -0.0485841, bmi_gte_30 = 0.3726929, egfr_lt_60 = 0.6926917,
      egfr_gte_60 = 0.0251827, bp_tx = 0.2980922, statin = 0.0, bp_tx_sbp_gte_110 = -0.0497731,
      statin_non_hdl = 0.0, age_non_hdl = 0.0, age_hdl = 0.0, age_sbp_gte_110 = -0.1289201,
      age_dm = -0.3040924, age_smoking = -0.1401688, age_bmi_gte_30 = 0.0068126, age_egfr_lt_60 = -0.1797778,
      intercept = -3.9463910
    ),
    female_chd = c(
      age = 0.7587146, non_hdl = 0.1810949, hdl = -0.2014507, sbp_lt_110 = -0.0881827, sbp_gte_110 = 0.3547731,
      dm = 0.9045358, smoking = 0.5410917, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.5198725,
      egfr_gte_60 = 0.0325935, bp_tx = 0.2010642, statin = -0.0361950, bp_tx_sbp_gte_110 = -0.0891238, statin_non_hdl = 0.0750716,
      age_non_hdl = -0.0683256, age_hdl = 0.0484755, age_sbp_gte_110 = -0.0898086, age_dm = -0.2569041, age_smoking = -0.0786607,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1597513, intercept = -4.6087510
    ),
    female_stroke = c(
      age = 0.6907849, non_hdl = 0.0534279, hdl = -0.1055109, sbp_lt_110 = -0.1130780, sbp_gte_110 = 0.3665217,
      dm = 0.8013721, smoking = 0.4187039, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.4539767,
      egfr_gte_60 = 0.0515087, bp_tx = 0.2494624, statin = -0.0798829, bp_tx_sbp_gte_110 = -0.0079039, statin_non_hdl = 0.0833101,
      age_non_hdl = -0.0409242, age_hdl = 0.0169940, age_sbp_gte_110 = -0.1191213, age_dm = -0.2480549, age_smoking = -0.0998063,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1759075, intercept = -4.4091990
    ),
    male_chd = c(
      age = 0.7423283, non_hdl = 0.2572109, hdl = -0.1820374, sbp_lt_110 = -0.3174515, sbp_gte_110 = 0.3127780,
      dm = 0.7485249, smoking = 0.3912047, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3764870,
      egfr_gte_60 = 0.0193687, bp_tx = 0.1588199, statin = -0.0494555, bp_tx_sbp_gte_110 = -0.0577851, statin_non_hdl = 0.0809765,
      age_non_hdl = -0.0517872, age_hdl = 0.0489033, age_sbp_gte_110 = -0.0850404, age_dm = -0.2107552, age_smoking = -0.1206397,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.0779500, intercept = -4.1567530
    ),
    male_stroke = c(
      age = 0.7225130, non_hdl = 0.0263348, hdl = -0.0248959, sbp_lt_110 = -0.2681040, sbp_gte_110 = 0.3474634,
      dm = 0.6846990, smoking = 0.3874844, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3877827,
      egfr_gte_60 = 0.0201965, bp_tx = 0.2329630, statin = -0.1178935, bp_tx_sbp_gte_110 = 0.0120926, statin_non_hdl = 0.1557390,
      age_non_hdl = 0.0141928, age_hdl = -0.0111745, age_sbp_gte_110 = -0.1155391, age_dm = -0.2123743, age_smoking = -0.0824133,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1807890, intercept = -4.2088100
    )
  ),
  # Full model (UACR, HbA1c and social deprivation index; preventr full_10yr).
  # SDI is not available for simulated patients and enters as missing, as in
  # preventr when no ZIP code is given.
  full = list(
    female_ascvd = c(
      age = 0.7023067, non_hdl = 0.0898765, hdl = -0.1407316, sbp_lt_110 = -0.0256648, sbp_gte_110 = 0.3145110,
      dm = 0.4799217, smoking = 0.4062049, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3847744,
      egfr_gte_60 = 0.0495174, bp_tx = 0.2133861, statin = -0.0678552, bp_tx_sbp_gte_110 = -0.0451416, statin_non_hdl = 0.0788187,
      age_non_hdl = -0.0535985, age_hdl = 0.0291762, age_sbp_gte_110 = -0.0961839, age_dm = -0.2001466, age_smoking = -0.0586472,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1537791, sdi_4_6 = 0.1413965, sdi_7_10 = 0.2281360, sdi_missing = 0.1588908,
      ln_uacr = 0.1371824, uacr_missing = 0.0061613, hba1c_dm = 0.1231920, hba1c_nodm = 0.1410572, hba1c_missing = 0.0058660,
      intercept = -4.2915030
    ),
    male_ascvd = c(
      age = 0.7128741, non_hdl = 0.1465201, hdl = -0.1125794, sbp_lt_110 = -0.3387216, sbp_gte_110 = 0.2980252,
      dm = 0.3995830, smoking = 0.3379111, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.2582604,
      egfr_gte_60 = 0.0147769, bp_tx = 0.1686621, statin = -0.1073619, bp_tx_sbp_gte_110 = -0.0381038, statin_non_hdl = 0.1034169,
      age_non_hdl = -0.0228755, age_hdl = 0.0267453, age_sbp_gte_110 = -0.0897449, age_dm = -0.1497464, age_smoking = -0.0772060,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1198368, sdi_4_6 = 0.0651121, sdi_7_10 = 0.2676683, sdi_missing = 0.1388492,
      ln_uacr = 0.1375837, uacr_missing = 0.0652944, hba1c_dm = 0.1012820, hba1c_nodm = 0.1092726, hba1c_missing = -0.0112852,
      intercept = -3.9697880
    ),
    female_hf = c(
      age = 0.8842090, non_hdl = 0.0000000, hdl = 0.0000000, sbp_lt_110 = -0.4214740, sbp_gte_110 = 0.3002919,
      dm = 0.6170359, smoking = 0.5380269, bmi_lt_30 = -0.0191335, bmi_gte_30 = 0.2764302, egfr_lt_60 = 0.5975847,
      egfr_gte_60 = 0.0654197, bp_tx = 0.3313614, statin = 0.0000000, bp_tx_sbp_gte_110 = -0.1002304, statin_non_hdl = 0.0000000,
      age_non_hdl = 0.0000000, age_hdl = 0.0000000, age_sbp_gte_110 = -0.0845363, age_dm = -0.2989062, age_smoking = -0.1111354,
      age_bmi_gte_30 = 0.0008104, age_egfr_lt_60 = -0.1666635, sdi_4_6 = 0.1213034, sdi_7_10 = 0.2314147, sdi_missing = 0.1819138,
      ln_uacr = 0.1948135, uacr_missing = 0.0395368, hba1c_dm = 0.1766680, hba1c_nodm = 0.1614911, hba1c_missing = -0.0010583,
      intercept = -4.8965240
    ),
    male_hf = c(
      age = 0.9095703, non_hdl = 0.0000000, hdl = 0.0000000, sbp_lt_110 = -0.6765184, sbp_gte_110 = 0.3111651,
      dm = 0.5535052, smoking = 0.4326811, bmi_lt_30 = -0.0854286, bmi_gte_30 = 0.3551736, egfr_lt_60 = 0.5102245,
      egfr_gte_60 = 0.0154720, bp_tx = 0.2570964, statin = 0.0000000, bp_tx_sbp_gte_110 = -0.0591177, statin_non_hdl = 0.0000000,
      age_non_hdl = 0.0000000, age_hdl = 0.0000000, age_sbp_gte_110 = -0.1219056, age_dm = -0.2437577, age_smoking = -0.1053630,
      age_bmi_gte_30 = 0.0037907, age_egfr_lt_60 = -0.1660207, sdi_4_6 = 0.1106372, sdi_7_10 = 0.3371204, sdi_missing = 0.1694628,
      ln_uacr = 0.2164607, uacr_missing = 0.1702805, hba1c_dm = 0.1482970, hba1c_nodm = 0.1234088, hba1c_missing = -0.0234637,
      intercept = -4.6635130
    ),
    female_chd = c(
      age = 0.7544208, non_hdl = 0.1403589, hdl = -0.1954699, sbp_lt_110 = -0.0021814, sbp_gte_110 = 0.3127753,
      dm = 0.5230750, smoking = 0.4594228, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.4173237,
      egfr_gte_60 = 0.0385169, bp_tx = 0.1981640, statin = -0.0557405, bp_tx_sbp_gte_110 = -0.0940465, statin_non_hdl = 0.0844888,
      age_non_hdl = -0.0630114, age_hdl = 0.0473455, age_sbp_gte_110 = -0.0801956, age_dm = -0.2002523, age_smoking = -0.0484742,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1455343, sdi_4_6 = 0.1651771, sdi_7_10 = 0.2276000, sdi_missing = 0.1602508,
      ln_uacr = 0.1406282, uacr_missing = 0.0323720, hba1c_dm = 0.1656628, hba1c_nodm = 0.1586376, hba1c_missing = 0.0266703,
      intercept = -5.1315050
    ),
    female_stroke = c(
      age = 0.6848394, non_hdl = 0.0327248, hdl = -0.0957615, sbp_lt_110 = -0.0747400, sbp_gte_110 = 0.3237856,
      dm = 0.4441471, smoking = 0.3636951, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.3629529,
      egfr_gte_60 = 0.0603154, bp_tx = 0.2253420, statin = -0.0885632, bp_tx_sbp_gte_110 = -0.0161592, statin_non_hdl = 0.0727068,
      age_non_hdl = -0.0389022, age_hdl = 0.0141743, age_sbp_gte_110 = -0.1121459, age_dm = -0.2089706, age_smoking = -0.0703397,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1605001, sdi_4_6 = 0.1064527, sdi_7_10 = 0.2095741, sdi_missing = 0.1402740,
      ln_uacr = 0.1285363, uacr_missing = -0.0243528, hba1c_dm = 0.0897340, hba1c_nodm = 0.1354790, hba1c_missing = -0.0158448,
      intercept = -4.8008020
    ),
    male_chd = c(
      age = 0.7335852, non_hdl = 0.2403104, hdl = -0.1822238, sbp_lt_110 = -0.4148860, sbp_gte_110 = 0.2880084,
      dm = 0.4937277, smoking = 0.3326075, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.2586836,
      egfr_gte_60 = 0.0124978, bp_tx = 0.1132755, statin = -0.0823542, bp_tx_sbp_gte_110 = -0.0718794, statin_non_hdl = 0.0765924,
      age_non_hdl = -0.0489011, age_hdl = 0.0531464, age_sbp_gte_110 = -0.0813293, age_dm = -0.1679294, age_smoking = -0.0927969,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.0677064, sdi_4_6 = 0.0705264, sdi_7_10 = 0.2306082, sdi_missing = 0.0942060,
      ln_uacr = 0.1354182, uacr_missing = 0.0759494, hba1c_dm = 0.1161950, hba1c_nodm = 0.0991112, hba1c_missing = 0.0213677,
      intercept = -4.6298740
    ),
    male_stroke = c(
      age = 0.7182761, non_hdl = 0.0008864, hdl = -0.0220683, sbp_lt_110 = -0.2719759, sbp_gte_110 = 0.3199570,
      dm = 0.2728292, smoking = 0.3426763, bmi_lt_30 = 0.0000000, bmi_gte_30 = 0.0000000, egfr_lt_60 = 0.2907134,
      egfr_gte_60 = 0.0186548, bp_tx = 0.2400360, statin = -0.1218938, bp_tx_sbp_gte_110 = 0.0042588, statin_non_hdl = 0.1412729,
      age_non_hdl = 0.0275883, age_hdl = -0.0079987, age_sbp_gte_110 = -0.1121897, age_dm = -0.1446989, age_smoking = -0.0580327,
      age_bmi_gte_30 = 0.0000000, age_egfr_lt_60 = -0.1820914, sdi_4_6 = 0.0797728, sdi_7_10 = 0.3204988, sdi_missing = 0.1892707,
      ln_uacr = 0.1404936, uacr_missing = 0.0536898, hba1c_dm = 0.0868309, hba1c_nodm = 0.1187536, hba1c_missing = -0.0603180,
      intercept = -4.6830480
    )
  )
)

# Validated input ranges of the PREVENT equations (Khan et al. 2024; as enforced by
# the preventr package). Inputs outside these ranges are winsorised before scoring.
# Age is NOT clamped: the model ages patients beyond 79, so the age terms are
# extrapolated (the resulting risk is smooth and monotone in age up to 100).
PREVENT_RANGES <- list(
  sbp        = c(90, 180),
  total_chol = c(130, 320),
  hdl_chol   = c(20, 100),
  bmi        = c(18.5, 39.9),
  egfr       = c(15, 140),
  hba1c      = c(4.5, 15),
  # preventr accepts 0.1-25,000 mg/g; values below the assay limit (3 mg/g) are
  # set to 3, as in the kidney trajectory (egfr_patient_multiplier())
  uacr       = c(3, 25000)
)

clamp <- function(x, range) pmin(pmax(x, range[1]), range[2])


#' Score one PREVENT 10-year equation and convert to an annual hazard
#'
#' @param outcome One of "ascvd", "hf", "chd", "stroke"
#' @param use_hba1c Logical; use the HbA1c-enhanced model when hba1c is supplied
#' @param uacr Urine albumin-creatinine ratio (mg/g); used by the full model
#' @param model "base", "hba1c" or "full"; NULL chooses from use_hba1c (base/hba1c)
#' @return Annual hazard implied by a constant hazard over 10 years
calculate_prevent_hazard <- function(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi, hba1c, outcome, use_hba1c, uacr = NULL, model = NULL) {
  if (is.null(model)) model <- if (use_hba1c && !is.null(hba1c)) "hba1c" else "base"
  use_hba1c_model <- model %in% c("hba1c", "full")
  b <- PREVENT_COEF[[model]][[paste0(if (sex == 1) "male_" else "female_", outcome)]]
  if (is.null(b)) stop("Unknown PREVENT outcome: ", outcome)

  # Winsorise to the validated input ranges
  sbp        <- clamp(sbp, PREVENT_RANGES$sbp)
  total_chol <- clamp(total_chol, PREVENT_RANGES$total_chol)
  hdl_chol   <- clamp(hdl_chol, PREVENT_RANGES$hdl_chol)
  bmi        <- clamp(bmi, PREVENT_RANGES$bmi)
  egfr       <- clamp(egfr, PREVENT_RANGES$egfr)

  # Predictor scaling
  age_s       <- (age - 55) / 10
  non_hdl_mol <- ((total_chol - hdl_chol) * 0.02586) - 3.5
  hdl_mol     <- ((hdl_chol * 0.02586) - 1.3) / 0.3
  sbp_lt_110  <- (pmin(sbp, 110) - 110) / 20
  sbp_gte_110 <- (pmax(sbp, 110) - 130) / 20
  bmi_lt_30   <- (pmin(bmi, 30) - 25) / 5
  bmi_gte_30  <- (pmax(bmi, 30) - 30) / 5
  egfr_lt_60  <- (pmin(egfr, 60) - 60) / (-15)
  egfr_gte_60 <- (pmax(egfr, 60) - 90) / (-15)

  log_odds <- b["intercept"] +
    b["age"] * age_s +
    b["non_hdl"] * non_hdl_mol +
    b["hdl"] * hdl_mol +
    b["sbp_lt_110"] * sbp_lt_110 +
    b["sbp_gte_110"] * sbp_gte_110 +
    b["dm"] * diabetes +
    b["smoking"] * smoking +
    b["bmi_lt_30"] * bmi_lt_30 +
    b["bmi_gte_30"] * bmi_gte_30 +
    b["egfr_lt_60"] * egfr_lt_60 +
    b["egfr_gte_60"] * egfr_gte_60 +
    b["bp_tx"] * antihyp_use +
    b["statin"] * statin_use +
    b["bp_tx_sbp_gte_110"] * (antihyp_use * sbp_gte_110) +
    b["statin_non_hdl"] * (statin_use * non_hdl_mol) +
    b["age_non_hdl"] * (age_s * non_hdl_mol) +
    b["age_hdl"] * (age_s * hdl_mol) +
    b["age_sbp_gte_110"] * (age_s * sbp_gte_110) +
    b["age_dm"] * (age_s * diabetes) +
    b["age_smoking"] * (age_s * smoking) +
    b["age_bmi_gte_30"] * (age_s * bmi_gte_30) +
    b["age_egfr_lt_60"] * (age_s * egfr_lt_60)

  if (use_hba1c_model) {
    hba1c_miss <- ifelse(is.na(hba1c), 1, 0)
    hba1c_val  <- ifelse(is.na(hba1c), 5.3, clamp(hba1c, PREVENT_RANGES$hba1c))
    hba1c_dm   <- ifelse(diabetes == 1, hba1c_val - 5.3, 0)
    hba1c_nodm <- ifelse(diabetes == 0, hba1c_val - 5.3, 0)

    log_odds <- log_odds +
      b["hba1c_dm"] * hba1c_dm +
      b["hba1c_nodm"] * hba1c_nodm +
      b["hba1c_missing"] * hba1c_miss
  }

  if (model == "full") {
    # ln(UACR) uncentred, SDI missing (preventr prep_terms())
    uacr_miss <- if (is.null(uacr) || is.na(uacr)) 1 else 0
    ln_uacr   <- if (uacr_miss == 1) 0 else log(clamp(uacr, PREVENT_RANGES$uacr))
    log_odds <- log_odds + b["ln_uacr"] * ln_uacr + b["uacr_missing"] * uacr_miss + b["sdi_missing"]
  }

  p_10yr <- 1 / (1 + exp(-log_odds))
  lambda <- -log(1 - p_10yr) / 10

  return(unname(lambda))
}

#' Calculate Annual ASCVD Hazard (PREVENT)
#'
#' @param age Numeric, age in years
#' @param sex Integer, 1 for male, 0 for female
#' @param sbp Numeric, systolic blood pressure (mmHg)
#' @param total_chol Numeric, total cholesterol (mg/dL)
#' @param hdl_chol Numeric, HDL cholesterol (mg/dL)
#' @param diabetes Integer, 1 for diabetes, 0 otherwise
#' @param smoking Integer, 1 for smoking, 0 otherwise
#' @param egfr Numeric, eGFR (mL/min/1.73m2)
#' @param statin_use Integer, 1 for statin use, 0 otherwise
#' @param antihyp_use Integer, 1 for antihypertensive use, 0 otherwise
#' @param bmi Numeric, body mass index
#' @param hba1c Numeric, HbA1c percentage
#' @param use_hba1c Logical, whether to use HbA1c model
#'
#' @return Numeric, annual hazard rate
#' @export
calculate_annual_ascvd_hazard <- function(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi = 25, hba1c = NULL, use_hba1c = TRUE, uacr = NULL, model = NULL) {
  calculate_prevent_hazard(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi, hba1c, "ascvd", use_hba1c, uacr, model)
}

#' Calculate Annual Heart Failure Hazard (PREVENT)
#'
#' @inheritParams calculate_annual_ascvd_hazard
#' @return Numeric, annual hazard rate
#' @export
calculate_annual_hf_hazard <- function(age, sex, bmi, sbp, egfr, hba1c, diabetes, smoking, antihyp_use = 0, total_chol = 200, hdl_chol = 50, statin_use = 0, use_hba1c = TRUE, uacr = NULL, model = NULL) {
  calculate_prevent_hazard(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi, hba1c, "hf", use_hba1c, uacr, model)
}

#' Share of ASCVD hazard attributable to MI (CHD) rather than stroke
#'
#' @description Uses the PREVENT CHD and stroke sub-models. Because these are
#'   fitted separately, their sum exceeds the ASCVD hazard (~10% in Stage 3), so
#'   they are used only as a patient-specific split of the ASCVD hazard.
#' @inheritParams calculate_annual_ascvd_hazard
#' @return Numeric in (0, 1)
calculate_mi_share <- function(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi = 25, hba1c = NULL, use_hba1c = TRUE, uacr = NULL, model = NULL) {
  h_chd    <- calculate_prevent_hazard(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi, hba1c, "chd", use_hba1c, uacr, model)
  h_stroke <- calculate_prevent_hazard(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking, egfr, statin_use, antihyp_use, bmi, hba1c, "stroke", use_hba1c, uacr, model)
  h_chd / (h_chd + h_stroke)
}

#' Calculate Annual Non-CV Mortality Hazard
#'
#' @description
#' US life table based background mortality (non-CV). Uses Gompertz parameterization
#' to approximate CDC NVSS 2022 life tables.
#'
#' @param age Numeric, age in years
#' @param sex Integer, 1 for male, 0 for female
#'
#' @return Numeric, annual non-CV mortality hazard rate
#' @export
calculate_annual_noncv_mortality <- function(age, sex) {
  # Gompertz parameterization approximating CDC NVSS 2022
  lambda <- ifelse(sex == 1,
                   0.0001 * exp(0.085 * age),
                   0.00006 * exp(0.088 * age))
  return(lambda)
}

#' Calculate Annual CV Mortality Hazard
#'
#' @description
#' CV-specific mortality hazard based on a proportion of all-cause mortality,
#' with multipliers for prior history and CKD stage. Multiplier defaults are the
#' base-case values; the model passes the (PSA/DSA-varied) parameters.
#'
#' @param age Numeric, age in years
#' @param sex Integer, 1 for male, 0 for female
#' @param prior_mi Integer, 1 if prior MI, 0 otherwise
#' @param prior_stroke Integer, 1 if prior stroke, 0 otherwise
#' @param prior_hf Integer, 1 if prior HF, 0 otherwise
#' @param ckd_stage Integer, CKD stage (1, 3, 4, 5)
#' @param mult_mi,mult_stroke,mult_hf Multipliers for prior events
#' @param mult_ckd3,mult_ckd4,mult_eskd Multipliers by CKD stage
#'
#' @return Numeric, annual CV mortality hazard rate
#' @export
calculate_annual_cv_mortality <- function(age, sex, prior_mi, prior_stroke, prior_hf, ckd_stage,
                                          mult_mi = 2.0, mult_stroke = 2.5, mult_hf = 3.0,
                                          mult_ckd3 = 1.5, mult_ckd4 = 2.5, mult_eskd = 4.0,
                                          bg_mult = 1) {
  # Base CV mortality is derived assuming 30% of all-cause mortality is CV
  # Thus, CV = (0.3 / 0.7) * Non-CV. bg_mult scales background mortality
  # (bg_mort_mult; 0.7 reads the Gompertz hazard as all-cause mortality)
  non_cv <- calculate_annual_noncv_mortality(age, sex)
  base_cv <- (0.3 / 0.7) * non_cv * bg_mult

  multiplier <- 1.0
  multiplier <- multiplier * ifelse(prior_mi == 1, mult_mi, 1.0)
  multiplier <- multiplier * ifelse(prior_stroke == 1, mult_stroke, 1.0)
  multiplier <- multiplier * ifelse(prior_hf == 1, mult_hf, 1.0)

  ckd_mult <- ifelse(ckd_stage >= 5, mult_eskd,
                     ifelse(ckd_stage == 4, mult_ckd4,
                            ifelse(ckd_stage == 3, mult_ckd3, 1.0)))

  return(base_cv * multiplier * ckd_mult)
}

#' Untreated event hazards for the current patient state
#'
#' @description Single entry point used at baseline and whenever the patient
#'   state changes (ageing, biomarker drift, eGFR decline, new events). Returns
#'   hazards WITHOUT recurrence or treatment multipliers; see
#'   `total_event_hazards()` in 04_treatment.R for those.
#'
#' @param cvd_mult Named numeric: mi, stroke, hf, ckd3, ckd4, eskd multipliers
#' @return Named numeric: mi, stroke, hf_hosp, death_cv
#' @param bg_mult Multiplier on background (CV) mortality (bg_mort_mult)
#' @param age_cap Age used in the PREVENT equations is min(age, age_cap)
#' @param hf_frac Share of PREVENT incident HF that is a hospitalization
#' @param uacr Baseline UACR (mg/g), used by the full model
#' @param prevent_full 1 = PREVENT full model (UACR + HbA1c), 0 = HbA1c model
calculate_base_hazards <- function(age, sex, sbp, total_chol, hdl_chol, diabetes, smoking,
                                   egfr, statin_use, antihyp_use, bmi, hba1c,
                                   prior_mi, prior_stroke, prior_hf, ckd_stage, cvd_mult,
                                   bg_mult = 1, age_cap = Inf, hf_frac = 1,
                                   uacr = NULL, prevent_full = 0) {
  age_p <- min(age, age_cap)
  mdl <- if (prevent_full == 1) "full" else "hba1c"
  h_ascvd <- calculate_annual_ascvd_hazard(age_p, sex, sbp, total_chol, hdl_chol, diabetes, smoking,
                                           egfr, statin_use, antihyp_use, bmi, hba1c, uacr = uacr, model = mdl)
  mi_share <- calculate_mi_share(age_p, sex, sbp, total_chol, hdl_chol, diabetes, smoking,
                                 egfr, statin_use, antihyp_use, bmi, hba1c, uacr = uacr, model = mdl)
  h_hf <- calculate_annual_hf_hazard(age_p, sex, bmi, sbp, egfr, hba1c, diabetes, smoking,
                                     antihyp_use, total_chol, hdl_chol, statin_use, uacr = uacr, model = mdl)
  h_cvd <- calculate_annual_cv_mortality(age, sex, prior_mi, prior_stroke, prior_hf, ckd_stage,
                                         cvd_mult[["mi"]], cvd_mult[["stroke"]], cvd_mult[["hf"]],
                                         cvd_mult[["ckd3"]], cvd_mult[["ckd4"]], cvd_mult[["eskd"]],
                                         bg_mult)
  c(mi = h_ascvd * mi_share, stroke = h_ascvd * (1 - mi_share), hf_hosp = h_hf * hf_frac,
    death_cv = h_cvd)
}

#' Get CKD Stage from eGFR
#'
#' @description
#' Converts continuous eGFR value to discrete CKD stage (1-2, 3, 4, 5).
#'
#' @param egfr Numeric, eGFR
#'
#' @return Integer, CKD stage (1, 3, 4, 5)
#' @export
get_ckd_stage_from_egfr <- function(egfr) {
  stage <- ifelse(egfr >= 60, 1L,
                  ifelse(egfr >= 30, 3L,
                         ifelse(egfr >= 15, 4L, 5L)))
  return(stage)
}
