
# ------------------------------------------------------------------------------------------------
# Stage 3: elementID not found in Laboratory Data (Certificates). Potential systematic error (prefix/suffix)

IDX.client <- DATA.client[, .(jobID, elementID, standardID, unitID)] |> unique()
IDX.lab <- INDEX.lab[, .(jobID, elementID, standardID, unitID)] |> unique()
COLS <- intersect(names(IDX.client), names(IDX.lab))
# > COLS
# [1] "jobID"      "elementID"  "standardID" "unitID"


# observations that do not exist in lab data
IDX.missing <- IDX.client[!IDX.lab, on = COLS] |> unique()
# > nrow(IDX.missing)
# [1] 2544


# ---------------------------------------------------------------------------------------
# Compare valueID for the same (jobID)
IDX.client <- DATA.client[, .(jobID,elementID,standardID,unitID,valueID.client = paste0(elementID,"_",standardID,"_",unitID))] |> unique()
IDX.lab <- INDEX.lab[, .(jobID,elementID,standardID,unitID,valueID.lab = paste0(elementID,"_",standardID,"_",unitID))] |> unique()
COLS <- intersect(names(IDX.client), names(IDX.lab))
IDX.client[IDX.lab, on = COLS][valueID.client == valueID.lab] |> unique()

IDX.client[IDX.lab, on = COLS][valueID.client != valueID.lab] |> unique()
# > IDX.client[IDX.lab, on = COLS][unitID.client!=unitID.lab] |> unique()
#           jobID elementID standardID unitID.client unitID.lab
#          <char>    <char>     <char>        <char>     <char>
#    1: SOL016682        Au      FAAAS           ppm         gt
#    2: SOL016682        Au        FAG           ppm         gt
#    3: SOL017417        Au      FAAAS           ppm         gt
#    4: SOL017417        Au        FAG           ppm         gt
#    5: SOL018008        Au      FAAAS           ppm         gt
#   ---
# 2535: SOL025130        Au        FAG           ppm         gt
# 2536: SOL025145        Au      FAAAS           ppm         gt
# 2537: SOL025145        Au        FAG           ppm         gt
# 2538: SOL025146        Au      FAAAS           ppm         gt
# 2539: SOL025146        Au        FAG           ppm         gt



# ---------------------------------------------------------------------------------------
# Compare units for the same (jobID, elementID, standardID)
IDX.client <- DATA.client[, .(jobID, elementID, standardID, unitID.client = unitID)] |> unique()
IDX.lab <- INDEX.lab[, .(jobID, elementID, standardID, unitID.lab = unitID)] |> unique()
COLS <- intersect(names(IDX.client), names(IDX.lab))
IDX.client[IDX.lab, on = COLS][unitID.client != unitID.lab] |> unique()
# > IDX.client[IDX.lab, on = COLS][unitID.client!=unitID.lab] |> unique()
#           jobID elementID standardID unitID.client unitID.lab
#          <char>    <char>     <char>        <char>     <char>
#    1: SOL016682        Au      FAAAS           ppm         gt
#    2: SOL016682        Au        FAG           ppm         gt
#    3: SOL017417        Au      FAAAS           ppm         gt
#    4: SOL017417        Au        FAG           ppm         gt
#    5: SOL018008        Au      FAAAS           ppm         gt
#   ---
# 2535: SOL025130        Au        FAG           ppm         gt
# 2536: SOL025145        Au      FAAAS           ppm         gt
# 2537: SOL025145        Au        FAG           ppm         gt
# 2538: SOL025146        Au      FAAAS           ppm         gt
# 2539: SOL025146        Au        FAG           ppm         gt

# ---------------------------------------------------------------------------------------
# Compare standards for the same (jobID, elementID, unitID)
IDX.client <- DATA.client[, .(jobID, elementID, unitID, standardID.client = standardID)] |> unique()
IDX.lab <- INDEX.lab[, .(jobID, elementID, unitID, standardID.lab = standardID)] |> unique()
COLS <- intersect(names(IDX.client), names(IDX.lab))
IDX.client[IDX.lab, on = COLS][standardID.client != standardID.lab] |> unique()
> IDX.client[IDX.lab, on = COLS][standardID.client != standardID.lab] |> unique()
           jobID elementID unitID standardID.client standardID.lab
          <char>    <char> <char>            <char>         <char>
  1: ABR0083.R24        Au    ppm           G0014R3          G0108
  2: ABR0083.R24        Au    ppm             G0108        G0014R3
  3: ABR0296.R24        Au    ppm           G0014R3          G0108
  4: ABR0296.R24        Au    ppm             G0108        G0014R3
  5: AGO0094.R23        Au    ppm           G0014R3          G0108
 ---
156: SEP0062.R23        Ag    ppm            G0587R          G0886
157: SEP0366.R23        Au    ppm           G0014R3          G0108
158: SEP0366.R23        Au    ppm             G0108        G0014R3
159:   SOL022768        Ag    ozt               FAG           AASR
160:   SOL022768        Ag    ozt              AASR            FAG


# Compare values for the same (jobID, elementID, standardID)

