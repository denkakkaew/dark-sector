# gdUnit4 test suite.
# Run from VS Code:
#   - Test Explorer (gdUnit4 extension), or
#   - Terminal > Run Task… > "gdUnit4: run all tests", or
#   - the gutter "run test" icons next to each test_ function.
extends GdUnitTestSuite

# A throwaway example proving the harness works. Delete once you have real tests.
func test_assertions_smoke() -> void:
	assert_int(2 + 2).is_equal(4)
	assert_str("Dark Sector").contains("Sector")
	assert_bool(true).is_true()


# A small taste of a real test for the game's energy bar (see CLAUDE.md):
# energy drops when an alien reaches Earth, and the game ends at zero.
func test_energy_depletes_and_bottoms_out_at_zero() -> void:
	var energy := 100
	var drain := 30

	energy = maxi(0, energy - drain)
	assert_int(energy).is_equal(70)

	# Three more hits should clamp at 0, not go negative.
	for i in 3:
		energy = maxi(0, energy - drain)
	assert_int(energy).is_equal(0)
	assert_bool(energy <= 0).is_true()  # -> game over condition
