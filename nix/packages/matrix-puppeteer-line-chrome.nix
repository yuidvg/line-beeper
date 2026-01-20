{ lib
, stdenv
, fetchFromGitea
, nodejs
, yarn
, makeWrapper
, chromium
}:

stdenv.mkDerivation rec {
  pname = "matrix-puppeteer-line-chrome";
  version = "unstable-2024-01-01";

  src = fetchFromGitea {
    domain = "src.miscworks.net";
    owner = "fair";
    repo = "matrix-puppeteer-line";
    rev = "master";
    sha256 = lib.fakeSha256;  # Replace with actual hash after first build
  };

  sourceRoot = "${src.name}/puppet";

  nativeBuildInputs = [
    nodejs
    yarn
    makeWrapper
  ];

  buildInputs = [
    chromium
  ];

  # Offline yarn build
  yarnOfflineCache = stdenv.mkDerivation {
    name = "${pname}-yarn-cache";
    inherit src sourceRoot;
    nativeBuildInputs = [ yarn ];
    buildPhase = ''
      export HOME=$TMPDIR
      yarn config set yarn-offline-mirror $out
      yarn --frozen-lockfile --ignore-scripts
    '';
    installPhase = "true";
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = lib.fakeSha256;  # Replace after first build
  };

  buildPhase = ''
    export HOME=$TMPDIR
    yarn config set yarn-offline-mirror ${yarnOfflineCache}
    yarn --offline --frozen-lockfile --ignore-scripts
  '';

  installPhase = ''
    mkdir -p $out/lib/matrix-puppeteer-line-chrome
    cp -r . $out/lib/matrix-puppeteer-line-chrome/

    mkdir -p $out/bin
    makeWrapper ${nodejs}/bin/node $out/bin/matrix-puppeteer-line-chrome \
      --add-flags "$out/lib/matrix-puppeteer-line-chrome/src/main.js" \
      --set PUPPETEER_EXECUTABLE_PATH "${chromium}/bin/chromium"
  '';

  meta = with lib; {
    description = "Chrome/Puppeteer backend for matrix-puppeteer-line";
    homepage = "https://src.miscworks.net/fair/matrix-puppeteer-line";
    license = licenses.agpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
