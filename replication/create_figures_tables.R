#  Create Figures and Tables for Mortality SCC Paper
#  By: Naomi Shimberg

# ====== SETUP =====
library(dplyr)
library(readr)
library(Hmisc)
library(ggplot2)
library(data.table)
library(dplyr)
library(dtplyr)
library(lubridate)
library(binsreg)
library(tidyquant)
library(readxl)
library(stargazer)
library(RColorBrewer)
library(reshape2) 
library(xtable)
library(countrycode)
library(viridis)
library(colorspace)
library(scales) 
library(RColorBrewer)
library(here)

rm(list = ls())
comb <- function(...) parse(text = paste0(...))
theme_set(theme_classic(base_family = "Times New Roman"))

#set working directory and path names
path <- here("output")
setwd(path)

#set universal theme
theme_set(
  theme_classic(base_family = "Times New Roman") + 
    theme(
      axis.text = element_text(size = rel(1), color = "black"),   # Increase size and set color to black for axis text
      axis.title = element_text(size = rel(1), color = "black"),  # Increase size and set color to black for axis titles
      legend.text = element_text(size = rel(1), color = "black"), # Increase size and set color to black for legend text
      legend.title = element_text(size = rel(1), color = "black") # Increase size and set color to black for legend title
    )
)
#=====FIGURE 1========
#create the world map
world_data <- map_data('world')
world_data <- fortify(world_data)
world_data %<>%
  mutate(country = if_else(region != "Virgin Islands", region, paste(region, subregion, sep = "-")),
         ISO3 = countrycode(country, "mapname", "a3", custom_dict = maps::iso3166,
                            custom_match = c("China" = "CHN", "Finland" = "FIN", "UK" = "GBR", "Norway" = "NOR", "Virgin Islands- British" = "VGB", "Virgin Islands- US" = "VIR"))) %>%
  filter(grepl("^[A-Z]{3}$", ISO3)) %>%
  identity() %>% data.table()

# Main Maps
for (spec in c("true","false")){
  #read in figure 1 data
  d <- fread(paste0("income_",spec,"/mortality_net_change_by_country_income_",spec,".csv")) %>% data.table
  d <- d[time == 2100,]
  setnames(d,"country","ISO3")
  d[, q05 :=  q05 / 100]
  d[, mean :=  mean / 100]
  d[, q95 :=  q95 / 100]
  
  #merge with map data
  m <- merge(world_data[ISO3 != "ATA" & ISO3 != "GRL"], d, by = "ISO3", all.x=T)
  ggplot(m, aes(long, lat, fill = mean)) +
    geom_map(map = m, aes(map_id = region)) +
    coord_fixed() +
    theme_void() +
    scale_fill_gradientn(labels = scales::percent, colors = c("#3288BD","#3288BD","#3288BD","#3288BD","#FFFFBF","#FC8D59","#D53E4F","#D53E4F","#D53E4F"), limits = c(-0.12,0.12)) +
    labs(fill = paste0("Mean percent change baseline mortality rate in 2100")) +
    theme(legend.position = "bottom",
          legend.key.width = unit(2.5,"cm"),
          legend.spacing = unit(0.25,"cm"),
          legend.title = element_text(hjust = 0.5),
          legend.justification = "center") +
    guides(fill = guide_colorbar(title.position="top", title.hjust = 0.5)) 
  ggsave(paste0("figure_1_income_",spec,".png"), height=5, width = 8, dpi = 600)
}


# Appendix Maps
for (spec in c("true","false")){
  #read in figure 1 data
  d <- fread(paste0("income_",spec,"/mortality_net_change_by_country_income_",spec,".csv")) %>% data.table
  d <- d[time == 2100,]
  setnames(d,"country","ISO3")
  d[, q05 :=  q05 / 100]
  d[, mean :=  mean / 100]
  d[, q95 :=  q95 / 100]
  
  #merge with map data
  m <- merge(world_data[ISO3 != "ATA" & ISO3 != "GRL"], d, by = "ISO3", all.x=T)
  
  for (outstring in c("mean","q05","q95")){
    if (outstring == "mean"){lab <-  "Mean"}
    else if (outstring == "q05"){lab <-  "5th percentile"}
    else if (outstring == "q95"){lab  <- "95th percentile"}
    
    m[, out := eval(comb(outstring))]
    
    describe(m)
    
    ggplot(m, aes(long, lat, fill = out)) +
      geom_map(map = m, aes(map_id = region)) +
      coord_fixed() +
      theme_void() +
      scale_fill_gradientn(labels = scales::percent, colors = c("#3288BD","#3288BD","#3288BD","#3288BD","#FFFFBF","#FC8D59","#D53E4F","#D53E4F","#D53E4F"), limits = c(-0.24,0.24)) +
      labs(fill = paste0(lab, " percent change baseline mortality rate in 2100")) +
      theme(legend.position = "bottom",
            legend.key.width = unit(2.5,"cm"),
            legend.spacing = unit(0.25,"cm"),
            legend.title = element_text(hjust = 0.5),
            legend.justification = "center") +
      guides(fill = guide_colorbar(title.position="top", title.hjust = 0.5)) 
    ggsave(paste0("app_figure_1_income_",spec,"_",outstring,".png"), height=5, width = 8, dpi = 600)
  }
} 


