# status-web

[status-api](https://github.com/Icicle-Nix/status-api)의 얇은 뷰어.
ReScript(`src/App.res`)로 작성하고, 빌드 결과는 `public/`에 번들된 `app.js`를
더한 정적 디렉터리 하나다. 같은 오리진의 `status.json`을 1분마다 fetch해
줄 단위로 출력한다. 데이터 형식은 status-api README를 따른다.

```
nix build                  # → result/ (index.html, style.css, app.js)
nix develop -c npm install # 개발: 이후 npm run watch
```
