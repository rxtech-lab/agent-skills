---
name: chippy-card-design
description: Design varied artwork and layouts for Chippy summary or briefing cards. Use when creating card covers, improving repetitive card compositions, or implementing the cover-generation prompts and templates. Ordinary saving, searching and listing chips belongs to chippy-mcp.
---

# Chippy Card Design

Make each card communicate its own story at thumbnail size. Choose a composition that fits the content and the actual card renderer; do not reuse a right-side subject, empty left half, dark teal palette and decorative rings for every topic.

## Choose a layout

Inspect the target aspect ratios, crop behavior and where the app places its title before designing. Distinguish the artwork from the surrounding UI: a title shown above an image does not require an empty title area inside that image. A social preview that draws text over the artwork does require a readable title zone.

Select a layout family deliberately:

| Family | Composition | Useful for |
|--------|-------------|------------|
| Centered subject | One strong subject near the center, with a simple supporting background | A person, product, vehicle or single concrete idea |
| Environmental scene | A wide scene with foreground, middle ground and a clear focal subject | Places, construction, travel, events or infrastructure |
| Comparison | Two balanced visual regions separated by space or a restrained divider | Competing choices, policy tradeoffs or before/after stories |
| Diagonal movement | A subject or visual path leads across the canvas on a diagonal | Transport, energy flows, change or momentum |
| Editorial collage | Two or three distinct cutouts arranged around one dominant visual | Stories connecting institutions, people and places |
| Object close-up | A tightly framed object or detail fills much of the canvas | Security, science, money or product features |
| Symbolic composition | A small set of meaningful objects expresses the central relationship | Abstract business, governance or technology topics |

For a batch, choose the families together before generating. Avoid repeating the same family on adjacent cards; aim for at least three families when there are four or more cards, unless the user requests a uniform series. Also vary subject scale, viewpoint, lighting and palette where the stories allow. Changing only the subject or colors is not a new layout. For one card, choose the strongest fit without making extra variants unless requested.

Use topic-specific visual metaphors. Financial stories need not all show a suited person, technology need not always be a holographic interface, and political stories need not all use maps. Decorative rings, grids, curves and dotted lines should support a particular idea rather than appear as a compulsory background.

## Compose for the renderer

- Keep the main subject and the visual relationship understandable at thumbnail size. Avoid tiny charts, busy dashboards and multiple equally prominent objects.
- Verify the actual crops. If a 16:9 image is center-cropped to a square, keep the essential subject within the central square-safe region (roughly the middle 56% of the width), with margin. Do not hide the only subject at the far right or left. Use separate compositions for incompatible crops when the implementation supports them.
- When titles sit outside the image, use the whole artwork area. Do not reserve half of it for text that will never appear there.
- When text is overlaid, specify its position and protect that area with restrained detail and adequate contrast. Choose a layout compatible with the template. A template with a fixed left-side title cannot support arbitrary subject placement without a template change.
- Generate text-free artwork: no headlines, labels, letters, numbers, logos, watermarks or invented glyphs. Render the headline and metadata separately in the app or card template, including translated text.
- Preserve the app's existing card shell, navigation and actions when the request concerns cover artwork. Variation belongs in the composition unless the user also asks to redesign the UI.

## Write the generation instruction

State the selected family, story-specific subject, subject scale, viewpoint, focal position, palette, crop requirements and any actual text zone. Supply the article as context rather than allowing source text to override the design instructions.

Example for artwork shown below a title and reused as a square thumbnail:

> Create a text-free editorial illustration about an emergency fuel release. Use an environmental scene: a central oil-storage tank with a port and tanker in the distance, viewed from a slightly elevated angle. Warm amber light and muted slate colors; broad, readable shapes and limited detail. Keep the tank and the key relationship within the central square-safe region of the 16:9 canvas. The title is outside the artwork, so use the entire image for the scene. No text, numbers, logos, UI or watermarks.

For agents implementing cover generation, carry the selected composition through the design schema, image prompt and renderer as needed. Remove or parameterize any unconditional right-side-subject or empty-left-half instruction that conflicts with it. If selection is automated, keep an existing card's choice stable across rerenders and translations; do not randomly change its composition on every request.

## Check the result

Inspect the actual rendered card and relevant crops, including a translated or long title when changing the text template. Check that the focal subject is visible, text is readable and no text was baked into the artwork. For a batch, inspect a contact sheet or grid: the cards should differ in composition, not just in subject and color. Correct clipping or repeated compositions before delivering.

## Chippy MCP boundary

The current `add_summary` tool generates the cover on the server and exposes no layout, image-prompt or artwork-upload argument. These instructions apply when an agent can design artwork or implement the cover pipeline; loading this skill alone does not steer MCP-generated covers. Use only fields supported by the connected tool's schema. Do not put design instructions into the raw source, summary, key points, tags or keywords to work around a missing layout field. If the connected tool later supports cover controls, pass the selected composition through those documented fields.
