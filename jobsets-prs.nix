{ declInput
, nixpkgs
, pullrequests
, jobsets
} :

let
  pkgs = import nixpkgs {};
  lib = pkgs.lib;

  # PRs from GitHub's API JSON file
  prs = with builtins; fromJSON (readFile pullrequests);

  # We only build PRs from GitHub users listed here
  allowedUsers = with builtins; fromJSON (readFile ./trustedUsers.json);

  # Valid: is allowedUser, not a draft, PR is open
  validPrs = with lib; filterAttrs (n: v:
    (foldr (user: found: v.user.login == user || found) false allowedUsers) &&
    !v.draft && v.state == "open"
  ) prs;

  # Create a single jobset for a PR
  # Allow building of all free packages
  createJobset = prNumber: spec: ref: {
    enabled = true;
    hidden = false;
    description = spec.title;
    nixexprinput = "qchem";
    nixexprpath = "release.nix";
    checkinterval = 300;    # 5 min. check interval
    schedulingshares = 100;
    enableemail = false;
    emailoverride = "";
    keepnr = 1;
    inputs = {
      qchem = {
        type = "git";
        value  = "https://github.com/markuskowa/NixOS-QChem pull/${prNumber}/${ref}";
        emailresponsible = false;
      };

      nixpkgs = {
        type = "git";
        value = "https://github.com/NixOS/nixpkgs nixpkgs-unstable";
        emailresponsible = false;
      };

      allowUnfree = {
        type = "boolean";
        value = "false";
        emailresponsible = false;
      };

      pin = {
        type = "boolean";
        value = "true";
        emailresponsible = false;
      };

      config = {
        type = "nix";
        value = ''
          {
            optAVX = true;
          }
        '';
        emailresponsible = false;
      };
    };
  };

  # Build the PR and the respective merge commit
  jobsetsHead = with lib; mapAttrs' (n: v: nameValuePair ( "PR-head-${n}" ) (createJobset n v "head")) validPrs;
  jobsetsMerge = with lib; mapAttrs' (n: v: nameValuePair ( "PR-merge-${n}" ) (createJobset n v "merge")) validPrs;

in {
  jobsets = pkgs.writeText "jobsets.json" (builtins.toJSON (jobsetsHead // jobsetsMerge ));
}

