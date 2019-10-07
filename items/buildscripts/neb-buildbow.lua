require "/scripts/util.lua"
require "/scripts/versioningutils.lua"
require "/items/buildscripts/abilities.lua"

function build(directory, config, parameters, level, seed)
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  if level and not configParameter("fixedLevel", true) then
    parameters.level = level
  end

  -- select, load and merge abilities
  setupAbility(config, parameters, "alt")
  setupAbility(config, parameters, "primary")

  -- elemental type
  local elementalType = parameters.elementalType or config.elementalType or "physical"
  replacePatternInData(config, nil, "<elementalType>", elementalType)

  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  --Populate tooltip fields
  if config.tooltipKind ~= "base" then
		config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
		config.tooltipFields.subtitle = parameters.category
		config.tooltipFields.damageLabel = util.round(config.primaryAbility.projectileParameters.power * config.primaryAbility.dynamicDamageMultiplier * config.primaryAbility.drawTime * config.damageLevelMultiplier, 2) or 0
		config.tooltipFields.perfectDrawTimeLabel = util.round(config.primaryAbility.powerProjectileTime, 2)
		config.tooltipFields.perfectDamageLabel = util.round(config.primaryAbility.powerProjectileParameters.power * config.primaryAbility.dynamicDamageMultiplier * config.primaryAbility.drawTime * config.damageLevelMultiplier, 2) or 0
		config.tooltipFields.airborneBonusLabel = util.round(config.primaryAbility.airborneBonus, 2)
		if config.altAbility then
			config.tooltipFields.drawTimeLabel = util.round(config.primaryAbility.drawTime - (config.altAbility.drawTimeReduction or 0), 2) or 0
		else
			config.tooltipFields.drawTimeLabel = util.round(config.primaryAbility.drawTime, 2) or 0
		end
		config.tooltipFields.drawEnergyLabel = util.round(config.primaryAbility.energyPerShot, 2) or 0
		config.tooltipFields.holdEnergyLabel = util.round(config.primaryAbility.holdEnergyUsage, 2) or 0
		if elementalType ~= "physical" then
			config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
		end
		if config.altAbility then
			config.tooltipFields.altAbilityTitleLabel = "Special:"
			config.tooltipFields.altAbilityLabel = config.altAbility.name or "unknown"
		end
		
		--Frackin' Universe critical fields
		if config.tooltipFields.critChanceLabel then
			config.tooltipFields.critChanceTitleLabel = "^orange;Crit %^reset;"
			config.tooltipFields.critChanceLabel = util.round(configParameter("critChance", 0), 0)
			config.tooltipFields.critBonusTitleLabel = "^yellow;Dmg +^reset;"
			config.tooltipFields.critBonusLabel = util.round(configParameter("critBonus", 0), 0)
		end
		
		if config.tooltipFields.stunChance then
			config.tooltipFields.stunChance = util.round(configParameter("stunChance", 0), 0)
		end
  end

  -- set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end
