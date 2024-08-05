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
         libGL
         xorg.libX11
        ]
     }";

     buildInputs = [
       libGL
       odin
       xorg.libX11
     ];

     shellHook = ''
        alias run='odin run .'
        alias build='odin build .'
     '';
   };
 };
}
