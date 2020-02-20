PRODUCT=`basename ${PWD}`

test:
	luajit -e "require'stackcollapse-stackshot'.test()"

build:
	echo ${PRODUCT}-`git rev-parse HEAD | cut -c-7`-`date '+%Y%m%d-%H%M%S'` > REVISION
	tar zvcf ${PRODUCT}-`git br|grep '*'|cut -c3-`-`cat REVISION | cut -f2- -d '-'`.tar.gz *.lua *.pl *.sh *.py mkstackshots