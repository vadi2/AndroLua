--- ELVA.lua
-- Expandable List View Adapter using a Lua table.
require 'import'
local lS = service
local DataSetObserver = bind 'android.database.DataSetObserver'

return function(groups,overrides)
    local ELA = {}
    local my_observer

    function ELA.areAllItemsEnabled ()
        return true
    end

    function ELA.getGroup (groupPos)
        return groups[groupPos+1].group
    end

    function ELA.getGroupCount ()
        return #groups
    end

    function ELA.getChild (groupPos,childPos)
        return groups[groupPos+1][childPos+1]
    end

    function ELA.getChildrenCount (groupPos)
        return #groups[groupPos+1]
    end

    function ELA.getChildId (groupPos,childPos)
        return childPos+1
    end

    function ELA.getCombinedChildId (groupPos,childPos)
        return 1000*groupPos + childPos
    end

    function ELA.getCombinedGroupId (groupPos)
        return groupPos+1
    end

    function ELA.getGroupId (groupPos)
        return groupPos+1
    end

    function ELA.hasStableIds ()
        return false
    end

    function ELA.isChildSelectable (groupPos,childPos)
        return true
    end

    function ELA.isEmpty ()
        return ELA.getGroupCount() == 0
    end

    function ELA.onGroupCollapsed (groupPos)
        print('collapse',groupPos)
    end

    function ELA.onGroupExpanded (groupPos)
        print('expand',groupPos)
    end

    function ELA.registerDataSetObserver (observer)
        my_observer = observer
    end

    function ELA.unregisterDataSetObserver (observer)
        my_observer = nil
    end

    if not overrides.getGroupView or not overrides.getChildView then error('must override getGroupView and getChildView') end

    local getGroupView = overrides.getGroupView
    ELA.getGroupView = function(groupPos,expanded,view,parent)
        return getGroupView(ELA.getGroup(groupPos),groupPos,expanded,view,parent)
    end
    overrides.getGroupView = nil

    local getChildView = overrides.getChildView
    ELA.getChildView = function(groupPos,childPos,lastChild,view,parent)
        return getChildView(ELA.getChild(groupPos,childPos),groupPos,childPos,lastChild,view,parent)
    end
    overrides.getChildView = nil

    -- allow for overriding any of the others...
    for k,v in pairs(overrides) do
        ELA[k] = v
    end

    return proxy('android.widget.ExpandableListAdapter',ELA)

end
