# Twitter Media Assist (faragouji fork)

For your better Twitter/X media experience.

This is a personal fork of [Flkalas/TwitterMediaAssist](https://github.com/Flkalas/TwitterMediaAssist)
with a few bug fixes, packaged for private (self-distributed) installation on
Firefox. It is not published to the add-ons store.

## Fixes in this fork

| PR | Problem | Fix |
| -- | ------- | --- |
| #1 | On a video **post page** the video downloaded **twice at once**. Twitter serves the same video across more than one API response with a differing URL query param (e.g. `?tag=12` vs `?tag=14`), so the URL-based dedup in `inject.js` stored two entries. | Deduplicate the media by a stable identity (`type` + `readableFilename`) in `downloadMediaObject()` before dispatching the download. |
| #2 | Sometimes the download button **did nothing until the page was reloaded**. The button only reads media captured by the `inject.js` response interceptor; if the tweet came from cache/bfcache (no request to intercept) or the interceptor loaded after Twitter's request, nothing was captured. | On-demand fallback: when nothing is cached for the tweet, fetch it via `extractGraphQlMedia()`. Also inject the page scripts in parallel with `async=false` (`content.js`) to shrink the load race. |
| #3 | — | Build prep for signing: new extension id `twitter-media-assist-fork@faragouji`, version `3.3.2`, `data_collection_permissions: none`. |
| #5 | Downloaded files used Twitter's raw hash names, with no account handle. | Name downloads `handle-tweetId.ext` (account handle first) **by default** across video/GIF/image downloads, and resolve the `@handle` from either `core.screen_name` or `legacy.screen_name` so it no longer falls back to `unknown`. Version `3.3.3`. |
| #6 | Twitter GIFs were saved both as an animated `.gif` and as `.mp4`. | Default the "save GIF as GIF" conversion (`isConvertGIF`) to **off**, so Twitter GIFs download only as MP4. Re-enable it in the options page if wanted. Version `3.3.4`. |
| #7 | In the timeline, clicking download sometimes did nothing (tweet not intercepted; the on-demand fallback used an internal GraphQL query id that Twitter had rotated). | Add a robust on-demand fallback via the public `cdn.syndication.twimg.com` endpoint (no login, no rotating query id) as the primary fallback, keeping the GraphQL path as secondary for login-gated tweets. Version `3.3.5`. |

## How it works (quick map)

- `content.js` injects `twitter_video_downloader.js` and `inject.js` into the page.
- `inject.js` intercepts Twitter's GraphQL `fetch`/XHR responses, extracts media, and stores them in `sessionStorage` (key `rectifying@gmail.com` — an internal namespace string, **not** the extension id).
- `twitter_video_assist_client.js` adds the download button; on click, `downloadMediaObject()` reads that `sessionStorage` and sends one message per media to the background.
- `twitter_video_assist_server.js` (background) performs the actual `browser.downloads.download()` and GIF conversion.

The extension source lives in [`src/`](src/); `src/manifest.json` is the manifest root.

## Prerequisites

- [Node.js](https://nodejs.org/) (for `npx web-ext`).
- A free Mozilla add-on developer account and API credentials from
  <https://addons.mozilla.org/developers/addon/api/key/> (only needed to sign).

## Build (validate + package)

From the repo root:

```powershell
npx --yes web-ext@latest lint  --source-dir src            # 0 errors expected
npx --yes web-ext@latest build --source-dir src --artifacts-dir dist --overwrite-dest
```

This produces an **unsigned** `dist/twitter_media_assist-<version>.zip`. Unsigned
packages can only be loaded *temporarily* on Firefox release (removed on restart)
via `about:debugging` → **This Firefox** → **Load Temporary Add-on…** → pick
`src/manifest.json`. Use this for quick testing.

## Sign for permanent install (Firefox release)

To install permanently on normal Firefox, the package must be signed by Mozilla.
This fork uses **self-distribution (unlisted)** signing — signed, but not listed
in the public store.

1. Get your API key/secret from
   <https://addons.mozilla.org/developers/addon/api/key/>.
2. Provide them via environment variables (kept out of git and shell history)
   and run the helper script:

   ```powershell
   $env:WEB_EXT_API_KEY = "user:XXXXX:XX"    # JWT issuer
   $env:WEB_EXT_API_SECRET = "your-secret"   # JWT secret
   ./sign.ps1
   ```

   `sign.ps1` wraps `web-ext sign --channel unlisted`. AMO validates and signs
   the package (usually within seconds for unlisted) and writes the signed
   `.xpi` into `dist/`.

## Install the signed add-on

Firefox → `about:addons` → gear ⚙ → **Install Add-on From File…** → choose the
signed `.xpi` in `dist/`. Because it is signed, it stays installed across
restarts on Firefox release.

> If you also had the original store version installed, remove it — this fork
> uses a different id, so both would run side by side and add two buttons.

## Updating after code changes

1. Make the change (ideally on a branch + PR).
2. Bump `version` in `src/manifest.json` (AMO rejects re-uploading the same version).
3. Run `./sign.ps1` again and reinstall the new `.xpi`; Firefox upgrades it in
   place via the shared extension id.

---

## Upstream project

Fork of <https://github.com/Flkalas/TwitterMediaAssist> (MIT). Original store listings:

- Firefox: <https://addons.mozilla.org/en-US/firefox/addon/twitter-media-assist-ff>
- Chrome: <https://chrome.google.com/webstore/detail/twitter-media-assist/cledppeceojodgghbbkaciochldmpdfk>

### Privacy

This product parses the Twitter/X web page. It does not collect any user data,
has no server or database, and all processing runs on your machine.

### Earlier related projects

- <https://github.com/Flkalas/TwitterVideoAssistChrome>
- <https://github.com/Flkalas/M2G>
