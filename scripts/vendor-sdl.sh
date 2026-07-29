#!/usr/bin/env bash
# Build SDL3 + SDL3_ttf from source into $SDL_DIR. Invoked by `mise run setup`,
# which exports SDL_DIR, SDL_VERSION, and SDL_TTF_VERSION.
# Idempotent: skips when the stamp exists. macOS + Linux only.
set -euo pipefail

if [ -f "$SDL_DIR/.stamp" ]; then
  echo "SDL3 $SDL_VERSION already vendored in $SDL_DIR"
  exit 0
fi

mkdir -p "$SDL_DIR" build/.sdl
cd build/.sdl
rm -rf inst

# fetch a libsdl-org release, cmake-build it, install into the shared `inst` prefix.
# args: <repo> <src-name> <version> [extra cmake flags...]. CMAKE_PREFIX_PATH=inst lets
# each build find the ones installed before it (SDL_ttf needs the SDL3 we build first).
vendor() {
  repo=$1; name=$2; ver=$3; shift 3
  tb="$name-$ver.tar.gz"
  [ -f "$tb" ] || curl -fL -o "$tb" "https://github.com/libsdl-org/$repo/releases/download/release-$ver/$tb"
  rm -rf "$name-$ver" "b-$name"
  tar xf "$tb"
  # release tarballs don't bundle vendored submodules (freetype/harfbuzz);
  # the upstream script git-clones them into external/
  [ -x "$name-$ver/external/download.sh" ] && "$name-$ver/external/download.sh"
  cmake -S "$name-$ver" -B "b-$name" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$PWD/inst" "$@"
  cmake --build "b-$name"
  cmake --install "b-$name" --prefix inst
}

vendor SDL     SDL3     "$SDL_VERSION"     -DSDL_SHARED=ON -DSDL_STATIC=OFF
# SDLTTF_VENDORED bundles freetype+harfbuzz so there are no system deps.
vendor SDL_ttf SDL3_ttf "$SDL_TTF_VERSION" -DBUILD_SHARED_LIBS=ON -DSDLTTF_VENDORED=ON

cd ../..
# copy shared libs (+ import libs + version symlinks) flat into the vendor dir; cp -a keeps symlinks.
# libSDL3*.dylib / libSDL3*.so* patterns catch both SDL3 and SDL3_ttf.
find build/.sdl/inst \( -name 'libSDL3*.so*' -o -name 'libSDL3*.dylib' \) -exec cp -a {} "$SDL_DIR/" \;
touch "$SDL_DIR/.stamp"
echo "vendored SDL3 $SDL_VERSION + SDL3_ttf $SDL_TTF_VERSION -> $SDL_DIR"
