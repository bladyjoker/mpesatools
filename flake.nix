{
  description = "M-PESA statement processing";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        (pkgs.haskellPackages.ghcWithPackages (p: [p.aeson p.parsec p.bytestring]))
        (pkgs.haskellPackages.haskell-language-server)
      ];
    };
    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;

  };
}
