# Standard make targets for r-bioc-dev-standards.
#
# Packages don't copy this file. Each package's Makefile includes a cached
# copy, which dev/hooks/load-standards.sh refreshes at every Claude session
# start (or run `make standards-update`). Package-specific settings go above
# the include in the package's Makefile; extra targets go below it.
#
# Settings a package can change (set them above the include):
#   FORCE_SUGGESTS  TRUE: check and check-full fail if any Suggests package
#                   is missing, as on Bioconductor's builders. FALSE: skip
#                   what needs a missing one.

FORCE_SUGGESTS ?= TRUE

.DEFAULT_GOAL := help

# The package settings allow-list `make test-one` with any arguments, so
# test-one must run on its own: `make test-one FILTER=x clean` would
# otherwise run a people-only target without a prompt.
ifneq ($(filter test-one,$(MAKECMDGOALS)),)
  ifneq ($(words $(MAKECMDGOALS)),1)
    $(error make test-one must be run on its own)
  endif
endif
.PHONY: help docs test test-one check check-full bioccheck lint coverage \
  site-check article standards-update

help:  ## List targets
	@grep -hE '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  %-17s %s\n", $$1, $$2}'

docs:  ## Regenerate man/*.Rd and NAMESPACE from roxygen comments
	Rscript -e 'devtools::document()'

test:  ## Run the full test suite
	Rscript -e 'devtools::test(stop_on_failure = TRUE)'

# FILTER reaches R through the environment, never pasted into the R code,
# and may contain only letters, digits, '.', '_' and '-'.
test-one:  ## Run matching test files: make test-one FILTER=<pattern>
	@case "$$FILTER" in \
	  "") echo "Usage: make test-one FILTER=<pattern>"; exit 1 ;; \
	  *[!A-Za-z0-9._-]*) echo "FILTER may contain only letters, digits, '.', '_' and '-'."; exit 1 ;; \
	esac
	Rscript -e 'devtools::test(filter = Sys.getenv("FILTER"), stop_on_failure = TRUE)'

check:  ## Quick R CMD check: skips vignettes and the PDF manual
	Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--ignore-vignettes"), build_args = "--no-build-vignettes", env = c("_R_CHECK_FORCE_SUGGESTS_" = "$(FORCE_SUGGESTS)"), error_on = "warning", check_dir = tempdir())'

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

# Renders one vignette or pkgdown article into a temporary folder, so the
# committed docs/ (if any) is never touched. FILTER is the file name without
# .Rmd; articles in vignettes/articles/ are found automatically.
article:  ## Render one article to a temp folder: make article FILTER=<name>
	@case "$$FILTER" in \
	  "") echo "Usage: make article FILTER=<name>"; exit 1 ;; \
	  *[!A-Za-z0-9._-]*) echo "FILTER may contain only letters, digits, '.', '_' and '-'."; exit 1 ;; \
	esac
	@out="$$(mktemp -d)"; \
	  OUT="$$out" Rscript -e 'n <- Sys.getenv("FILTER"); if (file.exists(file.path("vignettes", "articles", paste0(n, ".Rmd")))) n <- file.path("articles", n); pkg <- pkgdown::as_pkgdown(".", override = list(destination = Sys.getenv("OUT"))); pkgdown::build_article(n, pkg = pkg, lazy = FALSE, new_process = FALSE)' && \
	  echo "Rendered into $$out"

standards-update:  ## Re-download this file of shared targets
	curl -fsSL --max-time 30 "$(R_BIOC_STANDARDS_BASE)/shared/standards.mk" -o "$(STANDARDS_MK).tmp"
	mv -f "$(STANDARDS_MK).tmp" "$(STANDARDS_MK)"
