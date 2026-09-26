# Standard targets expected by r-bioc-dev-standards.
# Run `make help` to list them. Recipe lines must start with a tab.

.PHONY: help docs test test-one check check-full bioccheck lint

help:  ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  %-12s %s\n", $$1, $$2}'

docs:  ## Regenerate man/ and NAMESPACE from roxygen comments
	Rscript -e 'devtools::document()'

test:  ## Run the full test suite
	Rscript -e 'devtools::test(stop_on_failure = TRUE)'

test-one:  ## Run matching test files: make test-one FILTER=<pattern>
	@test -n "$(FILTER)" || { echo "Usage: make test-one FILTER=<pattern>"; exit 1; }
	Rscript -e 'devtools::test(filter = "$(FILTER)", stop_on_failure = TRUE)'

check:  ## Quick R CMD check: skips vignettes and the PDF manual
	Rscript -e 'rcmdcheck::rcmdcheck(args = c("--no-manual", "--ignore-vignettes"), build_args = "--no-build-vignettes", error_on = "warning", check_dir = tempdir())'

check-full:  ## Full check: rebuilds vignettes, runs \donttest examples
	Rscript -e 'devtools::check(document = FALSE, vignettes = TRUE, run_dont_test = TRUE, error_on = "warning", check_dir = tempdir())'

bioccheck:  ## BiocCheckGitClone on the repo, then BiocCheck on a built tarball
	Rscript -e 'BiocCheck::BiocCheckGitClone(".", "quit-with-status" = TRUE)'
	@tmp="$$(mktemp -d)"; \
	  cd "$$tmp" && R CMD build "$(CURDIR)" && \
	  Rscript -e 'BiocCheck::BiocCheck(list.files(pattern = "[.]tar[.]gz$$")[1], "quit-with-status" = TRUE)'; \
	  status=$$?; echo "BiocCheck output kept in $$tmp"; exit $$status

lint:  ## Run lintr on the package (reports only; changes nothing)
	Rscript -e 'print(lintr::lint_package())'
