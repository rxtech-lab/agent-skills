# Composition rules

What a Chippy podcast composition must do, and what `submit_podcast_video` checks. These follow the instructions Chippy's built-in video agent uses.

## Project

- Canvas 1280×720 at 24 fps. The scaffold (`src/index.ts`, `src/Root.tsx`, `src/data.json`, `src/phrases.json`, `src/podcast.ts`) is read-only; `get_podcast_project` returns its source.
- Write `src/Video.tsx` exporting `PodcastVideo`, plus optional components under `src/` (max 8 generated `.ts`/`.tsx`/`.css` files, 60,000 characters each). `Root.tsx` mixes in `public/podcast.mp3`; do not add audio.
- Use inline styles: the preview renderer does not apply CSS files.

## Scaffold helpers (`src/podcast.ts`)

| Helper | Returns |
|--------|---------|
| `podcast` | `title`, `language`, `mood` (bright/calm/focused/warm/reflective), `durationSeconds`, `fps`, `speakers[{name}]`, `segments[]` |
| `segments[i]` | `speaker`, `chipId`, `chipTitle`, `startSeconds`, `endSeconds`, `voiceStartSeconds`, `voiceEndSeconds`, `image` (artwork path or null), `icon` |
| `useTime()` | Current time in seconds |
| `useSegment()` | `{ index, segment, progress }`; `index` is -1 before the first turn (the opening title) |
| `useNarration()` | `{ index, segment, elapsedSeconds, progress, speaking }`; holds 1 after the voice ends |
| `usePhrases()` | `useNarration()` plus `phrase`, `phraseCount`, `phraseProgress`, `at(k)`, `cue(k, seconds = 0.6)` |
| `useStoryTransition(min = 0.9, max = 1.6)` | `{ active, progress, from, to, story, storyCount, transition }` for the bridge between chips |
| `useSceneMotion(period = 6)` | `{ elapsedSeconds, loopProgress }`, a continuous per-story clock for ambient loops |
| `toFrame(seconds)` | Seconds to frames |

The opening title is the window where `useSegment().index === -1`. The ending is `useTime() >= last.voiceEndSeconds` on the last segment.

## Timing

- Read timings at runtime only, never hard-code seconds: a translated recording replays the same composition with different timings.
- `cue(k)` starts 0.15 s before phrase k so the picture leads the voice; use it for entrances, highlights and state changes, finishing within 0.4–0.7 s. `at(k)` runs across phrase k; use it for processes that unfold with the sentence.
- Don't stage a turn by equal slices of progress, elapsed seconds, or one slow entrance across the whole turn. If the voice names it, it is visible by the end of that phrase.
- Hold completed results during pauses; never replay a story on a loop.

## Scenes

- One clear idea per frame: a small chip-title heading, a large subject-specific illustration, at most two supporting objects, one short takeaway label.
- Each turn: a visible beginning, action and consequence tied to its claims, with at least five subject elements animating on their own phrase cues. Change the explanation on every turn, even within one chip.
- Generic nodes, orbiting circles, particles, equalizers, speaker badges, changing titles or pan/zoom over artwork are not explanations; don't make them the main visual.
- Don't invent numbers, dates, code or facts. Label conceptual illustrations as schematic when needed.
- Show a chip's artwork (`<Img src={staticFile(segment.image)} />`) only in its first eligible turn as an establishing inset, then retire it. See art-direction.md.

## Transitions

- **Within a story:** Magic Move. Shared objects with stable semantic keys are rendered once in a persistent layer and interpolate position, size and simple geometry from the previous settled layout to the next over ≈0.45–0.7 s from the incoming `segment.startSeconds` (at most half that turn).
- **Between stories:** a designed bridge of ≈0.9–1.6 s timed by `useStoryTransition().progress`: exit (the outgoing scene condenses into a token), bridge (a full-width wipe, iris, staggered stripes or seam), enter (heading on the wipe's trailing edge, then the first object grows from where the bridge ended). A chapter marker (`story + 1 / storyCount` and the incoming chip title) rides the bridge, and a small progress rail of story dots advances with a spring. While `active`, draw `from` frozen at its final state and `to` at its initial layout. Vary the bridge per change within one family of shapes and easing.
- **Opening and ending:** Magic Move bookends, as described in SKILL.md and art-direction.md.

## Motion craft

- Easing: `Easing.bezier(0.16, 1, 0.3, 1)` for entrances, `Easing.bezier(0.7, 0, 0.84, 0)` for exits, `Easing.inOut(Easing.cubic)` for layout moves, `spring({ damping: 12–18 })` for landings. Nothing linear except constant ambient flow.
- Stagger related elements by 2–4 frames and overlap actions. Prefer gentle arcs to straight diagonals.
- Layer depth: decorations drift slowest, the subject moves fully, accents slightly overshoot. A subtle camera drift (scale 1→1.03) is fine; never move text relative to its object.
- Prefer masked reveals, `clipPath` wipes, `strokeDashoffset` line draws, compatible path morphs and scale-from-anchor growth over plain fades.
- Emphasis on a cue: ring ripple, highlight sweep, a shape's scale kick (1→1.08→1) or a shift to coral for a narrated risk.
- Keep scenes alive between cues with ambient motion tied to the subject, derived from `useSceneMotion()` or the frame with sin/cos so loops never jump.
- Match energy (spring stiffness, stagger, ambient speed) to `podcast.mood`, keeping the light palette.

## Text

- Never draw captions, subtitles, transcripts or spoken sentences. Short topic, object and takeaway labels only.
- Keep headings and labels anchored, opaque and unchanged during actions; no pulsing, blinking, scaling, retyping or animated font properties. Changed labels may crossfade once.
- Give every label its own box with ≥16px clearance, accounting for the largest scale and translation an element reaches. Wrap long labels and support CJK.
- Font stack: `-apple-system, "SF Pro Display", "PingFang SC", "Hiragino Sans", "Apple SD Gothic Neo", sans-serif`.
- Keep all text above the bottom 100px while a voice plays.

## Hard rules (submission rejects these)

- Imports only from `react`, `remotion` and your own files: `interpolate`, `interpolateColors`, `spring`, `Easing`, `Sequence`, `AbsoluteFill`, `Img`, `staticFile`, `random`.
- Animate only from `useCurrentFrame()` and the helpers. No React state or effects, timers, clocks, `Math.random`, CSS transitions or `@keyframes`, SVG `<animate>`, Web Animations, `fetch`, URLs, storage, iframes, `dangerouslySetInnerHTML`, audio or video elements.
- `random()` seeds are string or number literals; never seed with frame, time or progress, and never resample geometry or change React keys over time.
- `interpolate()` input ranges must be strictly increasing; guard zero-length windows.
- 2D only: no 3D transforms, perspective, `backdrop-filter` or `mix-blend-mode`.
- Keep frames cheap: no heavy blur on large layers, ≈80 animated elements at most.
- A static composition, overlapping text, text over artwork, text clipped by the canvas, text in the subtitle band while a voice plays, or a runtime error fails submission with the times to inspect.
