# Groom journey: before / after

Data and generator for the before/after review page of the groom journey (published as a private artifact).

- `data/<domain>.json`: one entry per real screen. Today's screen, the new design, what changed, what exists on the server, what is left, and design fixes.
- `data/lifecycle.json`: state machines from the backend, compared with the design. `src` fields cite file:line.
- `data/top.json`: the most important false claims in the new design.
- Images are not stored here. Current screens come from the golden-tagged capture tests in `mobile/test/prototype/now_*/`. New designs come from `mobile/test/prototype/v3/out/`. Convert them to `img/<domain>/*.jpg` and `img/new/<id>.jpg` (520px wide), then run `python3 -I build.py`.
