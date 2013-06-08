texts = {}
texts.main = tparse([==[
$cFFFFFF55Welcome to Iceball!

Seeing as people don't know what
reading is, we're moving a quick
tutorial to here.

Use your up/down arrow keys to
scroll through the text.
$-

$cFFFFFF55What is Iceball?

Iceball is one of two things:
$pA game engine
$pA game built on said engine

This tutorial was built upon said
game engine, and the files can be
found in:
$cFFFF5555  pkg/iceball/halp/

You will not need the files for
the game itself in order to play
games written for Iceball, unless
you are hosting a "server".
This is because the server sends
all the code and files needed to
the clients that connect.

Note, use of pmfedit and mapedit
require you to host a local
"server".

If you ARE running a server, the
code and files are found in:
$cFFFF5555  pkg/base/

If this directory does not exist,
download the source code from:
$cFF55FF55https://
$cFF55FF55  github.com/iamgreaser/iceball/

$-
$cFFFFFF55How do I run Iceball?

Open up a commandline. On Windows,
you can double-click on:
$cFFFF5555  opencmd.bat

In your commandline, type:
$cFFAAAAFF  iceball -h

It should give you brief
instructions on how to actually
run this game.

Yes, you do need to press Enter
at the end of a command.

$-
$cFFFFFF55How do I play the Iceball game?

Principles:

$cFFFF0000If you wear blue, you're on blue.
Same goes for green.
If you forget, look down.

$cFFFF0000Never EVER screw your team over.
Subterfuge does not exist.
Griefing your team is cheating.
We don't have an issue with grief
so far, but soon we'll add
support to ban small children.

$cFFFF0000COMMUNICATE
$cFFFF0000COMMUNICATE
$cFFFF0000COMMUNICATE
This cannot be stressed enough.
This is a team game.

Controls:
$pWASD = movement
$p1234 = select tool
$pArrows = change block colour
$pM = toggle large map
$pTYU = global/team/squad chat
$pSpace = jump
$pCtrl = crouch
$pV = sneak
$p, = change team
$p. = change gun
$pEsc = quit

Left click:
$pSpade = pick + get more blocks
$pBlock = place block
$pGun = shoot
$pGrenade = throw

Right click:
$pSpade = dig 3 high
$pBlock = pick block colour
$pGun = scope

$-
$cFFFFFF55Further documentation

How to configure Iceball
(e.g. setting your name and all
that crap):
$cFFFF5555  docs/setup_json.txt

Brief introduction to the engine
(for modders):
$cFFFF5555  docs/modding_101.txt

Lua API reference:
$cFFFF5555  docs/modding_lua.txt
This is also useful, though not
everything is available:
$cFF55FF55  http://lua.org/manual/5.1/

File format specifications:
$cFFFF5555  docs/format_icemap.txt
$cFFFF5555  docs/format_pmf.txt

$-
$cFF000000Kurukuru tokei no hari
$cFF000000  Guruguru atama mawaru
$cFF000000Datte tsubura medama
$cFF000000  Futatsu shika nai no ni
$cFF000000    Sanbon no hari nante
$cFF000000      Chinpunkan
]==])

return texts









--

