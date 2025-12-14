{
    description = "Universal 7 - an intuitive cli for a human and AI";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    outputs = { self, nixpkgs }:
        let 
            system = "aarch64-darwin";
            pkgs = nixpkgs.legacyPackages.${system};
        in 
        {
            devShells.${system}.default = pkgs.mkShell {
                buildInputs = [
                    pkgs.curl
                    pkgs.jq
                    pkgs.ripgrep
                    pkgs.fd
                    pkgs.qsv

                    pkgs.coreutils
                    pkgs.gnused
                    pkgs.gawk
                    pkgs.findutils
                    pkgs.gnugrep

                    pkgs.bc
                    pkgs.ffmpeg
                    pkgs.imagemagick
                    pkgs.gnutar
                    pkgs.gzip
                    pkgs.bzip2
                    pkgs.xz
                    pkgs.p7zip
                    pkgs.unzip

                    pkgs.rsync

                    pkgs.openssl
                    pkgs.yq-go
                    pkgs.git
                    pkgs.bash-completion
                ];

                shellHook = ''
                    source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
                    source ./utility.sh
                    echo "u7 - Universal 7 CLI"
                    echo "Verbs: show make drop convert move set run"
                '';
            };
        };
}