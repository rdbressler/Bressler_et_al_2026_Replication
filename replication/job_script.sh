#!/bin/bash

#SBATCH --job-name=scc
#SBATCH --partition=pi_econ_lp
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=2-
#SBATCH --mem=10GB
#SBATCH --cpus-per-task=10


# Run the Julia script with the passed arguments
julia main.jl "$ARGS"