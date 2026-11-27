package main

import alicorn "alicorn:runtime"
import trial_app "trial:app"
import data_grid "alikit:data_grid"

// This executable constructs one ordinary application frame against Alicorn's
// retained runtime. It intentionally has no native window or GPU host.
main :: proc() {
	app: trial_app.Grid_App
	trial_app.initialize_app(&app)
	_ = data_grid.request_focus(&app.view)

	runtime := new(alicorn.Runtime)
	if runtime == nil { return }
	defer {
		alicorn.destroy_runtime(runtime)
		free(runtime)
	}
	runtime^ = alicorn.new_runtime(
		alicorn.Rect{0, 0, 1280, 800},
		alicorn.Runtime_Config{
			persistent_allocator=context.allocator,
			scratch_backing_allocator=context.allocator,
		},
	)
	if !alicorn.text_engine_load_default_fonts(runtime) { return }
	_ = trial_app.grid_build_application(rawptr(&app), runtime, 1280, 800, 1)
}
