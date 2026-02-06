# Replication Code for Bressler et al. 2026

# Preparing the software environment

You need to install [Julia](https://julialang.org/) to run this model. We tested this code on Julia version 1.10.0. Figures and related analysis were produced in R version 4.3.2. 

Make sure to install Julia in such a way that the Julia binary is on the `PATH`.

Add the following packages to your current environment by running the following commands at the julia package REPL. This will ensure that the correct versions of the packages are installed for this analysis.

```julia
using Pkg
Pkg.add(name="Mimi", version="1.5.1")
Pkg.add(name="MimiGIVE", version="1.0.0")
```

Now restart Julia after installing the packages to ensure that the packages are properly loaded.

# Running the model and replication scripts

The full replication code below involves many runs in many specifications sampling across uncertainties in 10,000 Monte Carlo simulations. This takes significant computational time, and thus we recommend running on a high performance computer (HPC). We ran the output on Yale's Grace HPC. However, to produce the main income-weighted SCC results from the paper on a local machine, you can run the following code in the Julia REPL:

```julia
using Pkg
ENV["JULIA_PKG_IGNORE_HASHES"] = "1"
Pkg.activate(".")
empty!(ARGS); push!(ARGS, "rate19")
include("replication/main.jl")
```

To run the model to produce the data for the study, the following jobs should be submitted to an HPC, run from the replication directory:

```R
replication/submit_jobs.sh
replication/main_save_income_false.sh
replication/main_save_income_true.sh
```

This will run the main.jl file across all specifications and produce the output data required to make the figures and tables in the paper.

The following script reads in the output data to produce the figures and tables in the paper:

```R
replication/create_figures_tables.R
```


