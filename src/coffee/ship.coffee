define(["init","animations","assets","person_ki","ship_data", "door", "room", "multi_layer_container"]
      ,(init,animations,Assets,PersonKI,ship_data,Door,Room,MultiLayerContainer) ->


    class Ship extends MultiLayerContainer
        persons: []
        constructor: (config) ->
            # Default attrs
            @attrs = 
                ship: "kestral"

            #Call super constructor
            super(config) 
            # Kinetic.Group.call(@, config) 

            # Put ship data in @
            @data = ship_data[@attrs.ship]

            if animations.ships[@attrs.ship].floor?
                floor = new Kinetic.Image( 
                    image: animations.ships[@attrs.ship].floor 
                )
            base = new Kinetic.Image( 
                image: animations.ships[@attrs.ship].base
            )
            
            @backgroundGroup = new Kinetic.Group(
                layer: "ships"
            )
            @backgroundGroup.add(base)
            @backgroundGroup.add(floor) if floor?

            @add(@backgroundGroup)

            @initRoomsAndDoors()
            
            @groups["room_selection_areas"].on("click tap",(event) => 
                event.stopPropagation()
                if @selected_person?
                    switch event.which
                        when 1 # left click
                            @deselectPerson()
                        when 3 # right click
                            absPos = @getAbsolutePosition()
                            tile_pos = @calculateTileXY(event.layerX - absPos.x, event.layerY - absPos.y)

                            # check whether there is a room in the clicked tile
                            if (tile_pos.x >= 0) and (tile_pos.y >= 0) and (tile_pos.x < @tiles.w) and (tile_pos.y < @tiles.h) \
                                and @tiles[tile_pos.x][tile_pos.y].room_id?

                                    if @selected_person.mission?
                                        @selected_person.mission.cancel( () => 
                                            mission = new PersonKI.TileMovement(@selected_person,tile_pos.x,tile_pos.y)
                                            @selected_person.mission = mission
                                        )
                                    else
                                        mission = new PersonKI.TileMovement(@selected_person,tile_pos.x,tile_pos.y)
                                        @selected_person.mission = mission
            )
        
        initRoomsAndDoors: () ->
            maxW = 0
            maxH = 0
            for room in @data.rooms
                maxW = Math.max(maxW,room.x+room.w)
                maxH = Math.max(maxH,room.y+room.h)
            for door in @data.doors
                maxW = Math.max(maxW,door.x+1)
                maxH = Math.max(maxH,door.y+1)

            # Initialize tiles
            @tiles = new Array(maxW)
            @tiles.w = maxW
            @tiles.h = maxH
            for x in [0..maxW-1]
                @tiles[x] = new Array(maxH-1)
                for y in [0..maxH-1]
                    @tiles[x][y] = 
                        reachable_rooms: []
                        open: []

            @roomsById = []
            # Set room assignments
            for roomData in @data.rooms
                for x in [0..roomData.w-1]
                    for y in [0..roomData.h-1]
                        @tiles[x+roomData.x][y+roomData.y].room_id = roomData.id


            # Create door objects 
            #    and
            # Set reachability of rooms via doors
            @doors = []
            for doorData in @data.doors
                # Create door object
                door = new Door
                    ship: @
                    data: doorData
                @add(door)
                # Make sure id1 contains the room that is reachable from @tiles[doorData.x][doorData.y]
                if @tiles[doorData.x][doorData.y].room_id == doorData.id1
                    tmp = doorData.id1
                    doorData.id1 = doorData.id2
                    doorData.id2 = tmp

                # Set reachable rooms of @tiles[doorData.x][doorData.y]
                @tiles[doorData.x][doorData.y].reachable_rooms[doorData.id1] = door

                # ... and vice versa 
                if doorData.direction == 0 # up
                    @tiles[doorData.x][doorData.y].open.push("up")
                    if doorData.y-1 >= 0
                        @tiles[doorData.x][doorData.y-1].open.push("down")
                        @tiles[doorData.x][doorData.y-1].reachable_rooms[doorData.id2] = door
                else # left
                    @tiles[doorData.x][doorData.y].open.push("left")
                    if doorData.x-1 >= 0
                        @tiles[doorData.x-1][doorData.y].open.push("right")
                        @tiles[doorData.x-1][doorData.y].reachable_rooms[doorData.id2] = door

            for roomData in @data.rooms
                # Create room object
                room = new Room(
                    data: roomData
                    ship: @
                )
                @add(room)
                @roomsById[roomData.id] = room
                for x in [0..roomData.w-1]
                    for y in [0..roomData.h-1]
                        @tiles[x+roomData.x][y+roomData.y].room = room

        getWalkableNeighbors: (x,y) ->
            # gets a list of tile positions that can be reached from (x,y) in one walking step
            neighbors = []
            for dx in [-1..1]
                if (x+dx >= 0) and (x+dx < @tiles.w)
                    for dy in [-1..1]
                        if (y+dy >= 0) and (y+dy < @tiles.h)
                            if dx == dy and dx == 0
                                continue
                            if @tiles[x+dx][y+dy].room_id?
                                if (dx * dy == 0) # horizontal or vertical 
                                    if @tiles[x][y].room_id == @tiles[x+dx][y+dy].room_id # in same room without door allowed
                                        neighbors.push({x:dx+x,y:dy+y})
                                    else if (@tiles[x][y].reachable_rooms[@tiles[x+dx][y+dy].room_id]?) or (@tiles[x+dx][y+dy].reachable_rooms[@tiles[x][y].room_id]?)
                                        neighbors.push({x:dx+x,y:dy+y})
                                # else if @tiles[x][y].room_id == @tiles[x+dx][y+dy].room_id # diagonal only allowed in same room
                                    # neighbors.push({x:dx+x,y:dy+y})

            return neighbors


        calculateTileXY: (x,y,precision=false) ->
            tile_pos = 
                x: (x + @data.tile_offset.x) / @data.tile_size
                y: (y + @data.tile_offset.y) / @data.tile_size
            if not precision
                tile_pos.x = Math.floor(tile_pos.x)
                tile_pos.y = Math.floor(tile_pos.y)
            return tile_pos
        
        selectPerson: (person) ->
            if not person.attrs.selectable?
                return
            @deselectPerson()
            @selected_person = person
            @selected_person.attrs.selected = true
            @selected_person.sprite.color = "green"
            @selected_person.sprite.update()
            
        deselectPerson: () ->
            if @selected_person?
                @selected_person.attrs.selected = false
                @selected_person.sprite.color = "yellow"
                @selected_person.sprite.update()
            @selected_person = null
            
        addPerson: (person) ->
            person.ship = this
            @add(person)
            person.selectionArea.on("click",(event) =>
                switch event.which
                    when 1 # left click
                        if person.attrs.selectable
                            @selectPerson(person)
                            event.cancelBubble = true
            )
            person.sprite.update()
            @persons.push(person)

        update: (elapsedTime) ->
            for person in @persons
                person.update(elapsedTime)
    
    return Ship
    
)