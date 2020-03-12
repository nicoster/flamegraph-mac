PRODUCT := $(shell basename ${PWD})

test:
	luajit -e "require'stackcollapse-stackshot'.test()"

build:
	rm -rf archive/*
	@echo ${PRODUCT}-`git rev-parse HEAD | cut -c-7`-`date '+%Y%m%d-%H%M%S'` > REVISION;
	@$(eval BUILDNAME := ${PRODUCT}-`git br|grep '*'|cut -c3-`-`cat REVISION | cut -f3- -d '-'`.tar.gz )
	@tar zvcf archive/${BUILDNAME} lib/* bin/mkflame
	@sha256sum archive/${BUILDNAME}
	git add -f archive/*.gz
	git add archive
	git ci -m 'add artifacts'
	git push

brew:
	cd homebrew*; \
	echo `pwd`; \
	./update-rb.sh; \
	git diff && git add . && git ci -m 'update artifacts' && git ci

clean:
	rm -rf pid* *.out