# this file computes and visualizes niche comparisons according to
# (Broennimann et al. 2011), using the `ecospat` library

# used libraries
library(ecospat)
library(ade4)
library(dplyr)
library(parallel)

tot_time <- Sys.time()
set.seed(4326) # consistent randmoness
# load extracted pa data
pa <- readRDS("R/data/occurrence_data/axyridis_pa_vals_extracted.rds")
pa_as <- subset(pa, Area == "as")
po_as <- subset(pa_as, Presence == "present")
pa_eu <- subset(pa, Area == "eu")
po_eu <- subset(pa_eu, Presence == "present")
bio_tot <- select(pa, starts_with("bio")) # only use bioclim vars

## compare total native to total invaded
# pca calibrated on all datapoints
pca_tot <- dudi.pca(bio_tot, scannf = FALSE, nf = 2)
# plot pca axis contribution
# initialize destination directory if necessary
dest <- "R/figures"
if (!file.exists(dest)) {
    dir.create(dest, recursive = TRUE)
}
fname <- "R/figures/as_eu_pca.png"
png(width = 600, height = 600, filename = fname)
par(cex = 1.2)
ecospat.plot.contrib(contrib = pca_tot$co, eigen = pca_tot$eig)
dev.off()
# pca scores for the whole area
scores_tot <- pca_tot$li
# pca scores for native occs
scores_po_as <- suprow(pca_tot, select(po_as, starts_with("bio")))$li
# pca scores for native occs with background
scores_pa_as <- suprow(pca_tot, select(pa_as, starts_with("bio")))$li
# pca scores for eu occs
scores_po_eu <- suprow(pca_tot, select(po_eu, starts_with("bio")))$li
# pca scores for eu occs with background
scores_pa_eu <- suprow(pca_tot, select(pa_eu, starts_with("bio")))$li

# calculate native dynamic occurrence densities grids
grid_as <- ecospat.grid.clim.dyn(
    glob = scores_tot,
    glob1 = scores_pa_as, sp = scores_po_as, R = 100, th.sp = 0
)
grid_eu <- ecospat.grid.clim.dyn(
    glob = scores_tot,
    glob1 = scores_pa_eu, sp = scores_po_eu, R = 100, th.sp = 0
)

# compute niche overlap (Schoeners overlap metric)
ol <- round(ecospat.niche.overlap(grid_as, grid_eu, cor = TRUE)$D, digits = 3)
# calculate niche dynamic indices
di <- round(ecospat.niche.dyn.index(grid_as, grid_eu)$dynamic.index.w, digits = 3)

# plot niche overlap
# initialize destination directory if necessary
dest <- "R/plots/niche_comp/single_ys"
if (!file.exists(dest)) {
    dir.create(dest, recursive = TRUE)
}
fname <- "R/plots/niche_comp/as_eu_tot_niche.png"
png(width = 600, height = 600, filename = fname)
par(cex = 2, mar = c(3, 3, 1, 0), mgp = c(1.5, 0.5, par()$mgp[3]))
ecospat.plot.niche.dyn(grid_as, grid_eu,
    quant = 0.5,
    col.unf = "#00ba38", col.exp = "#f8766d", col.stab = "#3f80f1",
    interest = 2, name.axis1 = "PC1",
    name.axis2 = "PC2"
)
legend("topright", c("native (Asia)", "invaded (Europe)", "overlap"), fill = c("#00ba38", "#f8766d", "#3f80f1"), cex = 2)
dev.off()

fname <- "R/figures/as-eu-tot-eq-sim.png"
png(width = 1200, height = 600, filename = fname)
par(mfrow = c(1, 2))
# niche equivalency test
nc <- detectCores() - 2
eq_test <- ecospat.niche.equivalency.test(grid_as, grid_eu,
    rep = 100, ncores = nc, overlap.alternative = "higher",
    expansion.alternative = "lower", stability.alternative = "higher", unfilling.alternative = "lower"
) # alternatives set to test for niche conservatism, i.e. niche overlap more equivalent than random
# plot eq_test
ecospat.plot.overlap.test(eq_test, "D", "Equivalency Native / EU")
rm(eq_test)
# niche similarity test
sim_test <- ecospat.niche.similarity.test(grid_as, grid_eu,
    rep = 100, rand.type = 2, ncores = nc, overlap.alternative = "higher",
    expansion.alternative = "lower", stability.alternative = "higher", unfilling.alternative = "lower"
) # alternatives set to test for niche conservatism, i.e. niche overlap more similar than random
# plot sim_test
ecospat.plot.overlap.test(sim_test, "D", "Similarity Native / EU")
rm(sim_test)
dev.off()
rm(grid_eu)

