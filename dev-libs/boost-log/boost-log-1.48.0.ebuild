# Copyright 1999-2009 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI="2"

ESVN_PROJECT="boost-log"
ESVN_REPO_URI="https://boost-log.svn.sourceforge.net/svnroot/boost-log/branches/v1"

inherit subversion eutils multilib toolchain-funcs

DESCRIPTION="C++ logging library implementation being proposed to the Boost library collection."
HOMEPAGE="http://boost-log.sourceforge.net/"
LICENSE="Boost-1.0"
SLOT="1.48"
KEYWORDS="~amd64"
IUSE="examples"

RDEPEND="dev-libs/boost:1.48"
DEPEND="${RDEPEND}
	dev-util/boost-build:1.48"

S="${WORKDIR}/boost-log"

src_prepare() {
	echo "${S}"

	cp "${FILESDIR}/Jamroot" "${S}"

	epatch "${FILESDIR}/${PV}-dependencies.patch"
}

src_configure() {
	cat > "${S}/user-config.jam" << __EOF__

variant gentoorelease : release : <optimization>none <debug-symbols>none ;
variant gentoodebug : debug : <optimization>none ;

using gcc : $(gcc-version) : $(tc-getCXX) : <cxxflags>"${CXXFLAGS}" <linkflags>"${LDFLAGS}" ;
__EOF__
}

src_compile() {
	bjam-1_48 -q \
		--user-config="${S}/user-config.jam" \
		--prefix="${D}/usr" \
		--layout=versioned \
		--includedir="${D}/usr/include" \
		--libdir="${D}/usr/$(get_libdir)" \
		gentoorelease threading=single,multi link=shared,static runtime-link=shared \
		|| die "bjam failed"
}

src_install() {
	bjam-1_48 -q \
		--user-config="${S}/user-config.jam" \
		--prefix="${D}/usr" \
		--layout=versioned \
		--includedir="${D}/usr/include" \
		--libdir="${D}/usr/$(get_libdir)" \
		gentoorelease threading=single,multi link=shared,static runtime-link=shared \
		install || die "bjam install failed"

	if use examples ; then
		find libs/log/example -iname Jamfile.v2 -or -iname CVS | xargs rm -rf
		insinto /usr/share/doc/${PF}/examples
		doins -r libs/log/example/*
	fi
}
