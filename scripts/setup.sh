#!/bin/bash -e


# Valiables
# -----------------------------------------------

#DEFAULT_TARGET=agl-ivi-demo-platform-flutter
SETUP_NAME="kvm-demo"

MACHINE="raspberrypi4"
TARGET="agl-kvm-demo-platform"
FEATURES="agl-demo agl-devel agl-kvm"
BRANCH="master"
MANIFEST="quillback_16.93.0.xml"
LOCAL_CONF_SETTINGS='
'
BBLAYERS_CONF_SETTINGS='
'
CACHE_SHARED=true


# functions
# -----------------------------------------------

function init_env()
{
	BASE_DIR=$(pwd)

	BUILD_DIR=${BASE_DIR}/build/${SETUP_NAME}

	RECIPES_BASE_DIR=${BASE_DIR}/recipes
	RECIPES_DIR=${RECIPES_BASE_DIR}/${BRANCH}_${MANIFEST:0:-4}

	CACHE_BASE_DIR=${BASE_DIR}/cache/cache-${BRANCH}
	CACHE_DOWNLOAD=${CACHE_BASE_DIR}/downloads
	CACHE_SSTATE=${CACHE_BASE_DIR}/sstate-cache

	CACHE_SHARED_DIR=${BASE_DIR}/cache/cache-shared
	CACHE_SHARED_DOWNLOAD=${CACHE_SHARED_DIR}/downloads
	CACHE_SHARED_SSTATE=${CACHE_SHARED_DIR}/sstate-cache
}

function show_help()
{
        echo "Usage: $0 <Argument> [Options]"
        echo ""
        echo "Argument:"
        echo "  -h, --help: show this help infomation"
        echo "  -d, --download: download source code"
        echo "  -s, --source: source environment setup scripts"
        echo "  -b, --build: build image"
	echo "  -e, --environment: show environment"
	echo ""
        echo "Options:"
	echo "  -c, --config <filename>: use specified config file"
}

function show_env()
{
	cat <<-EOF
		Environment:
		    SETUP_NAME: $SETUP_NAME
		    MACHINE:  $MACHINE
		    TARGET:   $TARGET
		    FEATURES: $FEATURES
		    BRANCH:   $BRANCH
		    MANIFEST: $MANIFEST
	EOF
}

function info()
{
	printf "[%(%F %T)T] ${FUNCNAME[1]}: $@\n"
}

function download_src()
{
	info "START"
	if [ ! -d $RECIPES_DIR ]; then
		RECIPES_TMP_DIR=${RECIPES_BASE_DIR}/tmp-recipes
		if [ -d $RECIPES_TMP_DIR ]; then rm -rf $RECIPES_TMP_DIR; fi
		mkdir -p $RECIPES_TMP_DIR && cd $RECIPES_TMP_DIR
		repo init -b $BRANCH -m $MANIFEST \
			-u https://gerrit.automotivelinux.org/gerrit/AGL/AGL-repo
		repo sync -j$(nproc)
		cd $BASE_DIR
		mv $RECIPES_TMP_DIR $RECIPES_DIR
	else
		info "Source code has been already downloaded."
	fi

	if [ -d ${RECIPES_BASE_DIR}/meta-loca ] && [ ! -e "${RECIPES_DIR}/meta-local" ]; then
		ln -s ${RECIPES_BASE_DIR}/meta-local ${RECIPES_DIR}/
		info "Creating link to meta-local"
	fi
	info "FINISH"
}

function source_env()
{
	info "START"
	cd $RECIPES_DIR
	source meta-agl/scripts/aglsetup.sh \
		-f -m $MACHINE -b $BUILD_DIR $FEATURES

	# make cache settings
	if $CACHE_SHARED;
	then
		CACHE_BASE_DIR=$CACHE_SHARED_DIR
		CACHE_DOWNLOAD=$CACHE_SHARED_DOWNLOAD;
		CACHE_SSTATE=$CACHE_SHARED_SSTATE;
	fi
	cat > conf/site.conf <<-EOF
		DL_DIR = "$CACHE_DOWNLOAD"
		SSTATE_DIR = "$CACHE_SSTATE"
	EOF
	if [ ! -d "$CACHE_BASE_DIR" ]; then mkdir -p $CACHE_BASE_DIR; fi

	# make local settings
	cat >> conf/local.conf <<-EOF
		$LOCAL_CONF_SETTINGS
	EOF
	cat >> conf/bblayers.conf <<-EOF
		$BBLAYERS_CONF_SETTINGS
	EOF
	info "FINISH"
}

function build_image()
{
	info "START"
	info "bitbake --runall=fetch"
	time bitbake --runall=fetch ${TARGET}
	info "bitbake --continue"
	time bitbake --continue ${TARGET}
	info "FINISH"
}

function load_config()
{
	info "START"
	if [ $# -lt 2 ];
	then
		echo "--config option should be followed by config filename"
		show_help
		exit 1
	fi

	if [ ! -f "$2" ]; then
		echo "No such file: $2"
		exit 1
	fi

	info "source $2"
	source $2
	info "FINISH"
}

function build()
{
	DO_DOWNLOAD=${DO_DOWNLOAD:=false}
	DO_SOURCE=${DO_SOURCE:=false}
	DO_BUILD=${DO_BUILD:=false}

	$DO_DOWNLOAD || $DO_SOURCE || $DO_BUILD && \
		download_src

	$DO_SOURCE || $DO_BUILD && \
		source_env &&
		show_env

	$DO_BUILD && \
		build_image
}

function parse_arg()
{
	while [ $# -ne 0 ];
	do
		case $1 in
			-h | --help )
				CMD=show_help;
				return;;
			-d | --download )
				CMD=build;
				DO_DOWNLOAD=true;
				shift;;
			-s | --source )
				CMD=build;
				DO_SOURCE=true;
				shift;;
			-b | --build )
				CMD=build;
				DO_BUILD=true;
				shift;;
			-c | --config )
				load_config $@
				shift 2;;
			-e | --environment)
				CMD=show_env;
				shift;;
			*)
				echo "Unkown option: $1"
				show_help
				exit 1;;
		esac

	done
}

function main()
{
	init_env
	${CMD:=show_help}
}


# Main
# -----------------------------------------------

parse_arg $@
main

