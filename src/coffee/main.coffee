define(["init", "person", "ship"], (init, Person, Ship) ->
    canvas = init.canvas

    
    sampleHuman = canvas.display.person(
        race: 'human'
        tile_x: 1
        tile_y: 1
    )

    sampleShip= canvas.display.ship(
        model: 'kestral'
        x: 0
        y: 0
    )
    
    canvas.addChild(sampleShip);
    sampleShip.addPerson(sampleHuman);
    
    sampleHuman.bind("click tap",() ->
        sampleHuman.moveByTileXY(1,0)
    )
    
    canvas.setLoop(() -> 
        sampleHuman.update
    )
    canvas.timeline.start()
)