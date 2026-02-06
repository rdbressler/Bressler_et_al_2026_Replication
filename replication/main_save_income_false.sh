#!/bin/bash

#SBATCH --job-name=income_false
#SBATCH --partition=pi_econ_lp
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --time=2-
#SBATCH --mem=64GB
#SBATCH --cpus-per-task=10

# Run your Julia script
julia main_income_false.jl

