local Object = require("rat-scratch-common").Object
local Event = require("rat-scratch-common").Event
local EventScope = require("rat-scratch-common").EventScope

--- @class RatScratch.Graphics.Graphics3D.AnimatorEvent : RatScratch.Common.Event
--- @field private group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @field private playback RatScratch.Graphics.Graphics3D.AnimatorPlayback
--- @overload fun(scope: RatScratch.Common.EventScope): RatScratch.Graphics.Graphics3D.AnimatorEvent
local AnimatorEvent = Object(Event)

AnimatorEvent.GROUP_UPDATED = EventScope.create()
AnimatorEvent.GROUP_CLEARED = EventScope.create()
AnimatorEvent.GROUP_PLAYBACK_UPDATED = EventScope.create()
AnimatorEvent.GROUP_PLAYBACK_CLEARED = EventScope.create()

function AnimatorEvent:new(scope)
	Event.new(self, scope)
end

function AnimatorEvent:getGroup()
	return self.group
end

function AnimatorEvent:getPlayback()
	return self.playback
end

--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @return RatScratch.Graphics.Graphics3D.AnimatorEvent
function AnimatorEvent.fromAnimatorGroupUpdated(group)
	local event = Event.get(AnimatorEvent, AnimatorEvent.GROUP_UPDATED)
	event.group = group

	return event
end

--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @return RatScratch.Graphics.Graphics3D.AnimatorEvent
function AnimatorEvent.fromAnimatorGroupCleared(group)
	local event = Event.get(AnimatorEvent, AnimatorEvent.GROUP_CLEARED)
	event.group = group

	return event
end

--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @param playback RatScratch.Graphics.Graphics3D.AnimatorPlayback
--- @return RatScratch.Graphics.Graphics3D.AnimatorEvent
function AnimatorEvent.fromAnimatorGroupPlaybackUpdated(group, playback)
	local event = Event.get(AnimatorEvent, AnimatorEvent.GROUP_PLAYBACK_UPDATED)
	event.group = group
	event.playback = playback

	return event
end

--- @param group RatScratch.Graphics.Graphics3D.AnimatorGroup
--- @param playback RatScratch.Graphics.Graphics3D.AnimatorPlayback
--- @return RatScratch.Graphics.Graphics3D.AnimatorEvent
function AnimatorEvent.fromAnimatorGroupPlaybackCleared(group, playback)
	local event = Event.get(AnimatorEvent, AnimatorEvent.GROUP_PLAYBACK_CLEARED)
	event.group = group
	event.playback = playback

	return event
end

return AnimatorEvent
