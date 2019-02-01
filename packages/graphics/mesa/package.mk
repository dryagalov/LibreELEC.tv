# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="mesa"
PKG_LICENSE="OSS"
PKG_SITE="http://www.mesa3d.org/"
PKG_DEPENDS_TARGET="toolchain expat libdrm Mako:host"
PKG_LONGDESC="Mesa is a 3-D graphics library with an API."
PKG_TOOLCHAIN="meson"
PKG_BUILD_FLAGS="+lto"

case $PROJECT in
  Amlogic)
    case $DEVICE in
      Khadas_VIM2|Nexbox_A1|S912)
        #PKG_VERSION="3c2923caa79f885212dc0b891ea420e325f4ccea" # master
        #PKG_SHA256="992e86cd1e08fe67591a8838a9e4a0c54af8c169b2fa052938b7e9e44d31dc32"
        #PKG_URL="https://gitlab.freedesktop.org/panfrost/mesa/-/archive/$PKG_VERSION/mesa-$PKG_VERSION.tar.gz"
        #;;
        PKG_VERSION="5beac5f5333a5d89a3ad363b2139db495589d9ce" # winsys-rebased-meson
        PKG_SHA256="72eba8c035161be88bcb223f40525d37f64ead3d8b726dd09aa57dcb8421bb15"
        PKG_URL="https://github.com/chewitt/mesa/archive/$PKG_VERSION.tar.gz"
        PKG_SOURCE_NAME="mesa-$PKG_VERSION.tar.gz"
        PKG_PATCH_DIRS="panfrost"
        ;;
      *)
        PKG_VERSION="8e713e4781982c700bfc7b09279146189d525a86" # lima-18.3
        PKG_SHA256="389b781c64e9be176ea98ec9b940179d410a7eebc206318d33b3806450ea4f16"
	PKG_URL="https://gitlab.freedesktop.org/lima/mesa/-/archive/$PKG_VERSION/mesa-$PKG_VERSION.tar.gz"
	;;
    esac
    ;;
  *)
    PKG_VERSION="18.3.2"
    PKG_SHA256="e9760ff8f0a6700c395705181ee997cd4fcb6f492143f2d52965ca63bca7139f"
    PKG_URL="https://github.com/mesa3d/mesa/archive/mesa-$PKG_VERSION.tar.gz"
    ;;
esac

get_graphicdrivers

PKG_MESON_OPTS_TARGET="-Ddri-drivers=$DRI_DRIVERS \
                       -Dgallium-drivers=$GALLIUM_DRIVERS \
                       -Dgallium-extra-hud=false \
                       -Dgallium-xvmc=false \
                       -Dgallium-omx=disabled \
                       -Dgallium-nine=false \
                       -Dgallium-opencl=disabled \
                       -Dvulkan-drivers= \
                       -Dshader-cache=true \
                       -Dshared-glapi=true \
                       -Dopengl=true \
                       -Dgbm=true \
                       -Degl=true \
                       -Dglvnd=false \
                       -Dasm=true \
                       -Dvalgrind=false \
                       -Dlibunwind=false \
                       -Dlmsensors=false \
                       -Dbuild-tests=false \
                       -Dselinux=false \
                       -Dosmesa=none"

if [ "$DISPLAYSERVER" = "x11" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET xorgproto libXext libXdamage libXfixes libXxf86vm libxcb libX11 libxshmfence libXrandr"
  export X11_INCLUDES=
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=x11,drm -Ddri3=true -Dglx=dri"
elif [ "$DISPLAYSERVER" = "weston" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET wayland wayland-protocols"
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=wayland,drm -Ddri3=false -Dglx=disabled"
else
  PKG_MESON_OPTS_TARGET+=" -Dplatforms=drm -Ddri3=false -Dglx=disabled"
fi

if [ "$LLVM_SUPPORT" = "yes" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET elfutils llvm"
  export LLVM_CONFIG="$SYSROOT_PREFIX/usr/bin/llvm-config-host"
  PKG_MESON_OPTS_TARGET+=" -Dllvm=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dllvm=false"
fi

if [ "$VDPAU_SUPPORT" = "yes" -a "$DISPLAYSERVER" = "x11" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET libvdpau"
  PKG_MESON_OPTS_TARGET+=" -Dgallium-vdpau=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-vdpau=false"
fi

if [ "$VAAPI_SUPPORT" = "yes" ] && listcontains "$GRAPHIC_DRIVERS" "(r600|radeonsi)"; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET libva"
  PKG_MESON_OPTS_TARGET+=" -Dgallium-va=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-va=false"
fi

if listcontains "$GRAPHIC_DRIVERS" "vmware"; then
  PKG_MESON_OPTS_TARGET+=" -Dgallium-xa=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgallium-xa=false"
fi

if [ "$OPENGLES_SUPPORT" = "yes" ]; then
  PKG_MESON_OPTS_TARGET+=" -Dgles1=false -Dgles2=true"
else
  PKG_MESON_OPTS_TARGET+=" -Dgles1=false -Dgles2=false"
fi

# Temporary workaround:
# Listed libraries are static, while mesa expects shared ones. This breaks the
# dependency tracking. The following has some ideas on how to address that.
# https://github.com/LibreELEC/LibreELEC.tv/pull/2163
pre_configure_target() {
  if [ "$DISPLAYSERVER" = "x11" ]; then
    export LIBS="-lxcb-dri3 -lxcb-dri2 -lxcb-xfixes -lxcb-present -lxcb-sync -lxshmfence -lz"
  fi
}

post_makeinstall_target() {
  # Similar hack is needed on EGL, GLES* front. Might as well drop it and test the GLVND?
  if [ "$DISPLAYSERVER" = "x11" ]; then
    # rename and relink for cooperate with nvidia drivers
    rm -rf $INSTALL/usr/lib/libGL.so
    rm -rf $INSTALL/usr/lib/libGL.so.1
    ln -sf libGL.so.1 $INSTALL/usr/lib/libGL.so
    ln -sf /var/lib/libGL.so $INSTALL/usr/lib/libGL.so.1
    mv $INSTALL/usr/lib/libGL.so.1.2.0 $INSTALL/usr/lib/libGL_mesa.so.1
  fi
}
