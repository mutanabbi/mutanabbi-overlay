# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit multilib eutils flag-o-matic toolchain-funcs

DESCRIPTION="Playstation Portable Video Converter"
HOMEPAGE="http://pspvc.sourceforge.net"
SRC_URI="mirror://sourceforge/pspvc/pspvc-install-${PV}.tar.gz
        amr? (
		http://www.3gpp.org/ftp/Specs/archive/26_series/26.104/26104-510.zip
		http://www.3gpp.org/ftp/Specs/archive/26_series/26.204/26204-510.zip )"

SLOT="0"
LICENSE="GPL-2"
KEYWORDS="~x86 ~amd64"

IUSE="debug threads aac altivec amr debug doc ieee1394 a52 encode imlib mmx ogg vorbis oss test theora threads truetype v4l xvid dts network zlib sdl"

RDEPEND="
	imlib? ( media-libs/imlib2 )
	truetype? ( >=media-libs/freetype-2 )
	sdl? ( >=media-libs/libsdl-1.2.10 )
	encode? ( media-sound/lame )
	ogg? ( media-libs/libogg )
	vorbis? ( media-libs/libvorbis )
	aac? ( media-libs/faad2 media-libs/faac )
	a52? ( >=media-libs/a52dec-0.7.4-r4 )
	xvid? ( >=media-libs/xvid-1.1.0 )
	zlib? ( sys-libs/zlib )
	dts? ( media-libs/libdts )
	ieee1394? ( =media-libs/libdc1394-1* sys-libs/libraw1394 )
	>=media-libs/x264-svn-20061014
	"


DEPEND=" ${RDEPEND}
	doc? ( app-text/texi2html )
	test? ( net-misc/wget )
	amr? ( app-arch/unzip )"

S=${WORKDIR}/pspvc-install-${PV} 
SS=${WORKDIR}/pspvc-install-${PV}/archives
dir=/usr/share/pspvc
Ddir=${D}/${dir} 

src_unpack() {
	unpack ${A}
# ffmpeg
	cd ${S}
	tar xjvf ${SS}/ffmpeg-0.4.9-p20061016.tar.bz2
	cd ${S}/ffmpeg
	# amr (float) support
	if use amr; then
		einfo "Including amr wide and narrow band (float) support ... "

		# narrow band codec
		mkdir ${S}/ffmpeg/libavcodec/amr_float
		cd ${S}/ffmpeg/libavcodec/amr_float
		
		unzip -q ${WORKDIR}/26104-510_ANSI_C_source_code.zip

		# wide band codec
		mkdir ${S}/ffmpeg/libavcodec/amrwb_float
		cd ${S}/ffmpeg/libavcodec/amrwb_float
		unzip -q ${WORKDIR}/26204-510_ANSI-C_source_code.zip

		# Patch if we're on 64-bit
		if useq alpha || useq amd64 || useq ia64 || useq ppc64; then
			cd ${S}
			epatch "${FILESDIR}/ffmpeg-0.4.9_p20060302-amr-64bit.patch"
		fi
	fi
	cd ${S}/ffmpeg

	#Append -fomit-frame-pointer to avoid some common issues
	use debug || append-flags "-fomit-frame-pointer"

	# for some reason it tries to #include <X11/Xlib.h>, but doesn't use it
	sed -i s:\#define\ HAVE_X11:\#define\ HAVE_LINUX: ffplay.c

	# .pc files contain wrong libdir path
	epatch ${FILESDIR}/ffmpeg-libdir.patch
	sed -i -e "s:GENTOOLIBDIR:$(get_libdir):" configure

	# Make it use pic always since we don't need textrels
	sed -i -e "s:LIBOBJFLAGS=\"\":LIBOBJFLAGS=\'\$\(PIC\)\':" configure

	# To make sure the ffserver test will work
	sed -i -e "s:-e debug=off::" tests/server-regression.sh

	epatch "${FILESDIR}/ffmpeg-shared-gcc4.1.patch"
	cd ${S}
	tar xzvf ${SS}/pspvc-0.3.tar.gz

}

src_compile() {
# ffmpeg
	einfo "Configuring ffmpeg"
	cd ${S}/ffmpeg

	replace-flags -O0 -O2

	local myconf="${EXTRA_ECONF}"
	
	#must enable x264 
	myconf="${myconf} --enable-x264"

	#disable mmx accelerated code if not requested, or if PIC is required
	# as the provided asm decidedly is not PIC.
	if ( gcc-specs-pie || ! use mmx ) && ( ! use amd64 ); then
		myconf="${myconf} --disable-mmx"
	fi

	# enabled by default
	use altivec || myconf="${myconf} --disable-altivec"
	use debug || myconf="${myconf} --disable-debug"
	use oss || myconf="${myconf} --disable-audio-oss"
	use v4l || myconf="${myconf} --disable-v4l --disable-v4l2"
	use ieee1394 || myconf="${myconf} --disable-dv1394"
	use network || myconf="${myconf} --disable-network"
	use zlib || myconf="${myconf} --disable-zlib"
	use sdl || myconf="${myconf} --disable-ffplay"

	myconf="${myconf} --disable-opts"

	# disabled by default
	use encode && myconf="${myconf} --enable-mp3lame"
	use a52 && myconf="${myconf} --enable-a52"
	use ieee1394 && myconf="${myconf} --enable-dc1394"
	use threads && myconf="${myconf} --enable-pthreads"
	use xvid && myconf="${myconf} --enable-xvid"
	if use vorbis
	then
		myconf="${myconf} --enable-vorbis --enable-libogg"
	else
		use ogg && myconf="${myconf} --enable-libogg"
	fi
	use dts && myconf="${myconf} --enable-dts"
	use aac && myconf="${myconf} --enable-faad --enable-faac"
	use amr && myconf="${myconf} --enable-amr_nb --enable-amr_wb"

	myconf="${myconf} --enable-gpl --enable-pp --disable-strip"

	# Specific workarounds for too-few-registers arch...
	if [[ $(tc-arch) == "x86" ]]; then
		filter-flags -fforce-addr -momit-leaf-frame-pointer
		append-flags -fomit-frame-pointer
		is-flag -O? || append-flags -O2
		if (use debug); then
			# no need to warn about debug if not using debug flag
			ewarn ""
			ewarn "Debug information will be almost useless as the frame pointer is omitted."
			ewarn "This makes debugging harder, so crashes that has no fixed behavior are"
			ewarn "difficult to fix. Please have that in mind."
			ewarn ""
		fi
	fi

	cd ${S}/ffmpeg
	./configure --extra-cflags=" ${CFLAGS} " --extra-ldflags=" ${LDFLAGS} " --prefix=/usr/share/pspvc --enable-static --enable-shared --cc=$(tc-getCC) ${myconf} || die "configure failed"
	einfo "Compiling ffmpeg"
	emake -j1 depend || die "depend failed"
	emake || die "make failed"

	cd ${S}/pspvc-0.3
	econf || die "pspvc econf failed"
	emake || die "pspvc emake failed"

}

src_install() {
	cd ${S}/ffmpeg
	emake -j1 LDCONFIG=true DESTDIR=${D} install || die "Install Failed"
	use doc && emake -j1 documentation
	dodoc ChangeLog README INSTALL
	dodoc doc
	cd ${S}/pspvc-0.3
	einstall || die "pspvc einstall failed"
	domenu ${SS}/pspvc.desktop
}
