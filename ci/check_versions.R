# Stops the run if the cloud installs different engine / risk-equation versions
# from the ones the model was validated with.
required <- c(WARDEN = "2.0.6", preventr = "0.12.0")
for (p in names(required)) {
  v <- as.character(packageVersion(p))
  cat(sprintf("%-10s installed %s, required %s\n", p, v, required[[p]]))
  if (v != required[[p]]) stop(sprintf("%s %s installed, but the model was validated with %s", p, v, required[[p]]))
}
cat(R.version.string, "\n")