#=====FIGURE 2========
#Main 
income_false <- fread("income_false/excess_deaths_income_false.csv") %>% data.table()
income_false[, income := "No"]
income_true <- fread("income_true/excess_deaths_income_true.csv") %>% data.table()
income_true[, income := "Yes"]
plot <- rbind(income_true, income_false) %>% data.table()
plot[, income := factor(income, levels = c("Yes", "No"))] 
describe(income_true)

ggplot(plot) +
  geom_line(aes(x = time, y = mean, group = income, color = income)) +
  geom_ribbon(aes(x = time, ymin = q05, ymax = q95, group = income, fill = income), alpha = 0.2) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  labs(x = "Year", y = "Global excess deaths", color = "Account for income-based adaptation?", fill = "Account for income-based adaptation?") +
  geom_segment(aes(x = 2020, xend = 2300, y = 0, yend = 0), color = "grey", linetype = "dashed") +
  scale_color_brewer(palette = "Set2") +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(labels = scales::number_format(scale = 1e-6, suffix = "M")) +
  scale_x_continuous(breaks = seq(2020, 2300, by = 20), limits = c(2020, 2300)) +
  theme(legend.position = "bottom")
ggsave("figure2.png", height=5, width = 7.5, units = "in", dpi = 600)



#=====FIGURE 3========
file_list <- list.files(pattern = "*.csv")
data_list <- lapply(file_list, fread)
d <- setDT(do.call("rbind", data_list))

total <- d[sector != "cromar_mortality" & (dr == "unweighted_eta_1.4_rho_.2" | dr == "weighted_globe_eta_1.4_rho_.2" | dr == "weighted_USA_eta_1.4_rho_.2") & sector == "total", .(dr,"scc_total" = scc)]
mortality <- d[sector != "cromar_mortality" & (dr == "unweighted_eta_1.4_rho_.2" | dr == "weighted_globe_eta_1.4_rho_.2" | dr == "weighted_USA_eta_1.4_rho_.2") & sector == "bressler_mortality",.("scc_mortality" = scc)]
plot <- cbind(total,mortality) 
plot[, scc_non_mort := scc_total - scc_mortality]  

t <- melt(plot, id.vars =  "dr", variable.name = "sector", value.name = "scc") %>% data.table()
plot <- t[, .("q5" = quantile(scc, 0.05), "q25" = quantile(scc, 0.25), 
              "mean" = mean(scc), "median" = median(scc),
              "q75" = quantile(scc, 0.75), q95 = quantile(scc, 0.95)), by = .(dr, sector)]

plot[dr == "unweighted_eta_1.4_rho_.2", dr_lab := "Equal Dollar Valuation"]
plot[dr == "weighted_globe_eta_1.4_rho_.2", dr_lab := "Income-Weighted (Global)"]
plot[dr == "weighted_USA_eta_1.4_rho_.2", dr_lab := "Income-Weighted (U.S.)"]
plot[sector == "scc_mortality", sector_lab := "Mortality damages"]
plot[sector == "scc_non_mort", sector_lab := "All other damages"]
plot[sector == "scc_total", sector_lab := "Total"]

plot[, dr_lab := factor(dr_lab, levels = c("Income-Weighted (U.S.)","Income-Weighted (Global)","Equal Dollar Valuation"))]
colors <- c("Equal Dollar Valuation" = "#A6CEE3", "Income-Weighted (Global)" = "#1F78B4", "Income-Weighted (U.S.)" = "#B2DF8A")
plot[, sector_lab := factor(sector_lab, levels = c("Total","Mortality damages","All other damages"))]

