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
                ];

                shellHook = ''
                    echo "Universal 7 Environment Loaded"
                    echo "Verbs: VIEW MAKE DROP CAST MOVE TWEAL RUN"
                    echo ""
                    source ./utility.sh
                '';
            };
        };
}