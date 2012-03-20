# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

ESVN_PROJECT="boost-log"
ESVN_REPO_URI="https://boost-log.svn.sourceforge.net/svnroot/boost-log/trunk/boost-log"

inherit subversion eutils multilib toolchain-funcs

DESCRIPTION="C++ logging library implementation being proposed to the Boost library collection."
HOMEPAGE="http://boost-log.sourceforge.net/"
LICENSE="Boost-1.0"
SLOT="1.48"
KEYWORDS=""
IUSE="examples"

RDEPEND="dev-libs/boost:1.48"
DEPEND="${RDEPEND}
	dev-util/boost-build:1.48"

S="${WORKDIR}/boost-log"

src_prepare() {
	echo "${S}"

	cp "${FILESDIR}/Jamroot" "${S}"

	sed -i -e '/<library>/d' libs/log/build/Jamfile.v2 || die "sed failed"
}

src_compile() {
	bjam-1_48 \
		--prefix="${D}/usr" \
		--layout=versioned \
		--includedir="${D}/usr/include" \
		--libdir="${D}/usr/$(get_libdir)" \
		--toolchain=gcc \
		release threading=single,multi link=shared,static runtime-link=shared optimization=none \
		|| die "bjam failed"
}

src_install() {
	bjam-1_48 \
		--prefix="${D}/usr" \
		--layout=versioned \
		--includedir="${D}/usr/include" \
		--libdir="${D}/usr/$(get_libdir)" \
		--toolchain=gcc \
		release threading=single,multi link=shared,static runtime-link=shared optimization=none \
		install || die "bjam install failed"

	if use examples ; then
		find libs/log/example -iname Jamfile.v2 -or -iname CVS | xargs rm -rf
		insinto /usr/share/doc/${PF}/examples
		doins -r libs/log/example/*
	fi
}
