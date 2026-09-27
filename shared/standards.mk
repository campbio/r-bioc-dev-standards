# Standard make targets for r-bioc-dev-standards.
#
# Packages don't copy this file. Each package's Makefile includes a cached
# copy, which dev/hooks/load-standards.sh refreshes at every Claude session
# start (or run `make standards-update`). Package-specific settings go above
# the include in the package's Makefile; extra targets go below it.
#
# Settings a package can change (set them above the include):
#   FORCE_SUGGESTS  TRUE: check-full fails if any Suggests package is
#                   missing, as on Bioconductor's builders. FALSE: skip
#                   what needs a missing one.

FORCE_SUGGESTS ?= TRUE

.DEFAULT_GOAL := help
.PHONY: help docs test test-one check check-full bioccheck lint coverage \
  site-check standards-update

help:  ## List targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  %-17s %s\n", $$1, $$2}'

docs:  ## Regenerate man/*.Rd and NAMESPACE from roxygen comments
	Rscript -e 'devtools::document()'

test:  ## Run the full test suite
	Rscript -e 'devtools::test(stop_on_failure = TRUE)'

test-one:  ## Run matching test files: make test-one FILTER=<pattern>
	@test -n "$(FILTER)" || { echo "Usage: make test-one FILTER=<pattern>"; exit 1; }
	Rscript -e 'devtools::test(filter = "$(FILTER)", stop_on_failure = TRUE)'

check:  ## Quick R CMD check: skips vignettes and the PDF manual
	Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--ignore-vignettes"), build_args = "--no-build-vignettes", error_on = "warning", check_dir = tempdir())'

check-full:  ## Full check: rebuilds vignettes, runs \donttest examples
	Rscript -e 'devtools::check(document = FALSE, vignettes = TRUE, run_dont_test = TRUE, force_suggests = $(FORCE_SUGGESTS), error_on = "warning", check_dir = tempdir())'

bioccheck:  ## BiocCheckGitClone on the repo, then BiocCheck on a built tarball
	Rscript -e 'BiocCheck::BiocCheckGitClone(".", "quit-with-status" = TRUE)'
	@tmp="$$(mktemp -d)"; \
	  cd "$$tmp" && R CMD build "$(CURDIR)" && \
	  Rscript -e 'tb <- list.files(pattern = "[.]tar[.]gz$$")[1]; message(sprintf("Tarball %s: %.2f MB (limit 10 MB)", tb, file.size(tb) / 1e6)); BiocCheck::BiocCheck(tb, "quit-with-status" = TRUE)'; \
	  status=$$?; echo "BiocCheck output kept in $$tmp"; exit $$status

lint:  ## Run lintr on the package (reports only; changes nothing)
	Rscript -e 'print(lintr::lint_package())'

coverage:  ## Print test coverage, overall and per file
	Rscript -e 'print(covr::package_coverage())'

site-check:  ## Check the pkgdown reference index lists every export (no site build)
	Rscript -e 'pkgdown::check_pkgdown()'

standards-update:  ## Re-download this file of shared targets
	curl -fsSL --max-time 30 "$(R_BIOC_STANDARDS_BASE)/shared/standards.mk" -o "$(STANDARDS_MK).tmp"
	mv -f "$(STANDARDS_MK).tmp" "$(STANDARDS_MK)"
