# ReScript(src/App.res) → esbuild 번들(app.js) + public/ = 정적 웹 루트.
{
  lib,
  buildNpmPackage,
  esbuild,
}:
buildNpmPackage {
  pname = "status-web";
  version = "0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./rescript.json
      ./src
      ./public
    ];
  };
  npmDepsHash = "sha256-ZaUGMoHI1hTa6rfjrJ0jOHzrKgDertMjRQvsfpcrqA8=";

  nativeBuildInputs = [ esbuild ];

  # ReScript 출력은 @rescript/runtime을 ES 모듈로 import하므로
  # 브라우저가 바로 읽을 수 있게 하나의 스크립트로 묶는다.
  buildPhase = ''
    runHook preBuild
    npm run build
    esbuild src/App.res.mjs --bundle --minify --format=iife --outfile=public/app.js
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp -r public $out
    runHook postInstall
  '';
}
