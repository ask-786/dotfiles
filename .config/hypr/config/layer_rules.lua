-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- disable animation for vicinae only
hl.layer_rule({
	match = { namespace = "vicinae" },
	name = "vicinae-no-animation",
	no_anim = true,
})

-- blur vicinae
hl.layer_rule({
	match = { namespace = "vicinae" },
	name = "vicinae-blur",
	blur = true,
	ignore_alpha = 0,
})
