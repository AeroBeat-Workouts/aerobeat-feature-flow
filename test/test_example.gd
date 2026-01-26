extends GutTest

# ------------------------------------------------------------------------------
# Example Unit Test
# ------------------------------------------------------------------------------
# This script demonstrates the basic structure of a GUT test file.
# Run this via the GUT panel in the Editor or via Command Line.

func before_all():
	# Runs once before all tests in this script.
	# Use this to setup global resources or load heavy assets.
	gut.p("Starting Example Tests...")

func before_each():
	# Runs before each test function.
	# Use this to reset state between tests.
	pass

func after_each():
	# Runs after each test function.
	# Use this to clean up nodes (queue_free).
	pass

func after_all():
	# Runs once after all tests in this script.
	gut.p("Finished Example Tests.")

func test_sanity_check():
	assert_eq(1, 1, "Math should still work")

func test_string_equality():
	var project_name = "AeroBeat"
	assert_eq(project_name, "AeroBeat", "Strings should match")