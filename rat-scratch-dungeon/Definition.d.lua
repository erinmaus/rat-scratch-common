--- @meta

--- @class RatScratch.Dungeon.DungeonDefinition
--- @field public navigator RatScratch.Dungeon.Navigator
--- @field public shape RatScratch.Dungeon.DungeonDefinition.PolygonRootShape | RatScratch.Dungeon.DungeonDefinition.RectangleRootShape
--- @field public limits RatScratch.Dungeon.DungeonDefinition.Limits
local DungeonDefinition = {}

--- @alias RatScratch.Dungeon.DungeonDefinition.RootShape
--- | RatScratch.Dungeon.DungeonDefinition.BSPRootShape
--- | RatScratch.Dungeon.DungeonDefinition.PolygonRootShape
--- | RatScratch.Dungeon.DungeonDefinition.RectangleRootShape

--- @class RatScratch.Dungeon.DungeonDefinition.BSPRootShape
--- @field public type "bsp"
--- @field public node RatScratch.Math.BSP2D.BSPNode
local DungeonDefinitionBSPRootShape = {}

--- @class RatScratch.Dungeon.DungeonDefinition.PolygonRootShape
--- @field public type "polygon"
--- @field public points number[]
local DungeonDefinitionPolygonRootShape = {}

--- @class RatScratch.Dungeon.DungeonDefinition.RectangleRootShape
--- @field public type "rectangle"
--- @field public x number?
--- @field public y number?
--- @field public width number
--- @field public height number
local DungeonDefinitionRectangleRootShape = {}

--- @class RatScratch.Dungeon.DungeonDefinition.Limits
--- @field attemptSplitIterations integer
local DungeonDefinitionLimits = {}
