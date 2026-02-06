using CSVFiles, DataFrames

"""
	load_bressler_data(;cold_model::String="3", heat_model::String="4")

This function loads example data to run the temperature-mortality model from Bressler et al. (2021),
"Estimating Country-Level Mortality Damage Functions." It loads the supplementary data from this study
in addition to UN population and mortality projections (medium fertility scenario). The data corresponds
to the two projection periods from Bressler et al. (2040-2059 and 2080-2099).

Function Arguments:
   cold_model:   Specification for cold-mortality model (options = "1", "2", "3", "4", see Table 2 in Bressler et al. for details).
   heat_model:   Specification for heat-mortality model (options = "1", "2", "3", "4", see Table 1 in Bressler et al. for details).
"""
function load_bressler_data(;cold_model::String="3", heat_model::String="4")

	# Initialze a dictionary to store cleaned up data.
	data = Dict{Symbol, Any}()

	#---------------------------
	# Load Bressler et al. Data
	#---------------------------

	datadir = joinpath(@__DIR__, "..", "data")

	# Load supplementary data from Bressler et al. (2021).
	raw_data = load(joinpath(datadir, "hottest_coldest_month_bressler_clean.csv")) |> DataFrame

	# Create variables for the hottest and coldest months (note: these do not vary with projection period or scenario).
	data[:hottest_month] = raw_data[:, "hottest_month"]
	data[:coldest_month] = raw_data[:, "coldest_month"]

	# Get heat model coefficients and select model specification (defaults to model specification #4 in Table 1 from Bressler et al.).
	heat_model_coefficients = DataFrame(load(joinpath(datadir, "heat_model_coefficients.csv"), skiplines_begin=8))
	data[:β_heat] = heat_model_coefficients[:, "specification_"*heat_model*"_coefficients"]

	# Get cold model coefficients and select model specification (defaults to model specification #3 in Table 2 from Bressler et al.).
	cold_model_coefficients = DataFrame(load(joinpath(datadir, "cold_model_coefficients.csv"), skiplines_begin=8))
	data[:β_cold] = cold_model_coefficients[:, "specification_"*cold_model*"_coefficients"]

	# Return cleaned up data.
	return data
end
