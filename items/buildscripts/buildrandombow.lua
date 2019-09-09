require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"
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

  -- initialize randomization
  if seed then
    parameters.seed = seed
  else
    seed = configParameter("seed")
    if not seed then
      math.randomseed(util.seedTime())
      seed = math.random(1, 4294967295)
      parameters.seed = seed
    end
  end

  -- select the generation profile to use
  local builderConfig = {}
  if config.builderConfig then
    builderConfig = randomFromList(config.builderConfig, seed, "builderConfig")
  end
  
  -- select, load and merge abilities
  setupAbility(config, parameters, "alt", builderConfig, seed)
  setupAbility(config, parameters, "primary", builderConfig, seed)

  -- elemental type
  if not parameters.elementalType and builderConfig.elementalType then
    parameters.elementalType = randomFromList(builderConfig.elementalType, seed, "elementalType")
  end
  local elementalType = configParameter("elementalType", "physical")

  -- elemental config
  if builderConfig.elementalConfig then
    util.mergeTable(config, builderConfig.elementalConfig[elementalType])
  end
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end

  -- elemental tag
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  replacePatternInData(config, nil, "<elementalName>", elementalType:gsub("^%l", string.upper))

  -- name
  if not parameters.shortdescription and builderConfig.nameGenerator then
    parameters.shortdescription = root.generateName(util.absolutePath(directory, builderConfig.nameGenerator), seed)
  end

  -- merge damage properties
  if builderConfig.damageConfig then
    util.mergeTable(config.damageConfig or {}, builderConfig.damageConfig)
  end
  
  -- preprocess shared primary attack config
  parameters.primaryAbility = parameters.primaryAbility or {}
  parameters.primaryAbility.drawTimeFactor = valueOrRandom(parameters.primaryAbility.drawTimeFactor, seed, "drawTimeFactor")
  parameters.primaryAbility.powerProjectileTimeFactor = valueOrRandom(parameters.primaryAbility.drawTimeFactor, seed, "powerProjectileTimeFactor")
  parameters.primaryAbility.energyPerShotFactor = valueOrRandom(parameters.primaryAbility.energyPerShotFactor, seed, "energyPerShotFactor")
  parameters.primaryAbility.holdEnergyUsageFactor = valueOrRandom(parameters.primaryAbility.holdEnergyUsageFactor, seed, "holdEnergyUsageFactor")

  config.primaryAbility.drawTime = scaleConfig(parameters.primaryAbility.drawTimeFactor, config.primaryAbility.drawTime)
  config.primaryAbility.powerProjectileTime = scaleConfig(parameters.primaryAbility.powerProjectileTimeFactor, config.primaryAbility.powerProjectileTime)
  config.primaryAbility.energyPerShot = scaleConfig(parameters.primaryAbility.energyPerShotFactor, config.primaryAbility.energyPerShot) or 0
  config.primaryAbility.holdEnergyUsage = scaleConfig(parameters.primaryAbility.holdEnergyUsageFactor, config.primaryAbility.holdEnergyUsage) or 0
  
  -- preprocess shared alt attack config
  parameters.altAbility = parameters.altAbility or {}
  parameters.altAbility.drawTimeFactor = valueOrRandom(parameters.altAbility.drawTimeFactor, seed, "drawTimeFactor")
  parameters.altAbility.powerProjectileTimeFactor = valueOrRandom(parameters.altAbility.drawTimeFactor, seed, "powerProjectileTimeFactor")
  parameters.altAbility.energyPerShotFactor = valueOrRandom(parameters.altAbility.energyPerShotFactor, seed, "energyPerShotFactor")
  parameters.altAbility.holdEnergyUsageFactor = valueOrRandom(parameters.altAbility.holdEnergyUsageFactor, seed, "holdEnergyUsageFactor")

  config.altAbility.drawTime = scaleConfig(parameters.altAbility.drawTimeFactor, config.altAbility.drawTime)
  config.altAbility.powerProjectileTime = scaleConfig(parameters.altAbility.powerProjectileTimeFactor, config.altAbility.powerProjectileTime)
  config.altAbility.energyPerShot = scaleConfig(parameters.altAbility.energyPerShotFactor, config.altAbility.energyPerShot) or 0
  config.altAbility.holdEnergyUsage = scaleConfig(parameters.altAbility.holdEnergyUsageFactor, config.altAbility.holdEnergyUsage) or 0

  -- preprocess melee primary attack config
  if config.primaryAbility.damageConfig and config.primaryAbility.damageConfig.knockbackRange then
    config.primaryAbility.damageConfig.knockback = scaleConfig(parameters.primaryAbility.drawTimeFactor, config.primaryAbility.damageConfig.knockbackRange)
  end

  -- preprocess ranged primary attack config
  if config.primaryAbility.projectileParameters then
    config.primaryAbility.projectileType = randomFromList(config.primaryAbility.projectileType, seed, "projectileType")
    config.primaryAbility.projectileCount = randomIntInRange(config.primaryAbility.projectileCount, seed, "projectileCount") or 1
    if config.primaryAbility.projectileParameters.knockbackRange then
      config.primaryAbility.projectileParameters.knockback = scaleConfig(parameters.primaryAbility.drawTimeFactor, config.primaryAbility.projectileParameters.knockbackRange)
    end
  end
  
  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  -- populate tooltip fields
  if config.tooltipKind ~= "base" then
	config.tooltipFields = {}
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
	config.tooltipFields.subtitle = parameters.category
	config.tooltipFields.maxDamageLabel = util.round(config.primaryAbility.projectileParameters.power * config.primaryAbility.dynamicDamageMultiplier * config.damageLevelMultiplier, 1) or 0
	config.tooltipFields.perfectMaxDamageLabel = util.round(config.primaryAbility.powerProjectileParameters.power * config.primaryAbility.dynamicDamageMultiplier * config.damageLevelMultiplier, 1) or 0
	if config.altAbility then
	  config.tooltipFields.drawTimeLabel = config.primaryAbility.drawTime - (config.altAbility.drawTimeReduction or 0) or 0
	else
	  config.tooltipFields.drawTimeLabel = config.primaryAbility.drawTime or 0
	end
	config.tooltipFields.energyPerShotLabel = config.primaryAbility.energyPerShot or 0
	config.tooltipFields.energyPerSecondLabel = config.primaryAbility.holdEnergyUsage or 0
	if elementalType ~= "physical" then
	  config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
	end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = config.primaryAbility.name or "unknown"
    end
    if config.altAbility then
      config.tooltipFields.altAbilityTitleLabel = "Special:"
      config.tooltipFields.altAbilityLabel = config.altAbility.name or "unknown"
    end
	--Custom manufacturer label
	config.tooltipFields.manufacturerLabel = configParameter("manufacturer")
  end

  -- build palette swap directives
  config.paletteSwaps = ""
  if builderConfig.palette then
    local palette = root.assetJson(util.absolutePath(directory, builderConfig.palette))
    local selectedSwaps = randomFromList(palette.swaps, seed, "paletteSwaps")
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end

  -- merge extra animationCustom
  if builderConfig.animationCustom then
    util.mergeTable(config.animationCustom or {}, builderConfig.animationCustom)
  end

  -- animation parts
  if builderConfig.animationParts then
    config.animationParts = config.animationParts or {}
    if parameters.animationPartVariants == nil then parameters.animationPartVariants = {} end
    for k, v in pairs(builderConfig.animationParts) do
      if type(v) == "table" then
        if v.variants and (not parameters.animationPartVariants[k] or parameters.animationPartVariants[k] > v.variants) then
          parameters.animationPartVariants[k] = randomIntInRange({1, v.variants}, seed, "animationPart"..k)
        end
        config.animationParts[k] = util.absolutePath(directory, string.gsub(v.path, "<variant>", parameters.animationPartVariants[k] or ""))
        if v.paletteSwap then
          config.animationParts[k] = config.animationParts[k] .. config.paletteSwaps
        end
      else
        config.animationParts[k] = v
      end
    end
  end
  
  -- set the projectileType
  local arrowVariant = config.animationParts.arrow:match("(%d+)%.png")
  parameters.primaryAbility = parameters.primaryAbility or {}
  parameters.altAbility = parameters.altAbility or {}
  parameters.altAbility.altProjectileType = parameters.altAbility.altProjectileType or "arrow" .. arrowVariant
  parameters.altAbility.specialAbility = parameters.altAbility.specialAbility or {}
  parameters.primaryAbility.projectileType = parameters.primaryAbility.projectileType or "arrow" .. arrowVariant
  parameters.altAbility.specialAbility.projectileType = parameters.altAbility.specialAbility.projectileType
  

  -- set gun part offsets
  local partImagePositions = {}
  if builderConfig.gunParts then
    construct(config, "animationCustom", "animatedParts", "parts")
    local imageOffset = {0,0}
    local gunPartOffset = {0,0}
    for _,part in ipairs(builderConfig.gunParts) do
      local imageSize = root.imageSize(config.animationParts[part])
      construct(config.animationCustom.animatedParts.parts, part, "properties")

      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
      config.animationCustom.animatedParts.parts[part].properties.offset = {config.baseOffset[1] + imageOffset[1] / 8, config.baseOffset[2]}
      partImagePositions[part] = copy(imageOffset)
      imageOffset = vec2.add(imageOffset, {imageSize[1] / 2, 0})
    end
    config.muzzleOffset = vec2.add(config.baseOffset, vec2.add(config.muzzleOffset or {0,0}, vec2.div(imageOffset, 8)))
  end

  -- elemental perfect release sounds
  if config.perfectRelease then
    construct(config, "animationCustom", "sounds", "fire")
    local sound = randomFromList(config.perfectRelease, seed, "fireSound")
    config.animationCustom.sounds.perfectRelease = type(sound) == "table" and sound or { sound }
  end

  -- build inventory icon
  if not config.inventoryIcon and config.animationParts then
    config.inventoryIcon = jarray()
    local parts = builderConfig.iconDrawables or {}
    for _,partName in pairs(parts) do
      local drawable = {
        image = config.animationParts[partName] .. ":1" .. config.paletteSwaps,
        position = partImagePositions[partName]
      }
	  if partName == "bottomLimb" then
	    drawable.image = config.animationParts[partName] .. ":1?flipy" .. config.paletteSwaps
	  end
      table.insert(config.inventoryIcon, drawable)
    end
  end

  -- set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1))

  return config, parameters
end

function scaleConfig(ratio, value)
  if type(value) == "table" then
    return util.lerp(ratio, value[1], value[2])
  else
    return value
  end
end
