#!/bin/bash

# Define an array of identifiers
discount_rates=("rate1" "rate2" "rate3" "rate4" "rate5" "rate6" "rate7" "rate8" "rate9" "rate10" "rate11" "rate12" "rate13" "rate14" "rate15" "rate16" "rate17" "rate18" "rate19" "rate20" "rate21" "rate22")

# Loop through each identifier and submit a job
for rate_id in "${discount_rates[@]}"; do
    echo "Submitting job for rate identifier: $rate_id"
    sbatch --export=ALL,ARGS="$rate_id" job_script.sh
done
 
