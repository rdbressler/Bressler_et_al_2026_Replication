using Mimi
using MimiGIVE
using Distributions
using Dates
using StatsBase
using LinearAlgebra
using PDMats

function sample_mortality_coefficients(n::Int)
    
    # Cold model
    #coefficients from cold model 3, flag only three here since the fourth coeff is zero
    μ_β_cold = [-1.44114; 0.198986; -0.0113227] 
    #variance-covariance matrix from cold model 3
    σ_β_cold = [0.01876749	0. 0.
                -0.00456457	0.00130528	0. 
                -0.00037881	0.00009383	0.00004624]                      
    
    # Heat model
    #coefficients from heat model 4
    μ_β_heat = [-0.531771, -0.0629332, 0.525104, -0.0408753] 
    #variance-covariance matrix from heat model 4
    σ_β_heat = [1.497007 0. 0. 0.			
                -0.02817277	0.00873646	0. 0.	
                0.02024908	0.0152027	0.04343176	0.
                -0.00862287	-0.00145899	-0.00447662	0.00049201]   

    # Convert var-cov matrices to be symmetric.
    covar_cold = Symmetric(coalesce.(σ_β_cold, 0.), :L)
    covar_heat = Symmetric(coalesce.(σ_β_heat, 0.), :L)
    
    # Sample from a multivariate normal for cold β terms for preferred model specification #3.
    # Note: Preferred cold model does not have a gdp interaction term (4th coefficient), so setting to 0.0.
    cold_sample = zeros(4,n)
    cold_sample[1:3,:] .= rand(MvNormal(μ_β_cold, PDMat(covar_cold)), n)
    
    # Sample from a multivariate normal for heat β terms for preferred model specification #4.
    heat_sample = rand(MvNormal(μ_β_heat, PDMat(covar_heat)), n)
    
    # Return samples.
    return cold_sample, heat_sample
end

function get_modified_mcs(trials; args...)
    
    mcs = MimiGIVE.get_mcs(trials; args...) # get the original MCS

    # add TempMortality uncertainty based on covariance matrix from Bressler et al.
    cold_sample, heat_sample = sample_mortality_coefficients(trials)        
    
    for coef in [1,2,3,4] # four coefficients defined with an anonymous dimension
        # Cold model
        rv_name = Symbol("rv_β_cold_$(coef)")
        Mimi.add_RV!(mcs, rv_name, Mimi.SampleStore(cold_sample[coef,:]))
        Mimi.add_transform!(mcs, :BresslerMortality, :β_cold, :(=), rv_name, [coef])
        # Heat model
        rv_name = Symbol("rv_β_heat_$(coef)")
        Mimi.add_RV!(mcs, rv_name, Mimi.SampleStore(heat_sample[coef,:]))
        Mimi.add_transform!(mcs, :BresslerMortality, :β_heat, :(=), rv_name, [coef])
    end

    # add uncertainty to the gcm used for pattern scaling
    rv_name = :rv_gcm_id
    Mimi.add_RV!(mcs, rv_name, Mimi.EmpiricalDistribution(collect(1:21)))
    Mimi.add_transform!(mcs, :TempMortality_PatternScaling, :gcm_id, :(=), rv_name)
    
    return mcs
end

function run_modified_mcs(;trials::Int64 = 10000, 
                            output_dir::Union{String, Nothing} = nothing, 
                            save_trials::Bool = false,
                            fair_parameter_set::Symbol = :random,
                            fair_parameter_set_ids::Union{Vector{Int}, Nothing} = nothing,
                            rffsp_sampling::Symbol = :random,
                            rffsp_sampling_ids::Union{Vector{Int}, Nothing} = nothing,
                            m::Mimi.Model = get_modified_model(), 
                            save_list::Vector = [],
                            results_in_memory::Bool = true,
                        )

    m = deepcopy(m) # in the case that an `m` was provided, be careful that we don't modify the original

    trials < 2 && error("Must run `run_mcs` function with a `trials` argument greater than 1 due to a Mimi specification about SampleStores.  TO BE FIXED SOON!")

    # Set up output directories
    output_dir = output_dir === nothing ? joinpath(@__DIR__, "output/mcs/", "MCS $(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) MC$trials") : output_dir
    isdir("$output_dir/results") || mkpath("$output_dir/results")

    trials_output_filename = save_trials ?  joinpath("$output_dir/trials.csv") : nothing

    socioeconomics_module = MimiGIVE._get_module_name(m, :Socioeconomic)
    if socioeconomics_module == :MimiSSPs
    socioeconomics_source = :SSP
    elseif socioeconomics_module == :MimiRFFSPs
    socioeconomics_source = :RFF
    end

    # Get an instance of the mcs
    mcs = get_modified_mcs(trials; 
        socioeconomics_source = socioeconomics_source, 
        mcs_years = Mimi.time_labels(m), 
        fair_parameter_set = fair_parameter_set, 
        fair_parameter_set_ids = fair_parameter_set_ids,
        rffsp_sampling = rffsp_sampling,
        rffsp_sampling_ids = rffsp_sampling_ids,
        save_list = save_list,
    )

    # run monte carlo trials
    results = run(mcs,
        m, 
        trials; 
        trials_output_filename = trials_output_filename, 
        results_output_dir = "$output_dir/results", 
        results_in_memory = results_in_memory
    )

    return results
end
