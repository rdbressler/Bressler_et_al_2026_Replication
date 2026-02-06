include("../src/main_model.jl")
include("../src/mcs.jl")
include("../src/scc.jl")
include("../replication/intermediate_data.jl")
include("../replication/price_level_inflator.jl")

output_dir = joinpath(@__DIR__, "output", "income_true")

our_seed = 24523438
num_trials = 10_000

compute_intermediate_data(num_trials=num_trials, seed=our_seed, output_dir=output_dir,
    income_heat_vulnerability_reduction=true)

save_intermediate_data(output_dir, true)

