{
 inputs = {
   nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
 };

 outputs = {
   nixpkgs
 , ...
 }:

 let
  pkgs = import nixpkgs {
    system = "x86_64-linux";
  };
 in with pkgs; {
   devShells.x86_64-linux.default = mkShell {
     LD_LIBRARY_PATH = "$LD_LIBRARY_PATH:${
        lib.makeLibraryPath [
         glfw
         libGL
         SDL2
         SDL2_mixer
         SDL
         vulkan-loader
         xorg.libX11
         xorg.libXi
        ]
     }";

     buildInputs = [
       (odin.overrideAttrs (finalAttr: prevAttr: {
         src = fetchFromGitHub {
           owner = "odin-lang";
           repo = "Odin";
           rev = "0fa62937d58fe5bc014a2749f68aaac518f79e92";
           sha256 = "sha256-cIrTmAa3vBimPGkuSH3QM56LD64FxnIRthbTNxG1BwM=";
         };
       }))
       # odin
       gcc
       glfw
       glxinfo
       gnumake
       lld
       libGL
       SDL2
       SDL2_mixer
       SDL
       vulkan-headers
       vulkan-loader
       vulkan-tools
       xorg.libXi
       xorg.libX11
       xorg.libXft
       xorg.libXrandr
       xorg.libX11.dev
       xorg.libXcursor
       xorg.libXinerama
       xorg.libXinerama
     ];

     shellHook = ''
        alias run='odin run .'
        alias build='odin build .'
     '';
   };
 };
}
