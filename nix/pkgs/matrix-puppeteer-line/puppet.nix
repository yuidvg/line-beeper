{

  fetchYarnDeps,
  mkYarnPackage,
  src,
}:

mkYarnPackage {
  name = "matrix-puppeteer-line-puppet";
  src = ../../../src/matrix-puppeteer-line/puppet;

  packageJSON = ./package.json;
  yarnLock = ./yarn.lock;

  offlineCache = fetchYarnDeps {
    yarnLock = ./yarn.lock;
    sha256 = "sha256-7FHSLSbQ/lmpe3fkQq8kwSfdbBHi0qfK5oFu+2lv7CE=";
  };

  # Fix for mkYarnPackage structure
  pkgConfig = {
    matrix-puppeteer-line = {
      root = null;
      build = true;
      main = "src/main.js";
    };
  };
}
