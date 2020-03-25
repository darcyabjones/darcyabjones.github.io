
R_OPTS=--no-save --no-restore --no-init-file --no-site-file # vanilla, but with --environ

_posts/%.md: posts/%.Rmd
	Rscript ${R_OPTS} -e "library(knitr); knit('$<', output='$@')"
