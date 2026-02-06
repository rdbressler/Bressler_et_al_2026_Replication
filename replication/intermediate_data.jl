using MimiGIVE, Mimi, DataFrames, CSVFiles, Query, Statistics, Printf, Random

function compute_intermediate_data(; num_trials::Int=10000,
    seed::Union{Nothing,Int}=nothing,
    output_dir::String=nothing,
    income_heat_vulnerability_reduction::Bool=true
)

    save_list = [
        (:BresslerMortality, :mortality_net_change),
        (:BresslerMortality, :excess_deaths_net)
    ]

    discount_rates = [(label="main", prtp=exp(0.001972641) - 1, eta=1.4)]
    Random.seed!(seed)

    m = get_modified_model(income_heat_vulnerability_reduction=income_heat_vulnerability_reduction)
    #update_param!(m, :DamageAggregator, :include_slr, false) # for speed remove slr calculations, note do not do this for finals runs
    println("Model Compiled")

    compute_scc(m;
        year=2020,
        last_year=2300,
        discount_rates=discount_rates,
        n=num_trials,
        output_dir=output_dir,
        save_list=save_list
    )
end


function save_intermediate_data(output_dir, income_heat_vulnerability_reduction)
    #MORTALITY RATE
    mortality_net_change = load(joinpath(output_dir, "results", "model_1", "BresslerMortality_mortality_net_change.csv")) |>
                           @filter(_.time >= 2020) |> DataFrame

    #aggregate
    agg = combine(groupby(mortality_net_change, [:time, :trialnum]), :mortality_net_change => mean)
    mortality_net_change_agg = combine(groupby(agg, :time),
        :mortality_net_change_mean => (x -> [quantile(x, 0.05)]) => [:q05],
        :mortality_net_change_mean => (x -> [mean(x)]) => [:mean],
        :mortality_net_change_mean => (x -> [quantile(x, 0.95)]) => [:q95])
    mortality_net_change_agg |> save(joinpath(output_dir, "mortality_net_change_income_$(income_heat_vulnerability_reduction).csv"))

    #by country
    mortality_net_change_by_country = combine(groupby(mortality_net_change, [:time, :country]),
        :mortality_net_change => (x -> [quantile(x, 0.05)]) => [:q05],
        :mortality_net_change => (x -> [mean(x)]) => [:mean],
        :mortality_net_change => (x -> [quantile(x, 0.95)]) => [:q95])
    mortality_net_change_by_country |> save(joinpath(output_dir, "mortality_net_change_by_country_income_$(income_heat_vulnerability_reduction).csv"))


    #EXCESS DEATHS
    excess_deaths = load(joinpath(output_dir, "results", "model_1", "BresslerMortality_excess_deaths_net.csv")) |>
                    @filter(_.time >= 2020) |> DataFrame

    #aggregate
    agg = combine(groupby(excess_deaths, [:time, :trialnum]), :excess_deaths_net => sum)
    excess_deaths_agg = combine(groupby(agg, :time),
        :excess_deaths_net_sum => (x -> [quantile(x, 0.05)]) => [:q05],
        :excess_deaths_net_sum => (x -> [mean(x)]) => [:mean],
        :excess_deaths_net_sum => (x -> [quantile(x, 0.95)]) => [:q95])
    excess_deaths_agg |> save(joinpath(output_dir, "excess_deaths_income_$(income_heat_vulnerability_reduction).csv"))

    #by country
    excess_deaths_by_country = combine(groupby(excess_deaths, [:time, :country]),
        :excess_deaths_net => (x -> [quantile(x, 0.05)]) => [:q05],
        :excess_deaths_net => (x -> [mean(x)]) => [:mean],
        :excess_deaths_net => (x -> [quantile(x, 0.95)]) => [:q95])
    excess_deaths_by_country |> save(joinpath(output_dir, "excess_deaths_by_country_income_$(income_heat_vulnerability_reduction).csv"))

    rm(joinpath(output_dir, "results"), recursive=true)
end