ggplot(plot, aes(x = sector_lab, fill = dr_lab, group = interaction(dr_lab, sector_lab))) +
  geom_boxplot(aes(ymin = q5, lower = q25, middle = median, upper = q75, ymax = q95), 
               stat = "identity",
               size = .25) +
  geom_point(aes(x = sector_lab, y = mean, group = interaction(dr_lab, sector_lab)), shape = 5, size = 2, position = position_dodge(width = .9)) +
  ylab(expression("SC-CO"[2] ~ "(US$" ~ per ~ "ton" ~ of ~ CO[2] ~ ")")) +
  xlab("") +
  scale_fill_manual(values = colors) +
  scale_y_continuous(labels = scales::comma) +
  geom_text(aes(x = sector_lab, y = mean, label = sprintf("$%s", scales::comma(mean, accuracy = 1)), 
                vjust = ifelse(sector_lab == "All other damages" & dr_lab == "Income-Weighted (Global)", -.6, -2.2),
                hjust = ifelse(sector_lab == "All other damages" & dr_lab == "Income-Weighted (Global)", -.3, .5)), 
            position = position_dodge(width = .9), 
            size = 3) +
  theme(legend.title = element_blank(), legend.position = "bottom")  +
  guides(fill = guide_legend(reverse = TRUE)) +  # Reverse legend order
  coord_flip()
ggsave("figure3.png", height=5, width = 7.5, units = "in", dpi = 600)


#=====FIGURE 4========
plot <- d[sector == "total" & (dr == "unweighted_eta_1_rho_.2" | dr == "unweighted_eta_1.25_rho_.2" | 
                                 dr == "unweighted_eta_1.4_rho_.2" | dr == "unweighted_eta_1.75_rho_.2" | dr == "unweighted_eta_2_rho_.2" |
                                 dr == "weighted_globe_eta_1_rho_.2" | dr == "weighted_globe_eta_1.25_rho_.2" | 
                                 dr == "weighted_globe_eta_1.4_rho_.2" | dr == "weighted_globe_eta_1.75_rho_.2" | dr == "weighted_globe_eta_2_rho_.2"),
          .("q5" = quantile(scc, 0.05), "q25" = quantile(scc, 0.25), 
            "mean" = mean(scc), "median" = median(scc),
            "q75" = quantile(scc, 0.75), "q95" = quantile(scc, 0.95)), by = .(dr)]

plot[dr == "unweighted_eta_1_rho_.2", dr_lab := "1"]
plot[dr == "unweighted_eta_1.25_rho_.2", dr_lab := "1.25"]
plot[dr == "unweighted_eta_1.4_rho_.2", dr_lab := "1.4"]
plot[dr == "unweighted_eta_1.75_rho_.2", dr_lab := "1.75"]
plot[dr == "unweighted_eta_2_rho_.2", dr_lab := "2"]
plot[dr == "weighted_globe_eta_1_rho_.2", dr_lab := "1"]
plot[dr == "weighted_globe_eta_1.25_rho_.2", dr_lab := "1.25"]
plot[dr == "weighted_globe_eta_1.4_rho_.2", dr_lab := "1.4"]
plot[dr == "weighted_globe_eta_1.75_rho_.2", dr_lab := "1.75"]
plot[dr == "weighted_globe_eta_2_rho_.2", dr_lab := "2"]
plot[1:5, method := "Equal Dollar Valuation"]
plot[6:10, method := "Income-Weighted (Global)"]

ggplot(plot, aes(x = dr_lab, group = method, color = method)) +
  geom_errorbar(aes(ymin = q5, ymax = q95), position = position_dodge(width = 0.5), width = 0.2) +
  geom_point(aes(y = mean),shape = 18, size = 3, position = position_dodge(width = 0.5)) +
  geom_line(aes(y = mean), position = position_dodge(width = 0.5), alpha = .5) +
  xlab(expression("Inequality Aversion (" * eta * ")")) +
  ylab(expression("SC-CO"[2] ~ "(US$" ~ per ~ "ton" ~ of ~ CO[2] ~ ")")) +
  scale_y_continuous(labels = scales::comma) +
  scale_color_manual(values = colors[1:2],name = "Method") +
  theme(legend.position = "bottom")  
ggsave("figure4.png", height=5, width = 7.5, units = "in", dpi = 600)


#=====TABLE 1========
t <- d[(sector == "total" & (dr == "unweighted_eta_1.4_rho_.2" | dr == "weighted_CHN_eta_1.4_rho_.2" | 
                               dr == "weighted_USA_eta_1.4_rho_.2"| dr == "weighted_IND_eta_1.4_rho_.2" |
                               dr == "weighted_globe_eta_1.4_rho_.2"| dr == "weighted_COD_eta_1.4_rho_.2")), 
       .("q5" = quantile(scc, 0.05), "mean" = mean(scc), "q95" = quantile(scc, 0.95)), by = .(dr)]
t[dr == "unweighted_eta_1.4_rho_.2", lab := "Equal Dollar Valuation"]
t[dr == "weighted_globe_eta_1.4_rho_.2", lab := "Income-Weighted (Global)"]
t[dr == "weighted_USA_eta_1.4_rho_.2", lab := "Income-Weighted (U.S.)"]
t[dr == "weighted_CHN_eta_1.4_rho_.2", lab := "Income-Weighted (China)"]
t[dr == "weighted_IND_eta_1.4_rho_.2", lab := "Income-Weighted (India)"]
t[dr == "weighted_COD_eta_1.4_rho_.2", lab := "Income-Weighted (Congo)"]

