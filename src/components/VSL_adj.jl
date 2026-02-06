using Mimi

# Calculate the value of a statistical life
# follows equations from FUND 

@defcomp VSL_adj begin
    country       = Index()

    α             = Parameter(unit = "US\$2005")    # VSL scaling parameter
    ϵ             = Parameter()                     # Income elasticity of the value of a statistical life.
    y₀            = Parameter(unit = "US\$2005")    # Normalization constant.
    pc_gdp        = Parameter(index=[time, country], unit = "US\$2005/yr/person") # Country-level per capita GDP ($/person).
    global_pc_gdp = Parameter(index=[time], unit = "US\$2005/yr/person") 
    vsl_type      = Parameter{Symbol}(default = :country_level)
    
    vsl = Variable(index=[time, country], unit = "US\$2005/yr") # Value of a statistical life ($).
    us_gdp_pc = Variable(index=[time], unit = "US\$2005/yr") 


    function run_timestep(p, v, d, t)
        v.us_gdp_pc[t] = p.pc_gdp[t,174] #174 is the index for USA

        for c in d.country
            
            if p.vsl_type == :country_level
                v.vsl[t,c] = p.α * (p.pc_gdp[t,c] / p.y₀) ^ p.ϵ
            elseif p.vsl_type == :global_average
                v.vsl[t,c] = p.α * (p.global_pc_gdp[t] / p.y₀) ^ p.ϵ
            elseif p.vsl_type == :US_average
                v.vsl[t,c] = p.α * (v.us_gdp_pc[t] / p.y₀) ^ p.ϵ 
            else
                error("Invalid vsl_type argument")
            end
            
        end
    end
end
