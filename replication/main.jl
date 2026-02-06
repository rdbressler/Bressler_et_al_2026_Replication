using MimiGIVE, Mimi, DataFrames, CSVFiles, Query, Statistics, Printf, Random, JSON

include("../src/main_model.jl")
include("../src/mcs.jl")
include("../src/scc.jl")
include("../replication/price_level_inflator.jl")


# ===== SETUP ============
output_dir = joinpath(@__DIR__, "output")
mkpath(output_dir)

seed = 24523438
num_trials = 10

# ===== DISCOUNT RATE SETUP ============
# Define a mapping from identifiers to JSON configurations
function get_rate_config(rate_id)
    if rate_id == "rate1" #Main
        return "{\"label\":\"unweighted_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate2" #Secondary
        return "{\"label\":\"unweighted_eta_1.4_rho_.1\",\"prtp\":0.001,\"eta\":1.4,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate3" #Implied A4
        return "{\"label\":\"unweighted_eta_1.4_rho_0\",\"prtp\":0,\"eta\":1.4,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate4" #EPA SC-GHG
        return "{\"label\":\"unweighted_eta_1.24_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.244458999,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate5" #Germany
        return "{\"label\":\"unweighted_eta_1_rho_1\",\"prtp\":0.01,\"eta\":1,\"ew\":null,\"ew_norm_region\":null}"

    elseif rate_id == "rate6" #Secondary
        return "{\"label\":\"weighted_globe_eta_1.4_rho_.1\",\"prtp\":0.001,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate7" #Implied A4
        return "{\"label\":\"weighted_globe_eta_1.4_rho_0\",\"prtp\":0,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate8" #EPA SC-GHG
        return "{\"label\":\"weighted_globe_eta_1.24_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.244458999,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate9" #Germany
        return "{\"label\":\"weighted_globe_eta_1_rho_1\",\"prtp\":0.01,\"eta\":1,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"

    elseif rate_id == "rate10" #Figure 4
        return "{\"label\":\"unweighted_eta_1_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate11" #Figure 4
        return "{\"label\":\"unweighted_eta_1.25_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.25,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate12" #Figure 4
        return "{\"label\":\"unweighted_eta_1.75_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.75,\"ew\":null,\"ew_norm_region\":null}"
    elseif rate_id == "rate13" #Figure 4
        return "{\"label\":\"unweighted_eta_2_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":2,\"ew\":null,\"ew_norm_region\":null}"

    elseif rate_id == "rate14" #Figure 4
        return "{\"label\":\"weighted_globe_eta_1_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate15" #Figure 4
        return "{\"label\":\"weighted_globe_eta_1.25_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.25,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate16" #Figure 4/Main
        return "{\"label\":\"weighted_globe_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate17" #Figure 4
        return "{\"label\":\"weighted_globe_eta_1.75_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.75,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"
    elseif rate_id == "rate18" #Figure 4
        return "{\"label\":\"weighted_globe_eta_2_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":2,\"ew\":\":gdp\",\"ew_norm_region\":\"globe\"}"

    elseif rate_id == "rate19" #Table 1
        return "{\"label\":\"weighted_USA_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"USA\"}"
    elseif rate_id == "rate20" #Table 1
        return "{\"label\":\"weighted_CHN_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"CHN\"}"
    elseif rate_id == "rate21" #Table 1
        return "{\"label\":\"weighted_IND_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"IND\"}"
    elseif rate_id == "rate22" #Table 1
        return "{\"label\":\"weighted_COD_eta_1.4_rho_.2\",\"prtp\":0.0019745879362491614,\"eta\":1.4,\"ew\":\":gdp\",\"ew_norm_region\":\"COD\"}"
    else
        error("Unknown rate identifier: $rate_id")
    end
end

# Use the identifier to get the JSON string
rate_id = ARGS[1]
json_config = get_rate_config(rate_id)

# Parse the JSON configuration
args = JSON.parse(json_config)

#Ensure ew is read as a symbol
if haskey(args, "ew") && args["ew"] == ":gdp"
    args["ew"] = :gdp
end
println("Discount Rate: ", args)

# Extract parameters from the arguments
label = args["label"]
prtp = args["prtp"]
eta = args["eta"]
# Extract other parameters if needed
ew = get(args, "ew", nothing)
ew_norm_region = get(args, "ew_norm_region", nothing)
# Prepare discount_rates for compute_scc
discount_rates = [(label=label, prtp=prtp, eta=eta)]
if ew !== nothing && ew_norm_region !== nothing
    discount_rates = [(label=label, prtp=prtp, eta=eta, ew=ew, ew_norm_region=ew_norm_region)]
end

# ===== COMPUTE SCC ============
m = get_modified_model(income_heat_vulnerability_reduction=true)
#update_param!(m, :DamageAggregator, :include_slr, false) # for speed remove slr calculations, note do not do this for finals runs
println("Model Compiled")

Random.seed!(seed)

#Compute SCC
results = compute_scc(m;
    year=2020,
    last_year=2300,
    discount_rates=discount_rates,
    n=num_trials,
    output_dir=output_dir,
    compute_sectoral_values=true
)

#Save SCCs
df_final = DataFrame(scc=Float64[], sector=Symbol[], dr=String[])
for (k, v) in results[:scc]
    df = DataFrame(scc=v.sccs .* pricelevel_2005_to_2020)
    df[!, :sector] .= k.sector
    df[!, :dr] .= k.dr_label
    append!(df_final, df)
end
df_final |> save(joinpath(output_dir, "scc_dr_$(label).csv"))



