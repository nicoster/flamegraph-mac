PRODUCT=`basename ${PWD}`

test:
	luajit -e "require'stackcollapse-stackshot'.test()"

build:
	@echo ${PRODUCT}-`git rev-parse HEAD | cut -c-7`-`date '+%Y%m%d-%H%M%S'` > REVISION;
	@$(eval BUILDNAME="${PRODUCT}-`git br|grep '*'|cut -c3-`-`cat REVISION | cut -f3- -d '-'`.tar.gz" )
	@tar zvcf archive/${BUILDNAME} lib/* bin/mkflamegraph
	@sha256sum archive/${BUILDNAME}

clean:
	rm -rf pid* *.out