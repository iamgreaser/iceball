Disco Mod
===========

Adds a `/disco` command to start a party !


## Configuration

* declare the mod in the server config file `svsave/pub/mods.json`, for example :
```json
	...
        "mods" : [
                "pkg/iceball/hack_console/",
                "pkg/melchips/disco"
        ],
	...
```
* add the `disco` permission to any user in config file `svsave/pub/server.json`, for example :
```json
		...
                },
                "moderator" : {
                        "password" : "iceball",
                        "extends" : "default",
                        "permissions" : [
                                "god",
                                "kick",
                                "tempban",
                                "teleport",
                                "gmode",
                                "piano",
                                "intelcmd",
                                "goto",
                                "map",
                                "disco"
                        ]
                },
		...
```
## Commands and permissions

* `disco`
    * Description: Start/stop the disco party
    * Permissions: `disco`

	
## Attribution

* `mat^2` : original script from pyspade
* `melchips` : script porting to iceball
* `iamgreaser` : music '7thdiscoheaven.it' and the amazing shader
* `rakiru` : helping with permissions, this readme and testing
