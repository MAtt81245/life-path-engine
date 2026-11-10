-- Engine module definition (see Shared/GamePack for the fields).
return {
	Id = "Relationships",
	Name = "Relationships",
	Description = "Family, friends, rivals, partners and affection.",
	EffectKeys = { "Affection", "TargetBecomes", "RemoveTarget", "NewRelationship" },
	RequirementFields = { "Friends", "HasRelationship", "NoRelationship" },
}
