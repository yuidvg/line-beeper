{
  lib,
  python3Packages,
  fetchFromGitHub,
  src,
  callPackage,
  ...
}:

let
  puppet = callPackage ./puppet.nix { inherit src; };

  # Old mautrix version required by matrix-puppeteer-line (0.9.x)
  # We might need to adjust dependencies if this fails.
  mautrix_0_9 = python3Packages.buildPythonPackage rec {
    pname = "mautrix";
    version = "0.9.2";
    # We ideally need to fetch this source, but let's see if we can use a newer one or if pip installs it.
    # For now, let's skip specific mautrix build and rely on what's available or fail.
    # Actually, let's just try to build the main app and see what dependencies are missing.
    src = fetchFromGitHub {
      owner = "tulir";
      repo = "mautrix-python";
      rev = "v${version}";
      sha256 = "sha256-DXS9rNvoxMskbS4ocTjZLxXYBTbKH9KI9pGo4bzr70o=";
    };
    doCheck = false;
    propagatedBuildInputs = with python3Packages; [
      aiohttp
      yarl
      attrs
    ];
  };

in
python3Packages.buildPythonApplication {
  pname = "matrix-puppeteer-line";
  version = "0.0.1-git";

  inherit src;

  propagatedBuildInputs = with python3Packages; [
    ruamel-yaml
    python-magic
    commonmark
    aiohttp
    yarl
    attrs
    mautrix_0_9 # Commented out to first fail on puppet hash
    asyncpg
    pillow
    qrcode
  ];

  # Inject puppet location
  postPatch = ''
    # Adjust path to puppet
    sed -i "s|/opt/matrix-puppeteer-line/puppet|${puppet}/libexec/matrix-puppeteer-line/deps/matrix-puppeteer-line/puppet|" matrix_puppeteer_line/config.py || true
  '';

  doCheck = false;

  meta = with lib; {
    description = "Matrix <-> LINE bridge";
    homepage = "https://github.com/fair/matrix-puppeteer-line";
    license = licenses.agpl3Only;
    maintainers = [ ];
  };

  passthru.puppet = puppet;
}
