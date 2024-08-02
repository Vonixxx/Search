{
  lib,
  odin,
  stdenv,
  fetchFromGitHub,
  makeBinaryWrapper,
}:

stdenv.mkDerivation {
  pname   = "search";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "Vonixxx";
    repo  = "Search";
    rev   = "6b6b5443074cc5dca00ad2da3a524b1609cc4521";
    hash  = "sha256-WowbFsec8oZVPTMDefQJYOb4GfH3xa40bN3P9AIjflE=";
  };

  postPatch = ''
     patchShebangs build.sh
  '';

  nativeBuildInputs = [ makeBinaryWrapper ];

  buildInputs = [ odin ];

  buildPhase = ''
     runHook preBuild

     ./build.sh

     runHook postBuild
  '';

  installPhase = ''
     runHook preInstall

     install -Dm755 search -t $out/bin/
     wrapProgram $out/bin/search --set-default ODIN_ROOT ${odin}/share

     runHook postInstall
  '';

  meta = {
    inherit (odin.meta) platforms;
    description = "Simple Search Program";
    homepage    = "https://github.com/Vonixxx/Search";
    license     = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      vonixxx
    ];
    mainProgram = "search";
  };
}
