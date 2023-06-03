{
  description = "M-PESA .pdf statement tools";

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      ghc = pkgs.haskellPackages.ghcWithPackages (p: [ p.aeson p.parsec p.bytestring p.cassava p.optparse-applicative ]);
      runtimeDeps = [
        ghc
        pkgs.poppler_utils
      ];
    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell {
        buildInputs = runtimeDeps ++ [
          pkgs.haskellPackages.haskell-language-server
          pkgs.nixpkgs-fmt
        ];
      };
      packages.x86_64-linux.mpesa2csv = pkgs.writeScriptBin "mpesa2csv" ''
        . ${./mpesa.sh};
        WORK=$(echo $TMPDIR/mpesa-tools);
        rm -fR $WORK
        mkdir $WORK;
        preprocess $1 $WORK;
        ${ghc}/bin/runghc ${./MPesa.hs} to-csv --input $WORK/mpesa.txt
      '';
      packages.x86_64-linux.mpesa2json = pkgs.writeScriptBin "mpesa2json" ''
        . ${./mpesa.sh};
        WORK=$(echo $TMPDIR/mpesa-tools);
        rm -fR $WORK
        mkdir $WORK;
        preprocess $1 $WORK;
        ${ghc}/bin/runghc ${./MPesa.hs} to-json --input $WORK/mpesa.txt
      '';

    };
}
