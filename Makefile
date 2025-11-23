# ---------------------------------------------------------------------------
# SIMPLIFIED BUMP WORKFLOW
# ---------------------------------------------------------------------------

# Extract current version from udwall script
VERSION := $(shell grep '__version__ =' udwall | cut -d '"' -f 2)

bump:
	@echo "------------------------------------------------"
	@echo "Current Version: $(VERSION)"
	@echo "------------------------------------------------"
	@# STEP 1: ASK BUMP TYPE AND UPDATE FILE
	@echo "Select bump type:"
	@echo "1) Patch (default)  [0.0.X -> 0.0.X+1]"
	@echo "2) Minor            [0.X.0 -> 0.X+1.0]"
	@echo "3) Major            [X.0.0 -> X+1.0.0]"
	@read -p "Enter choice [1]: " bump_type; \
	bump_type=$${bump_type:-1}; \
	\
	OLD_VER="$(VERSION)"; \
	if [ "$$bump_type" = "1" ]; then \
		NEW_VER=$$(echo $$OLD_VER | awk -F. '{$$NF = $$NF + 1;} 1' OFS=. ); \
	elif [ "$$bump_type" = "2" ]; then \
		NEW_VER=$$(echo $$OLD_VER | awk -F. '{$$(NF-1) = $$(NF-1) + 1; $$NF = 0;} 1' OFS=. ); \
	elif [ "$$bump_type" = "3" ]; then \
		NEW_VER=$$(echo $$OLD_VER | awk -F. '{$$1 = $$1 + 1; $$2 = 0; $$3 = 0;} 1' OFS=. ); \
	else \
		echo "Invalid option. Exiting."; exit 1; \
	fi; \
	\
	# Update version in udwall file \
	sed -i "s/__version__ = \".*\"/__version__ = \"$$NEW_VER\"/" udwall; \
	echo "Updated udwall to version $$NEW_VER"; \
	echo ""; \
	\
	# STEP 2 & 3: ASK TO COMMIT, PUSH, AND TAG \
	read -p "Do you want to 'git add .', commit 'bumped version to v$$NEW_VER', and push? [Y/n] " push_ans; \
	push_ans=$${push_ans:-Y}; \
	if [ "$$push_ans" = "Y" ] || [ "$$push_ans" = "y" ]; then \
		echo "Staging all changes..."; \
		git add .; \
		echo "Committing..."; \
		git commit -m "bumped version to v$$NEW_VER"; \
		echo "Pushing to main..."; \
		git push origin HEAD; \
		echo "Creating and Pushing Tag v$$NEW_VER..."; \
		git tag v$$NEW_VER; \
		git push origin v$$NEW_VER; \
		echo "Done! v$$NEW_VER released."; \
	else \
		echo "Changes staged in udwall file but NOT committed. process aborted."; \
	fi