cat("compared total EU to native range \n")
rm(list = c("scores_pa_as", "scores_po_as", "scores_pa_eu", "scores_po_eu"))
gc()

## compare EU years to their following year
bio_eu <- select(pa_eu, starts_with("bio"))
# pca calibrated on eu datapoints
pca_eu <- dudi.pca(bio_eu, scannf = FALSE, nf = 2)
# plot pca axis contribution
fname <- "R/figures/eu-years-pca.png"
png(width = 600, height = 600, filename = fname)
par(cex = 1.2)
ecospat.plot.contrib(contrib = pca_eu$co, eigen = pca_eu$eig)
dev.off()
# pca scores for the whole area
scores_eu_tot <- pca_eu$li

# values for starting year
po_eu_y2 <- subset(po_eu, Year == 2002)
scores_po_eu_y2 <- suprow(pca_eu, select(po_eu_y2, starts_with("bio")))$li
grid_eu_y2 <- ecospat.grid.clim.dyn(
    glob = scores_eu_tot,
    glob1 = scores_eu_tot, sp = scores_po_eu_y2, R = 100, th.sp = 0
)

# calculate overlap between EU years
eq_tests <- c()
sim_tests <- c()
overlap <- c()
dynamic <- c()
for (y in 2003:2022) {
    # take subsets for both years
    po_eu_y1 <- po_eu_y2
    po_eu_y2 <- subset(po_eu, Year == y)
    # pca scores for each year
    scores_po_eu_y1 <- scores_po_eu_y2
    scores_po_eu_y2 <- suprow(pca_eu, select(po_eu_y2, starts_with("bio")))$li
    # grids for both years
    grid_eu_y1 <- grid_eu_y2
    grid_eu_y2 <- ecospat.grid.clim.dyn(
        glob = scores_eu_tot,
        glob1 = scores_eu_tot, sp = scores_po_eu_y2, R = 100, th.sp = 0
    )
    # overlap and niche dynamic
    ol <- round(ecospat.niche.overlap(grid_eu_y1, grid_eu_y2, cor = TRUE)$D, digits = 3)
    overlap <- rbind(overlap, ol)
    di <- round(ecospat.niche.dyn.index(grid_eu_y1, grid_eu_y2)$dynamic.index.w, digits = 3)
    dynamic <- rbind(dynamic, di)


    # plot niche overlap
    if (ol == 0) { # correct color for case of no stable overlap
        col_stab <- "#00ba38"
    } else {
        col_stab <- "#3f80f1"
    }

    fname <- paste0("R/plots/niche_comp/single_ys/eu_", y - 1, y, "_niche.png")
    png(width = 600, height = 600, filename = fname)
    par(cex = 2, mar = c(3, 3, 1, 0), mgp = c(1.5, 0.5, par()$mgp[3]))
    ecospat.plot.niche.dyn(grid_eu_y1, grid_eu_y2,
        quant = 0.5,
        col.unf = "#00ba38", col.exp = "#f8766d", col.stab = col_stab,
        interest = 2, name.axis1 = "PC1",
        name.axis2 = "PC2"
    )
    legend("topright", c(y-1, y, "overlap"), fill = c("#00ba38", "#f8766d", "#3f80f1"), cex = 2)
    dev.off()

    # niche equivalency test
    eq_test <- ecospat.niche.equivalency.test(grid_eu_y1, grid_eu_y2,
        rep = 100, ncores = nc, overlap.alternative = "higher",
        expansion.alternative = "lower", stability.alternative = "higher", unfilling.alternative = "lower"
    )
    eq_tests <- rbind(eq_tests, eq_test) # save in array

    # niche similarity test
    sim_test <- ecospat.niche.similarity.test(grid_eu_y1, grid_eu_y2,
        rep = 100, rand.type = 1, ncores = nc, overlap.alternative = "higher",
        expansion.alternative = "lower", stability.alternative = "higher", unfilling.alternative = "lower"
    )
    sim_tests <- rbind(sim_tests, sim_test) # save in array
}
cat("compared each year to following \n")

# save niche sim and eq results
eq_sim <- cbind(eq_tests, sim_tests)
saveRDS(overlap, file = "R/data/modelling/niche_y_overlap.rds")
saveRDS(dynamic, file = "R/data/modelling/niche_y_dynamic.rds")
saveRDS(eq_sim, file = "R/data/modelling/niche_y_eq_sim.rds")

td <- difftime(Sys.time(), tot_time, units = "secs")[[1]]
cat("niche comparisons finished", td, "secs", "\n")
