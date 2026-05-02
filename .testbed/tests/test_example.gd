extends GutTest

# ------------------------------------------------------------------------------
# Flow Feature Sanity Tests
# ------------------------------------------------------------------------------
# Keep this file lightweight until repo-local Flow runtime code lands.
# Run it via the GUT panel in the Editor or from the command line.

func before_all():
	gut.p("Starting Flow feature sanity tests...")

func before_each():
	pass

func after_each():
	pass

func after_all():
	gut.p("Finished Flow feature sanity tests.")

func test_sanity_check():
	assert_eq(1, 1, "Math should still work")

func test_flow_feature_label():
	var feature_name = "AeroBeat Flow Feature"
	assert_eq(feature_name, "AeroBeat Flow Feature", "Feature label should stay stable")
