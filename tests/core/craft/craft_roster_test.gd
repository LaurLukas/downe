extends TestCase

func test_roster_has_seventeen_craft() -> void:
	assert_eq(CraftDefinitions.all_craft_ids().size(), 17, "14 shuttles + 3 fighter wings")

func test_every_declared_ability_id_resolves_in_the_registry() -> void:
	for craft_id: String in CraftDefinitions.all_craft_ids():
		var definition := CraftDefinitions.get_definition(craft_id)
		for ability_id: String in definition.ability_ids:
			assert_true(AbilityRegistry.has_ability(ability_id), "%s declares unknown ability '%s'" % [craft_id, ability_id])

func test_ally_docks_at_quellon() -> void:
	assert_eq(CraftDefinitions.get_definition("ally").home_ship, "quellon", "ally -> Quellon, per the resolved open question")

func test_wobbly_docks_at_shepherd() -> void:
	assert_eq(CraftDefinitions.get_definition("wobbly").home_ship, "shepherd", "wobbly -> Shepherd, per the resolved open question")

func test_endeavour_docks_at_shepherd() -> void:
	assert_eq(CraftDefinitions.get_definition("endeavour").home_ship, "shepherd", "Endeavour -> Shepherd, per the resolved open question")

func test_maliades_docks_at_dione() -> void:
	assert_eq(CraftDefinitions.get_definition("maliades").home_ship, "dione", "Maliades -> Dione, per the resolved open question")

func test_every_home_ship_is_a_real_ship() -> void:
	for craft_id: String in CraftDefinitions.all_craft_ids():
		var home_ship := CraftDefinitions.get_definition(craft_id).home_ship
		assert_true(ShipRegistry.all_ship_ids().has(home_ship), "%s's home_ship '%s' is not one of the 6 real ships" % [craft_id, home_ship])

func test_hummingbird_cannot_carry_materials() -> void:
	var cargo_types := CraftDefinitions.get_definition("hummingbird").cargo_types
	assert_true(not cargo_types.has(ResourceStock.Kind.MATERIALS), "Hummingbird's cargo list should not include materials")

func test_pallas_can_only_carry_security_teams() -> void:
	var cargo_types := CraftDefinitions.get_definition("pallas").cargo_types
	assert_eq(cargo_types, [ResourceStock.Kind.SECURITY_TEAMS] as Array[ResourceStock.Kind], "Pallas should only be able to carry security teams")
