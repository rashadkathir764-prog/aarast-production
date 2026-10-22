# Journeys: before / after

Data and generator for the before/after review page of the groom journey (published as a private artifact).

- `data/<domain>.json`: one entry per real screen. Today's screen, the new design, what changed, what exists on the server, what is left, and design fixes.
- `data/lifecycle.json`: state machines from the backend, compared with the design. `src` fields cite file:line.
- `data/top.json`: the most important false claims in the new design.
- Images are not stored here. Current screens come from the golden-tagged capture tests in `mobile/test/prototype/now_*/`. New designs come from `mobile/test/prototype/v3/out/`. Convert them to `img/<domain>/*.jpg` and `img/new/<id>.jpg` (520px wide), then run `python3 -I build.py`.

## Journeys

`python3 -I build.py <groom|bride|provider|participant>` builds one page per journey.

- Groom: `data/<domain>.json`.
- Provider: `data/provider.json`, `data/lifecycle_provider.json`. Current screens come from `mobile/test/prototype/now_provider_side/`, and new designs from `mobile/test/prototype/provider/out/`.
- Bride: `make_bride.py` builds `data/bride_<domain>.json` from the groom data plus her differences. The new designs come from `mobile/test/prototype/bride_profile/gen.py`, rendered with `--dart-define=BRIDE=true`. The current screens come from `bride_profile/gen_now.py`, which copies the groom capture tests with the bride persona into the git-ignored `gen/`.
- Participant: `data/participants.json`, `data/lifecycle_participant.json`.
