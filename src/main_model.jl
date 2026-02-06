using Mimi
using MimiGIVE

include("components/temperature_mortality_component.jl")
include("components/DamageAggregator_BresslerMortality.jl")
include("components/VSL_adj.jl")
include("components/TempMortality_PatternScaling.jl")
include("helper_functions.jl")

function get_modified_model(;   Agriculture_gtap::String = "midDF",
                                socioeconomics_source::Symbol = :RFF,
                                SSP_scenario::Union{Nothing, String} = nothing,       
                                RFFSPsample::Union{Nothing, Int} = nothing,
                                Agriculture_floor_on_damages::Bool = true,
                                Agriculture_ceiling_on_benefits::Bool = false,
                                vsl::Symbol= :epa,
                                vsl_type::Symbol = :country_level,
                                cold_model::Union{Nothing, String} = "3",
                                heat_model::Union{Nothing, String} = "4",
                                mortality_type::Symbol = :Bressler,
                                income_heat_vulnerability_reduction::Bool = true #default to main specification in Bressler et al (2021) - including the protective effects of income) 
                                )

    # start with MimiGIVE model
    m = MimiGIVE.get_model(Agriculture_gtap = Agriculture_gtap,
                            socioeconomics_source = socioeconomics_source,
                            SSP_scenario = SSP_scenario,       
                            RFFSPsample = RFFSPsample,
                            Agriculture_floor_on_damages = Agriculture_floor_on_damages,
                            Agriculture_ceiling_on_benefits  = Agriculture_ceiling_on_benefits,
                            vsl = vsl)

    # helper data and variables 
    data = load_bressler_data(cold_model= cold_model, heat_model= heat_model)
    cmip6_gcm_ids       = unique((load(joinpath(@__DIR__, "..", "data", "PatternScaling_cmip6", "PatternScaling_cmip6_pattern_scaling_by_country.csv")) |> DataFrame).source_id)
    damages_first = 2020 # first year to accumulate damages

    # --------------------------------------------------------------------------
    # Adding new components
    # --------------------------------------------------------------------------

    add_comp!(m, MimiGIVE.GlobalTempNorm, :TempNorm_2001to2020, after = :temperature); # Bressler Mortality
    add_comp!(m, TempMortality_PatternScaling, :TempMortality_PatternScaling, first = damages_first, after = :OceanPH); # Scale global temperature to country temperature
    add_comp!(m, BresslerMortality, first = damages_first, after = :energy_damages);
    
    # add dimensions
    set_dimension!(m, :cmip6_gcms, cmip6_gcm_ids);  # TempMortality Pattern Scaling component

    # --------------------------------------------------------------------------
    # TempNorm_2001to2020
    # --------------------------------------------------------------------------

	# Normalize temperature to deviation from 2001 to 2020 for Bressler Mortality Component
    update_param!(m, :TempNorm_2001to2020, :norm_range_start, 2001)
    update_param!(m, :TempNorm_2001to2020, :norm_range_end, 2020)
    connect_param!(m, :TempNorm_2001to2020 => :global_temperature, :temperature => :T)

    # --------------------------------------------------------------------------
    # TempMortality_PatternScaling
    # --------------------------------------------------------------------------

    # Baseline mortality use SSP2 as a proxy for SSP4 and SSP1 as a proxy for 
    # SSP5 per instructions from the literature
    mortality_SSP_map = Dict("SSP1" => "SSP1", "SSP2" => "SSP2", "SSP3" => "SSP3", "SSP4" => "SSP2", "SSP5" => "SSP1")

    # Grab the SSP name from the full scenario ie. SSP2 from SSP245
    SSP = socioeconomics_source == :SSP ? SSP_scenario[1:4] : nothing

    if socioeconomics_source == :SSP_scenario # use the mortality SSP map to get the right pattern
        pattern = load(joinpath(@__DIR__, "..", "data", "PatternScaling_cmip6", "PatternScaling_cmip6_patterns_pop_2000_$(mortality_SSP_map[SSP]).csv")) |> DataFrame   
    else # use SSP2 for RFF
        pattern = load(joinpath(@__DIR__, "..", "data", "PatternScaling_cmip6", "PatternScaling_cmip6_patterns_pop_2000_SSP2.csv")) |> DataFrame   
    end

    model_indices = indexin(dim_keys(m, :country), pattern.iso3) # Find pattern-scaling indices corresponding to countries in mortality components and subset pattern.
    isempty(findall(i -> isnothing(i), model_indices)) ? nothing : error("Not every country was found in the pattern scaling file.") # make sure all countries are found
          
    update_param!(m, :TempMortality_PatternScaling, :pattern, pattern[model_indices, 2:end] |> Matrix)
	connect_param!(m, :TempMortality_PatternScaling => :global_temperature, :TempNorm_2001to2020 => :global_temperature_norm)

    # --------------------------------------------------------------------------
    # VSL (REPLACE)
    # --------------------------------------------------------------------------

    # Replace VSL component with modified one
    replace!(m, :VSL => VSL_adj)

    # Need to set this VSL component to run from 2020 to 2300, currently picks up
    # 1750 to 2300 from replace!
    Mimi.set_first_last!(m, :VSL, first=2020);

    update_param!(m, :VSL, :vsl_type, vsl_type)
    connect_param!(m, :VSL => :global_pc_gdp, :PerCapitaGDP => :global_pc_gdp)

    # --------------------------------------------------------------------------
    # BresslerMortality
    # --------------------------------------------------------------------------

    # Allow heat mortality function to differ based on fixed income adjustment (default false)
    if income_heat_vulnerability_reduction == true
        update_param!(m, :BresslerMortality, :income_heat_vulnerability_reduction, true)
    else 
        update_param!(m, :BresslerMortality, :income_heat_vulnerability_reduction, false)
    end

	# Set temperature-mortality parameters specific to Bressler et al
	update_param!(m, :BresslerMortality, :β_cold, data[:β_cold])
	update_param!(m, :BresslerMortality, :β_heat, data[:β_heat])
	update_param!(m, :BresslerMortality, :coldest_month, data[:coldest_month])
	update_param!(m, :BresslerMortality, :hottest_month, data[:hottest_month])

    # Connections
    connect_param!(m, :BresslerMortality => :pc_gdp, :PerCapitaGDP => :pc_gdp)
    connect_param!(m, :BresslerMortality => :gdp, :Socioeconomic => :gdp)
    connect_param!(m, :BresslerMortality => :population,  :Socioeconomic => :population)
    connect_param!(m, :BresslerMortality => :vsl, :VSL => :vsl)
    connect_param!(m, :BresslerMortality => :temperature, :TempMortality_PatternScaling => :local_temperature)

    # Baseline mortality rate connection changes based on whether we run under RFFSPs or SSPs
    if socioeconomics_source == :SSP 
        connect_param!(m, :BresslerMortality, :baseline_mortality_rate, :model_ssp_baseline_mortality_rate)
    else
        connect_param!(m, :BresslerMortality => :baseline_mortality_rate, :Socioeconomic => :deathrate)
    end

    # --------------------------------------------------------------------------
    # DamageAggregator (REPLACE)
    # --------------------------------------------------------------------------

    # Replace Damage Aggregator component with modified one
    replace!(m, :DamageAggregator => DamageAggregator_BresslerMortality)

    # Need to set this damage aggregator to run from 2020 to 2300, currently picks up
    # 1750 to 2300 from replace!
    Mimi.set_first_last!(m, :DamageAggregator, first=2020);

    # Connect to damage aggregator
    connect_param!(m, :DamageAggregator => :damage_bressler_mortality, :BresslerMortality => :mortality_costs_net)
    
    # --------------------------------------------------------------------------
    # Run with Cromar or Bressler Mortality
    # --------------------------------------------------------------------------

    if mortality_type == :Bressler
        update_param!(m, :DamageAggregator, :include_cromar_mortality, false)
    elseif mortality_type == :Cromar
        update_param!(m, :DamageAggregator, :include_bressler_mortality, false)
    end
    
    return m
end

