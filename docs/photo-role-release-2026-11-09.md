# Photo role selection and longer splash

Deployment: https://vehiclebreakdown-7qg2jqrf4-breakers-projects-d332ab9a.vercel.app
ID: dpl_8K5gpbhJw8hyrreu6cccurSVVgAA
Client: b5315bbf36ad523cf78548e4229afebd817d8f6dc1f1934498eb2d95c4129fe4
Rollback: dpl_Enn15CigG5Cm1DQWuwkUS7UxbLV4

Splash stays visible at least 2.5 seconds from startup and waits longer if destination resolution is not ready. Handoff is a 650 ms eased fade and gentle slide; reduced motion skips the transition. The static splash content remains unchanged. Startup timers cancel safely on disposal.

Role selection uses native Flutter photo cards, the existing logo/font and road pattern, blue Driver and teal Provider actions, and compact guest access. Car/van login scenes and explicit role routing remain unchanged. Images are illustrative, not actual driver/provider vehicles.

Validation: 39 splash/auth/emergency/render tests passed; the expanded narrow/large-text layout suite passed all 25 checks. Static analysis has no errors, with existing warnings/info remaining. Production web build succeeds.

## Generated image

Built-in image_gen tool used. Asset: assets/images/role_roadside_scene.png (original generated PNG copied into the repository; no pre-existing image overwritten).

Prompt: Generate a production app background photograph asset, very wide landscape 3:2 composition, no text, no letters, no logos, no interface, no frame. Cinematic photorealistic Sri Lankan mountain road at blue hour with distant small city lights. On LEFT half prominent beautiful dark blue modern SUV seen three-quarter front, stopped safely at roadside and facing slightly inward. On RIGHT half clearly recognizable white flatbed recovery tow truck with amber beacon lights, three-quarter front, full cab and flatbed visible, facing slightly inward. Both separated with open winding asphalt road between, realistic lighting and vehicle geometry. Rich deep navy and sapphire tones, subtle wet road reflections, turquoise distance mountains, tasteful amber truck beacon, believable roadside assistance imagery. Vehicle subjects in lower two-thirds, sky and mountain silhouette upper third. No people needed. The image will be used twice cropped into Driver and Provider cards with Flutter overlays; left crop must show blue SUV clearly and right crop must show actual white tow truck clearly. Professional photo quality, not cartoon, not giant wheels closeup.
