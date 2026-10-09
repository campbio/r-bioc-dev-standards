# Standard make targets for r-bioc-dev-standards.
#
# Packages don't copy this file. Each package's Makefile includes a cached
# copy, which dev/hooks/load-standards.sh refreshes at every Claude session
# start (or run `make standards-update`). Package-specific settings go above
# the include in the package's Makefile; extra targets go below it.
# `make claude-setup` writes .claude/settings.json, which packages don't
# commit (BiocCheck rejects a tracked .claude/).
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
  site-check article standards-update claude-setup

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

# Claude Code's settings for this clone: the shared base (downloaded next to
# this file, at the same ref) plus the package's own rules in
# dev/claude-settings.json. Lists and hooks are appended; the package file
# can't remove a base rule. Each developer runs this once per clone, and
# again after the settings change. Claude may not run it, since it writes
# Claude's own permissions.
CLAUDE_BASE_JSON := $(dir $(STANDARDS_MK))claude-settings.json

# The merge, in R. It's passed in single quotes, so it has none, and $$ is a
# literal $. The package file must have only the keys merged below, each
# permission list an array of strings, and each hook event an array of
# objects; anything else stops with an error, leaving the settings alone.
_cs_read = rd <- function(p) jsonlite::read_json(p, simplifyVector = FALSE); \
  s <- rd(Sys.getenv("BASE")); add <- Sys.getenv("ADD"); \
  a <- if (file.exists(add)) rd(add) else list()
_cs_check = obj <- function(x) is.list(x) && (length(x) == 0 || (!is.null(names(x)) && !anyDuplicated(names(x)))); \
  arr <- function(x) is.list(x) && is.null(names(x)); \
  strs <- function(x) is.null(x) || (arr(x) && all(vapply(x, function(v) is.character(v) && length(v) == 1, NA))); \
  shape <- function() stop(add, " is not shaped like Claude Code settings: permission lists must be arrays of strings, each hook event an array of objects, and no key repeated.", call. = FALSE); \
  if (!obj(a)) shape(); p <- a[["permissions"]]; h <- a[["hooks"]]; \
  bad <- c(setdiff(names(a), c("$$schema", "permissions", "hooks")), setdiff(names(p), c("allow", "ask", "deny"))); \
  if (length(bad)) stop(add, " has keys claude-setup does not merge: ", paste(bad, collapse = ", "), call. = FALSE); \
  if (!(is.null(p) || obj(p)) || !all(vapply(p, strs, NA))) shape(); \
  if (!(is.null(h) || obj(h)) || !all(vapply(h, function(e) arr(e) && all(vapply(e, obj, NA)), NA))) shape()
_cs_merge = for (k in c("allow", "ask", "deny")) s[["permissions"]][[k]] <- unique(c(s[["permissions"]][[k]], p[[k]])); \
  for (e in names(h)) s[["hooks"]][[e]] <- c(s[["hooks"]][[e]], h[[e]]); \
  out <- Sys.getenv("OUT"); jsonlite::write_json(s, paste0(out, ".tmp"), auto_unbox = TRUE, pretty = TRUE); \
  stopifnot(file.rename(paste0(out, ".tmp"), out))

claude-setup:  ## Write .claude/settings.json (people only; once per clone)
	@if [ -n "$$CLAUDECODE" ]; then \
	  echo "make claude-setup is for people only: it writes Claude's own permissions."; \
	  echo "Run it in a terminal outside Claude Code (not with !, which runs inside it)."; exit 1; \
	fi
	@if git ls-files --error-unmatch .claude/settings.json > /dev/null 2>&1; then \
	  echo "This package still commits .claude/settings.json, and make claude-setup would drop its own rules."; \
	  echo "First follow \"Migrating a package that tracks .claude/\" in ADOPTING.md."; exit 1; \
	fi
	@mkdir -p "$(dir $(CLAUDE_BASE_JSON))"
	@if curl -fsSL --max-time 30 "$(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json" -o "$(CLAUDE_BASE_JSON).tmp" \
	    && [ -s "$(CLAUDE_BASE_JSON).tmp" ]; then \
	  mv -f "$(CLAUDE_BASE_JSON).tmp" "$(CLAUDE_BASE_JSON)"; \
	else \
	  rm -f "$(CLAUDE_BASE_JSON).tmp"; \
	  if [ -s "$(CLAUDE_BASE_JSON)" ]; then \
	    echo "NOTE: Couldn't download the shared settings; using the cached copy, which may be out of date."; \
	  else \
	    echo "Couldn't download $(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json, and there is no cached copy."; exit 1; \
	  fi; \
	fi
	@mkdir -p .claude
	@BASE="$(CLAUDE_BASE_JSON)" ADD=dev/claude-settings.json OUT=.claude/settings.json \
	  Rscript -e '$(_cs_read); $(_cs_check); $(_cs_merge)'
	@echo "Wrote .claude/settings.json. Start (or restart) claude in this folder for it to take effect."