t[, range := paste0("[", round(q5), " - ", round(q95), "]")]
order <- c("Equal Dollar Valuation", "Income-Weighted (Global)", "Income-Weighted (U.S.)", "Income-Weighted (India)", "Income-Weighted (China)")
t[, lab := factor(lab, levels = order)]
mean_rows <- t[, .(lab, value = round(mean), type = "mean")]
range_rows <- t[, .(lab, value = range, type = "range")]
reshaped_t <- rbindlist(list(mean_rows, range_rows), use.names = TRUE)
setorder(reshaped_t, lab, type)
reshaped_t[type == "range", lab := ""]

tab <- stargazer(reshaped_t[,.(lab, value)], summary = F,rownames = F)[12:23]

header <- "\\begin{tabular}{l c}
\\toprule
\\textbf{Specification} & \\textbf{SC-CO\\textsubscript{2} (\\$ per tCO\\textsubscript{2})} \\\\
\\midrule"
out <- c(header, tab, "\\bottomrule \\end{tabular}")
write_lines(out, "table1.tex")


#=====APPENDIX TABLE 1========
t <- d[(sector == "total" & (dr == "unweighted_eta_1.4_rho_.2"| dr == "unweighted_eta_1.4_rho_.1" |
                               dr == "unweighted_eta_1.4_rho_0"| dr == "unweighted_eta_1.24_rho_.2"| dr == "unweighted_eta_1_rho_1"| 
                               dr == "weighted_globe_eta_1.4_rho_.2"| dr == "weighted_globe_eta_1.4_rho_.1" |
                               dr == "weighted_globe_eta_1.4_rho_0"| dr == "weighted_globe_eta_1.24_rho_.2"| dr == "weighted_globe_eta_1_rho_1")), 
       .("q5" = quantile(scc, 0.05), "mean" = mean(scc), "q95" = quantile(scc, 0.95)), by = .(dr)]

t[dr == "unweighted_eta_1.4_rho_.2", lab := "eta = 1.4, rho = 0.2% (main text)"]
t[dr == "unweighted_eta_1.4_rho_.1", lab := "eta = 1.4, rho = 0.1%"]
t[dr == "unweighted_eta_1.4_rho_0", lab := "eta = 1.4, rho = 0.0%"]
t[dr == "unweighted_eta_1.24_rho_.2", lab := "eta = 1.24, rho = 0.2% (EPA 2023 SC-GHG report)"]
t[dr == "unweighted_eta_1_rho_1", lab := "eta = 1, rho = 1% (Germany preferred)"]

t[, range := paste0("[", round(q5), " - ", round(q95), "]")]
order <- c("unweighted_eta_1.4_rho_.2", "unweighted_eta_1.4_rho_.1", "unweighted_eta_1.4_rho_0", 
           "unweighted_eta_1.24_rho_.2", "unweighted_eta_1_rho_1", "weighted_globe_eta_1.4_rho_.2",
           "weighted_globe_eta_1.4_rho_.1","weighted_globe_eta_1.4_rho_0","weighted_globe_eta_1.24_rho_.2","weighted_globe_eta_1_rho_1")
t[, dr := factor(dr, levels = order)]

mean_rows <- t[1:5, .(lab, value = round(mean), dr, type = "mean")]
range_rows <- t[1:5, .(lab, value = range, dr, type = "range")]
reshaped_t <- rbindlist(list(mean_rows, range_rows), use.names = TRUE)
setorder(reshaped_t, dr, type)

mean_rows_weighted <- t[6:10, .(value_weighted = round(mean), dr, type = "mean")]
range_rows_weighted <- t[6:10, .(value_weighted = range, dr, type = "range")]
reshaped_t_weighted <- rbindlist(list(mean_rows_weighted, range_rows_weighted), use.names = TRUE)
setorder(reshaped_t_weighted, dr, type)

t <- cbind(reshaped_t[,.(lab, value, type)],reshaped_t_weighted[,.(value_weighted, type)])
t[type == "range", lab := ""]

tab <- stargazer(t[,.(lab, value, value_weighted)], summary = F,rownames = F)[12:21]
tab <- gsub("eta", "$\\eta", tab, fixed= T)
tab <- gsub("rho", "\\rho", tab, fixed= T)

header <- "\\begin{tabular}{l c c}
\\toprule
\\textbf{Specification} & \\textbf{Equal Dollar Value SC-CO\\textsubscript{2}} & \\textbf{Income-Weighted SC-CO\\textsubscript{2}} \\\\
\\midrule"
out <- c(header, tab, "\\bottomrule \\end{tabular}")
write_lines(out, "app_table1.tex")





















































