TAG = $(shell cat ./src/VERSION.txt)

CIRCLECI_FLAGS ?= --skip-update-check
ifneq ($(V),)
	CIRCLECI_FLAGS+=--debug
endif

CAT_COMMAND ?= cat
ifneq ($(shell command -v pygmentize),)
	CAT_COMMAND=pygmentize -l yaml
endif
ifneq ($(shell command -v bat),)
	CAT_COMMAND=bat -l yaml -
endif

.PHONY: create
create:  ## creates orb registry to org namespace.
	@circleci orb create $(strip $(CIRCLECI_FLAGS)) --no-prompt ${NAMESPACE}/${ORB} > /dev/null 2>&1 || true

.PHONY: pack
pack:  ## packing orb.
pack: clean
	@circleci config pack $(strip $(CIRCLECI_FLAGS)) src/ > src/${ORB}.yml

.PHONY: validate
validate:  ## validate orb.
	@circleci orb validate $(strip $(CIRCLECI_FLAGS)) ./src/${ORB}.yml
	@yamllint -s .
	@${MAKE} --silent clean

.PHONY: check
check:  ## pack orb and run validation.
check: pack validate

.PHONY: process
process:  ## processes orb.
process: pack
	@circleci orb process $(strip $(CIRCLECI_FLAGS)) ./src/${ORB}.yml | ${CAT_COMMAND}
	@${MAKE} --silent clean

.PHONY: clean
clean:  ## clean packed orb.
	@${RM} ./src/${ORB}.yml

.PHONY: publish/dev
publish/dev: TAG=dev:$(TAG)
publish/dev: validate create  ## publish ${ORB}.yml to dev orb registry.
	@echo ${TAG}
	# circleci orb publish $(strip $(CIRCLECI_FLAGS)) ./src/${ORB}.yml ${NAMESPACE}/$*@${TAG}

.PHONY: publish
publish: validate create  ## publish ${ORB}.yml to production orb registry.
	circleci orb publish $(strip $(CIRCLECI_FLAGS)) ./src/${ORB}.yml ${NAMESPACE}/$*@${TAG}

.PHONY: boilerplate/orb/%
boilerplate/orb/%: BOILERPLATE_ORB_DIR=$(*D)
boilerplate/orb/%: BOILERPLATE_ORB_NAME=$(*F)
boilerplate/orb/%:  ## Creates a orb yaml based on boilerplate.*.txt.
	@echo "BOILERPLATE_ORB_DIR:  ${BOILERPLATE_ORB_DIR}"
	@echo "BOILERPLATE_ORB_NAME: ${BOILERPLATE_ORB_NAME}"
	if [ ! -d "src/${BOILERPLATE_ORB_DIR}" ]; then mkdir -p "src/${BOILERPLATE_ORB_DIR}"; fi
	cat ./hack/boilerplate/boilerplate.${BOILERPLATE_ORB_DIR}.txt > src/${BOILERPLATE_ORB_DIR}/${BOILERPLATE_ORB_NAME}

.PHONY: help
help:  ## Show make target help.
	@perl -nle 'BEGIN {printf "Usage:\n  make \033[33m<target>\033[0m\n\nTargets:\n"} printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2 if /^([a-zA-Z\/_-].+)+:.*?\s+## (.*)/' ${MAKEFILE_LIST}
