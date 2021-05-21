{ declInput
, nixpkgs
, jobsets
} :

let
  pkgs = import nixpkgs {};

in {
  jobsets = pkgs.writeText "jobsets.json" (builtins.readFile ./jobsets-qchem.json);
}
