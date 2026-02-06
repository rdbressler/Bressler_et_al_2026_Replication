using Mimi

# --------------------------------------------------
# Temperature Mortality from Bressler et al. 2021
# --------------------------------------------------

function cold_mort(β_cold, temperature, coldest_month, pc_gdp)
    return β_cold[1] * temperature + β_cold[2] * temperature^2 + β_cold[3] * temperature * coldest_month + β_cold[4] * temperature * coldest_month * log(pc_gdp)
end

function heat_mort(β_heat, temperature, hottest_month, pc_gdp)
    return β_heat[1] * temperature + β_heat[2] * temperature^2 + β_heat[3] * temperature * hottest_month + β_heat[4] * temperature * hottest_month * log(pc_gdp)
end
@defcomp BresslerMortality begin

    country = Index()                                    # Mimi dimension for individual countries.

    income_heat_vulnerability_reduction = Parameter{Bool}(default=true)  # Option to run the Bressler mortality damage function both with and without accounting for the projected benefits of higher incomes on reducing vulnerability to heat (See Table 5a in Bressler et al.).

    β_cold = Parameter(index=[4])             # Coefficients for cold-model specification (from Table 2 in Bressler et al.).
    β_heat = Parameter(index=[4])             # Coefficients for heat-model specification (from Table 1 in Bressler et al.).
    coldest_month = Parameter(index=[country])       # Current population-weighted average temperature in the coldest month in a given country (°C).
    hottest_month = Parameter(index=[country])       # Current population-weighted average temperature in the hottest month in a given country (°C).
    pc_gdp = Parameter(index=[time, country]) # Current per-capita GDP in a given country ($).
    gdp = Parameter(index=[time, country], unit="billion US\$2005/yr") # Current GDP in a given country ($).
    baseline_mortality_rate = Parameter(index=[time, country], unit="deaths/1000 persons/yr") # Crude death rate in a given country (deaths per 1,000 population).
    population = Parameter(index=[time, country]) # Population in a given country (millions of persons).
    temperature = Parameter(index=[time, country], unit="degC") # Local average surface temperature anomaly relative to the 2001-2020 average (°C).
    vsl = Parameter(index=[time, country]) # Value of a statistical life ($).

    mortality_cold = Variable(index=[time, country])  # Percentage change in a country's baseline mortality rate due to cold (%, with positive values indicating increasing mortality rates).
    mortality_heat = Variable(index=[time, country])  # Percentage change in a country's baseline mortality rate due to heat (%, with positive values indicating increasing mortality rates).
    mortality_net_change = Variable(index=[time, country])  # Percentage change in a country's baseline mortality rate due to combined effects of cold and heat (%, with positive values indicating increasing mortality rates).
    excess_death_rate_cold = Variable(index=[time, country])  # Change in a country's baseline death rate due to cold (additional deaths per 1,000 population).
    excess_death_rate_heat = Variable(index=[time, country])  # Change in a country's baseline death rate due to heat (additional deaths per 1,000 population).
    excess_death_rate_net = Variable(index=[time, country])  # Change in a country's baseline death rate due to combined effects of cold and heat (additional deaths per 1,000 population).
    excess_deaths_cold = Variable(index=[time, country])  # Additional deaths that occur in a country due to cold (individual persons).
    excess_deaths_heat = Variable(index=[time, country])  # Additional deaths that occur in a country due to heat (individual persons).
    excess_deaths_net = Variable(index=[time, country])  # Additional deaths that occur in a country due to the combined effects of cold and heat (individual persons).
    mortality_costs_cold = Variable(index=[time, country])  # Costs of temperature mortality from cold based on the VSL ($).
    mortality_costs_heat = Variable(index=[time, country])  # Costs of temperature mortality from heat based on the VSL ($).
    mortality_costs_net = Variable(index=[time, country])  # Costs of temperature mortality from combined effects of cold and heat based on the VSL ($).

    cold_T_start_constant_subdomain = Variable(index=[time, country]) # Temperature at which the cold mortality model starts increasing in higher temperatures holding all else (including income) constant.
    heat_T_start_constant_subdomain = Variable(index=[time, country]) # Temperature at which the heat mortality model starts decreasing in higher temperatures holding all else (including income) constant.

    function run_timestep(p, v, d, t)

        for c in d.country

            #COLD

            # Use the partial derivative of the cold model to calculate the argmin temperature at which the cold mortality model starts increasing in higher temperatures holding all else (including income) constant.
            v.cold_T_start_constant_subdomain[t, c] = -(p.β_cold[1] + p.β_cold[3] * p.coldest_month[c] + p.β_cold[4] * p.coldest_month[c] * log(p.pc_gdp[t, c])) / (2 * p.β_cold[2])

            # Use a piecewise function so that if the partial derivative wrt cold is positive, then hold at the argmin temperature.

            if (p.temperature[t, c]) <= v.cold_T_start_constant_subdomain[t, c]
                v.mortality_cold[t, c] = cold_mort(p.β_cold, (p.temperature[t, c]), p.coldest_month[c], p.pc_gdp[t, c])
            else
                v.mortality_cold[t, c] = cold_mort(p.β_cold, v.cold_T_start_constant_subdomain[t, c], p.coldest_month[c], p.pc_gdp[t, c])
            end

            # Calculate percentage change in a country's baseline mortality rate due to cold. Use if statement to account for extreme Monte Carlos where future temperatures decrease.
            if (p.temperature[t, c]) >= 0
                v.mortality_cold[t, c] = min(0.0, p.β_cold[1] * (p.temperature[t, c]) + p.β_cold[2] * (p.temperature[t, c])^2 + p.β_cold[3] * (p.temperature[t, c]) * p.coldest_month[c] + p.β_cold[4] * (p.temperature[t, c]) * p.coldest_month[c] * log(p.pc_gdp[t, c]))
            else
                v.mortality_cold[t, c] = min(0.0, p.β_cold[1] * (p.temperature[t, c]) - p.β_cold[2] * (p.temperature[t, c])^2 + p.β_cold[3] * (p.temperature[t, c]) * p.coldest_month[c] + p.β_cold[4] * (p.temperature[t, c]) * p.coldest_month[c] * log(p.pc_gdp[t, c]))
            end
           
            #HEAT

            # Use the partial derivative of the heat model to calculate the argmax temperature at which the heat mortality model starts decreasing in higher temperatures holding all else (including income) constant.

            v.heat_T_start_constant_subdomain[t, c] = -(p.β_heat[1] + p.β_heat[3] * p.hottest_month[c] + p.β_heat[4] * p.hottest_month[c] * log(p.pc_gdp[t, c])) / (2 * p.β_heat[2])

            # Use a piecewise function so that if the partial derivative wrt heat is negative, then hold at the argmax temperature.
            if (p.temperature[t, c]) >= v.heat_T_start_constant_subdomain[t, c]
                v.mortality_heat[t, c] = heat_mort(p.β_heat, (p.temperature[t, c]), p.hottest_month[c], p.pc_gdp[t, c])
            else
                v.mortality_heat[t, c] = heat_mort(p.β_heat, v.heat_T_start_constant_subdomain[t, c], p.hottest_month[c], p.pc_gdp[t, c])
            end

            # Calculate percentage change in a country's baseline mortality rate due to heat, allow to differ based on fixed income adjustment or not.
            # Use if statement to account for extreme Monte Carlos where future temperatures decrease.
            if (p.temperature[t, c]) >= 0
                if p.income_heat_vulnerability_reduction === true
                    v.mortality_heat[t, c] = max(0.0, p.β_heat[1] * (p.temperature[t, c]) + p.β_heat[2] * (p.temperature[t, c])^2 + p.β_heat[3] * (p.temperature[t, c]) * p.hottest_month[c] + p.β_heat[4] * (p.temperature[t, c]) * p.hottest_month[c] * log(p.pc_gdp[t, c]))
                else
                    v.mortality_heat[t, c] = max(0.0, p.β_heat[1] * (p.temperature[t, c]) + p.β_heat[2] * (p.temperature[t, c])^2 + p.β_heat[3] * (p.temperature[t, c]) * p.hottest_month[c] + p.β_heat[4] * (p.temperature[t, c]) * p.hottest_month[c] * log(p.pc_gdp[TimestepValue(2020), c]))
                end
            else
                if p.income_heat_vulnerability_reduction === true
                    v.mortality_heat[t, c] = max(0.0, p.β_heat[1] * (p.temperature[t, c]) - p.β_heat[2] * (p.temperature[t, c])^2 + p.β_heat[3] * (p.temperature[t, c]) * p.hottest_month[c] + p.β_heat[4] * (p.temperature[t, c]) * p.hottest_month[c] * log(p.pc_gdp[t, c]))
                else
                    v.mortality_heat[t, c] = max(0.0, p.β_heat[1] * (p.temperature[t, c]) - p.β_heat[2] * (p.temperature[t, c])^2 + p.β_heat[3] * (p.temperature[t, c]) * p.hottest_month[c] + p.β_heat[4] * (p.temperature[t, c]) * p.hottest_month[c] * log(p.pc_gdp[TimestepValue(2020), c]))
                    #
                end
            end

            # Calculate percentage change in a country's baseline mortality rate due to combined effects of cold and heat.
            v.mortality_net_change[t, c] = v.mortality_cold[t, c] + v.mortality_heat[t, c]

            # Calculate additional deaths per 1,000 population due to cold, heat, and net effect (divide by 100 because mortality changes above given as percentages).
            v.excess_death_rate_cold[t, c] = p.baseline_mortality_rate[t, c] * (v.mortality_cold[t, c] / 100.0)
            v.excess_death_rate_heat[t, c] = p.baseline_mortality_rate[t, c] * (v.mortality_heat[t, c] / 100.0)
            v.excess_death_rate_net[t, c] = p.baseline_mortality_rate[t, c] * (v.mortality_net_change[t, c] / 100.0)

            # Calculate additional deaths that occur due to cold, heat, and net effect (assumes population units in millions of persons).
            v.excess_deaths_cold[t, c] = (p.population[t, c] * 1e3) * v.excess_death_rate_cold[t, c]
            v.excess_deaths_heat[t, c] = (p.population[t, c] * 1e3) * v.excess_death_rate_heat[t, c]
            v.excess_deaths_net[t, c] = (p.population[t, c] * 1e3) * v.excess_death_rate_net[t, c]

            # Multiply excess deaths by the VSL.
            v.mortality_costs_cold[t, c] = p.vsl[t, c] * v.excess_deaths_cold[t, c]
            v.mortality_costs_heat[t, c] = p.vsl[t, c] * v.excess_deaths_heat[t, c]
            v.mortality_costs_net[t,c]  = p.vsl[t,c] * v.excess_deaths_net[t,c]

        end
    end
end