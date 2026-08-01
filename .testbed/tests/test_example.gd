extends GutTest

# ------------------------------------------------------------------------------
# Flow Mode Sanity Tests
# ------------------------------------------------------------------------------
# Keep this file lightweight until repo-local Flow runtime code lands.
# Run it via the GUT panel in the Editor or from the command line.

func before_all():
	gut.p("Starting Flow mode sanity tests...")

func before_each():
	pass

func after_each():
	pass

func after_all():
	gut.p("Finished Flow mode sanity tests.")

func test_sanity_check():
	assert_eq(1, 1, "Math should still work")

func test_flow_mode_label():
	var mode_name = "AeroBeat Flow Mode"
	assert_eq(mode_name, "AeroBeat Flow Mode", "Mode label should stay stable")
