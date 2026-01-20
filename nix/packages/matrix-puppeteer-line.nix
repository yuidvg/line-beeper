{ lib
, python3Packages
, fetchFromGitea
}:

python3Packages.buildPythonApplication rec {
  pname = "matrix-puppeteer-line";
  version = "unstable-2024-01-01";

  src = fetchFromGitea {
    domain = "src.miscworks.net";
    owner = "fair";
    repo = "matrix-puppeteer-line";
    rev = "master";
    sha256 = lib.fakeSha256;  # Replace with actual hash after first build
  };

  format = "setuptools";

  propagatedBuildInputs = with python3Packages; [
    ruamel-yaml
    python-magic
    commonmark
    aiohttp
    yarl
    attrs
    mautrix
    asyncpg
    pillow
    qrcode
  ];

  # Optional dependencies for e2be
  passthru.optional-dependencies = {
    e2be = with python3Packages; [
      python-olm
      pycryptodome
      unpaddedbase64
    ];
  };

  # Skip tests as they require network
  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/matrix-puppeteer-line
    cp $src/matrix_puppeteer_line/example-config.yaml $out/share/matrix-puppeteer-line/
  '';

  meta = with lib; {
    description = "A Matrix-LINE puppeting bridge based on Puppeteer";
    homepage = "https://src.miscworks.net/fair/matrix-puppeteer-line";
    license = licenses.agpl3Plus;
    maintainers = [];
    platforms = platforms.linux;
  };
}
